import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'leave_details_screen.dart';
import '../utils/error_handler.dart';

class CreateLeaveScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<Map<String, dynamic>> employees;
  final VoidCallback onLeaveCreated;

  const CreateLeaveScreen({
    required this.serverUrl,
    required this.sid,
    required this.employees,
    required this.onLeaveCreated,
    super.key,
  });

  @override
  _CreateLeaveScreenState createState() => _CreateLeaveScreenState();
}

class _CreateLeaveScreenState extends State<CreateLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  String? employee;
  String? employeeName;
  String? leaveType;
  String? leaveApprover;
  String? leaveApproverName;
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  double totalLeavesAllocated = 0.0;
  double totalLeaveDays = 1.0;

  late List<Map<String, dynamic>> employees;
  List<Map<String, dynamic>> leaveAllocations = [];
  List<Map<String, dynamic>> existingLeaves = [];
  List<String> leaveTypes = [];
  List<Map<String, String>> leaveApprovers = [];
  String? lastSelectedEmployee;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    employees = widget.employees;
    _updateDateControllers();

    if (employees.isNotEmpty) {
      employee = employees.first['employee'];
      employeeName = employees.first['employee_name'];
      lastSelectedEmployee = employee;
      _fetchDataForEmployee();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  void _updateDateControllers() {
    _fromDateController.text = DateFormat('yyyy-MM-dd').format(fromDate);
    _toDateController.text = DateFormat('yyyy-MM-dd').format(toDate);
  }

  Future<void> _fetchDataForEmployee() async {
    if (employee == null) return;
    setState(() {
      _isLoading = true;
    });
    await Future.wait([
      fetchLeaveApprover(),
      fetchLeaveAllocations(),
      fetchExistingLeaves(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateAllocationForSelectedType() {
    if (leaveType != null && leaveType != 'Leave Without Pay') {
      final allocation = leaveAllocations.firstWhere(
        (alloc) => alloc['leave_type'] == leaveType,
        orElse: () => {'total_leaves_allocated': 0.0},
      );
      totalLeavesAllocated =
          allocation['total_leaves_allocated']?.toDouble() ?? 0.0;
    } else {
      totalLeavesAllocated = 0.0;
    }
  }

  Future<void> fetchLeaveApprover() async {
    if (employee == null) return;
    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_leave_approver?employee=$employee";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          if (!mounted) return;
          final String? approverEmailFromApi =
              data['message']['leave_approver'];
          final String finalApproverEmail =
              approverEmailFromApi ?? 'rafeek@keplertech.ae';
          final approverData = employees.firstWhere(
            (emp) => emp['employee'] == finalApproverEmail,
            orElse: () => <String, dynamic>{},
          );
          String finalApproverName;
          if (approverData.isNotEmpty &&
              approverData['employee_name'] != null) {
            finalApproverName = approverData['employee_name'];
          } else if (finalApproverEmail == 'rafeek@keplertech.ae') {
            finalApproverName = 'Rafeek';
          } else {
            finalApproverName = finalApproverEmail;
          }
          setState(() {
            leaveApprover = finalApproverEmail;
            leaveApproverName = finalApproverName;
            leaveApprovers = [
              {'email': leaveApprover!, 'name': leaveApproverName!},
            ];
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        leaveApprover = 'rafeek@keplertech.ae';
        leaveApproverName = 'Rafeek';
        leaveApprovers = [
          {'email': 'rafeek@keplertech.ae', 'name': 'Rafeek'},
        ];
      });
      showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> fetchLeaveAllocations() async {
    if (employee == null) return;
    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_employee_leave_allocations";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };
    final body = json.encode({'employee': employee});

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          if (!mounted) return;
          final allAllocations = List<Map<String, dynamic>>.from(
            data['message']['data'] ?? [],
          );
          final today = DateTime.now();
          final validLeaveTypes = allAllocations
              .where((alloc) {
                try {
                  final fromDate = DateTime.parse(alloc['from_date']);
                  final toDate = DateTime.parse(alloc['to_date']);
                  return !today.isBefore(fromDate) && !today.isAfter(toDate);
                } catch (e) {
                  return false;
                }
              })
              .map((alloc) => alloc['leave_type'] as String)
              .toSet()
              .toList();
          setState(() {
            leaveAllocations = allAllocations;
            leaveTypes = validLeaveTypes;
            if (!leaveTypes.contains('Leave Without Pay')) {
              leaveTypes.add('Leave Without Pay');
            }
            leaveType = leaveTypes.isNotEmpty ? leaveTypes.first : null;
            _updateAllocationForSelectedType();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        leaveAllocations = [];
        leaveTypes = ['Leave Without Pay'];
        leaveType = 'Leave Without Pay';
        totalLeavesAllocated = 0.0;
      });
      showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> fetchExistingLeaves() async {
    if (employee == null) return;
    final url =
        "${widget.serverUrl}/api/resource/Leave Application?filters=[[\"employee\",\"=\",\"$employee\"]]&fields=[\"name\",\"from_date\",\"to_date\",\"leave_type\"]";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          existingLeaves = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        existingLeaves = [];
      });
      showApiErrorDialog(context, message: e.toString());
    }
  }

  bool hasDateOverlap(DateTime from, DateTime to) {
    for (var leave in existingLeaves) {
      final leaveFrom = DateTime.parse(leave['from_date']);
      final leaveTo = DateTime.parse(leave['to_date']);
      if (!(to.isBefore(leaveFrom) || from.isAfter(leaveTo))) {
        return true;
      }
    }
    return false;
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          if (toDate.isBefore(fromDate)) toDate = fromDate;
        } else {
          toDate = picked;
          if (fromDate.isAfter(toDate)) fromDate = toDate;
        }
        totalLeaveDays = toDate.difference(fromDate).inDays + 1.0;
        _updateDateControllers();
      });
      if (hasDateOverlap(fromDate, toDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected dates overlap with an existing leave.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitLeaveApplication({String status = 'Open'}) async {
    if (!_formKey.currentState!.validate()) {
      showApiErrorDialog(
        context,
        message: 'Please fix the errors before saving.',
      );
      return;
    }

    if (hasDateOverlap(fromDate, toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected dates overlap with an existing leave.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (leaveType != 'Leave Without Pay' &&
        totalLeaveDays > totalLeavesAllocated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient leave allocation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final body = json.encode({
      'employee': employee,
      'employee_name': employeeName,
      'leave_type': leaveType,
      'leave_approver': leaveApprover,
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      'total_leave_days': totalLeaveDays,
      'description': _reasonController.text,
      'posting_date': DateTime.now().toIso8601String().split('T')[0],
      'company': 'Kepler Tech LLC',
      'status': status,
      'letter_head': 'Kepler Tech LLC',
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/resource/Leave Application'),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 && mounted) {
        final responseData = json.decode(response.body);
        final leaveId = responseData['data']['name'];
        widget.onLeaveCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Leave application created successfully (ID: $leaveId)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Leave Application',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (employees.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No employees available.',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.9),
            Theme.of(context).colorScheme.background,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModuleCard(
                title: 'Leave Application Details',
                context: context,
                child: Column(
                  children: [
                    _buildSearchableDropdownField(
                      labelText: 'Employee *',
                      value: employee != null
                          ? '${employees.firstWhere((e) => e['employee'] == employee)['employee_name']} ($employee)'
                          : null,
                      items: employees
                          .map(
                            (e) => '${e['employee_name']} (${e['employee']})',
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final selected = employees.firstWhere(
                            (e) =>
                                '${e['employee_name']} (${e['employee']})' ==
                                value,
                          );
                          setState(() {
                            employee = selected['employee'];
                            employeeName = selected['employee_name'];
                            leaveType = null;
                            leaveApprover = null;
                            leaveApproverName = null;
                            totalLeavesAllocated = 0.0;
                            leaveAllocations.clear();
                            leaveTypes.clear();
                            leaveApprovers.clear();
                            existingLeaves.clear();
                            if (employee != lastSelectedEmployee) {
                              lastSelectedEmployee = employee;
                              _fetchDataForEmployee();
                            }
                          });
                        }
                      },
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Leave Type *',
                      value: leaveType,
                      items: leaveTypes,
                      onChanged: (value) => setState(() {
                        leaveType = value;
                        _updateAllocationForSelectedType();
                      }),
                      prefixIcon: Icons.work_off_outlined,
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Leave Balance:',
                      '${totalLeavesAllocated.toStringAsFixed(1)} days',
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Leave Approver *',
                      value: leaveApprover != null
                          ? '$leaveApproverName ($leaveApprover)'
                          : null,
                      items: leaveApprovers
                          .map((a) => '${a['name']} (${a['email']})')
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final selected = leaveApprovers.firstWhere(
                            (a) => '${a['name']} (${a['email']})' == value,
                          );
                          setState(() {
                            leaveApprover = selected['email'];
                            leaveApproverName = selected['name'];
                          });
                        }
                      },
                      prefixIcon: Icons.person_search_outlined,
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context,
                      controller: _fromDateController,
                      labelText: 'From Date *',
                      isFromDate: true,
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context,
                      controller: _toDateController,
                      labelText: 'To Date *',
                      isFromDate: false,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Total Leave Days:',
                      '${totalLeaveDays.toStringAsFixed(1)} days',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _reasonController,
                      labelText: 'Reason *',
                      prefixIcon: Icons.notes_outlined,
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submitLeaveApplication,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required Widget child,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Colors.grey),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.black54),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    int maxLines = 1,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      validator: validator,
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
    required bool isFromDate,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () => _selectDate(context, isFromDate),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildSearchableDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return FormField<String>(
      validator: validator,
      initialValue: value,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: items.isEmpty
                  ? null
                  : () async {
                      final result = await _showSearchableDialog(
                        context,
                        items,
                        labelText,
                      );
                      if (result != null) {
                        onChanged?.call(result);
                        state.didChange(result);
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: labelText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
                  errorText: state.errorText,
                ),
                child: Text(
                  value ?? 'Select an option',
                  style: TextStyle(
                    color: value != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showSearchableDialog(
    BuildContext context,
    List<String> items,
    String title,
  ) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items
                .where(
                  (item) =>
                      item.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Text('Select $title'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            title: Text(item),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
