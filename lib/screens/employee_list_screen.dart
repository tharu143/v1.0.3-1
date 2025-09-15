import 'dart:convert';
import 'dart:io'; // Added for File handling
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart'; // Added for temporary directory
import '../utils/error_handler.dart'; // Import the custom error handler

// Enum to manage the current view
enum EmployeeView { list, details, create }

class EmployeeListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  const EmployeeListScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });
  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  // --- STATE VARIABLES ---
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<String> _userRoles = [];
  bool _isLoading = true;
  bool _isLoadingRoles = true;
  EmployeeView _currentView = EmployeeView.list;
  Map<String, dynamic>? _selectedEmployee;
  String _appBarTitle = 'Employees';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;
  int _totalEmployees = 0;
  Map<String, int> _statusCounts = {};
  List<String> _statusOptionsForFilter = [];
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchUserRoles(), _fetchEmployees()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUserRoles() async {
    setState(() => _isLoadingRoles = true);
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_user_roles';
      final headers = {'Cookie': 'sid=${widget.sid}'};
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(
          () => _userRoles = List<String>.from(data['message']['roles'] ?? []),
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
      if (mounted) setState(() => _isLoadingRoles = false);
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_employee_deatils';
      final headers = {'Cookie': 'sid=${widget.sid}'};
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _allEmployees = List<Map<String, dynamic>>.from(
            data['message']['employees'] ?? [],
          );
          _calculateDashboardStats();
          _filterEmployees();
        });
      } else if (mounted) {
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    }
  }

  void _calculateDashboardStats() {
    _totalEmployees = _allEmployees.length;
    _statusCounts.clear();
    for (var employee in _allEmployees) {
      final status = employee['status'] ?? 'Unknown';
      _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
    }
    _statusOptionsForFilter = _statusCounts.keys.toList();
  }

  void _filterEmployees() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEmployees = _allEmployees.where((employee) {
        final matchesStatus =
            _selectedStatusFilter == null ||
            employee['status'] == _selectedStatusFilter;
        if (!matchesStatus) return false;
        if (query.isEmpty) return true;
        final employeeId = (employee['employee'] ?? '').toLowerCase();
        final employeeName = (employee['employee_name'] ?? '').toLowerCase();
        return employeeId.contains(query) || employeeName.contains(query);
      }).toList();
    });
  }

  void _selectStatusFilter(String? status) {
    setState(() {
      _selectedStatusFilter = (_selectedStatusFilter == status) ? null : status;
    });
    _filterEmployees();
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + increment,
        1,
      );
      _selectedStatusFilter = null;
    });
    _filterEmployees();
  }

  bool _canAddEmployee() {
    return _userRoles.contains('HR User') || _userRoles.contains('HR Manager');
  }

  void _switchToListView() {
    setState(() {
      _currentView = EmployeeView.list;
      _appBarTitle = 'Employees';
      _selectedEmployee = null;
    });
  }

  void _showDetailsView(Map<String, dynamic> employee) {
    setState(() {
      _selectedEmployee = employee;
      _currentView = EmployeeView.details;
      _appBarTitle = 'Employee Details';
    });
  }

  void _showCreateView() {
    if (_isLoadingRoles || !_canAddEmployee()) return;
    setState(() {
      _currentView = EmployeeView.create;
      _appBarTitle = 'Add New Employee';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _appBarTitle,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: _currentView != EmployeeView.list
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _switchToListView,
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentView(),
      ),
      floatingActionButton:
          _currentView == EmployeeView.list &&
              !_isLoadingRoles &&
              _canAddEmployee()
          ? FloatingActionButton(
              onPressed: _showCreateView,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCurrentView() {
    if (_isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    switch (_currentView) {
      case EmployeeView.list:
        return _buildEmployeeListView();
      case EmployeeView.details:
        return _EmployeeDetailsView(
          key: ValueKey(_selectedEmployee?['name']),
          employeeData: _selectedEmployee!,
          serverUrl: widget.serverUrl,
          sid: widget.sid,
        );
      case EmployeeView.create:
        return _EmployeeCreateView(
          key: const ValueKey('create'),
          serverUrl: widget.serverUrl,
          sid: widget.sid,
          onEmployeeCreated: () {
            _fetchEmployees();
            _switchToListView();
          },
        );
    }
  }

  Widget _buildEmployeeListView() {
    return Column(
      key: const ValueKey('list'),
      children: [
        _buildDashboard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by ID or Name...',
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredEmployees.isEmpty
              ? const Center(child: Text('No employees found.'))
              : RefreshIndicator(
                  onRefresh: _fetchEmployees,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = _filteredEmployees[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15),
                            child: Text(
                              (employee['employee_name'] ?? 'N')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            employee['employee_name'] ?? 'No Name',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            employee['designation'] ?? 'No Designation',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => _showDetailsView(employee),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.red;
      case 'Left':
        return Colors.orange;
      case 'Suspended':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDashboard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
            ),
            children: _statusCounts.entries.map((entry) {
              final status = entry.key;
              final count = entry.value;
              final isSelected = _selectedStatusFilter == status;
              return _buildDashboardCard(
                status,
                count,
                _getStatusColor(status),
                isSelected,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    int count,
    Color color,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () => _selectStatusFilter(title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isSelected ? Border.all(color: color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeDetailsView extends StatelessWidget {
  final Map<String, dynamic> employeeData;
  final String serverUrl;
  final String sid;

  const _EmployeeDetailsView({
    super.key,
    required this.employeeData,
    required this.serverUrl,
    required this.sid,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      try {
        final date = DateFormat('dd/MM/yyyy').parse(dateStr);
        return DateFormat('MMMM d, y').format(date);
      } catch (e) {
        return dateStr;
      }
    }
  }

  Future<void> _launchAttachment(String attachment) async {
    if (attachment.isEmpty) {
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('Attachment path is empty'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final url = Uri.parse('$serverUrl$attachment');
    try {
      // Download the PDF with authentication
      final response = await http.get(url, headers: {'Cookie': 'sid=$sid'});
      if (response.statusCode == 200) {
        // Decode filename to handle %20 and other encoded characters
        final filename = Uri.decodeComponent(attachment.split('/').last);
        // Get temporary directory and save the file
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);

        // Verify file exists
        if (await file.exists()) {
          final localUri = Uri.file(file.path);
          if (await canLaunchUrl(localUri)) {
            await launchUrl(
              localUri,
              mode: LaunchMode.externalApplication,
              // Explicitly set MIME type for PDF
              webViewConfiguration: const WebViewConfiguration(
                headers: {}, // No headers needed for local file
              ),
            );
            // Optionally clean up the file after a delay
            Future.delayed(const Duration(minutes: 5), () async {
              if (await file.exists()) {
                await file.delete();
              }
            });
          } else {
            throw 'No application found to open PDF files. Please install a PDF viewer.';
          }
        } else {
          throw 'Failed to save PDF file locally.';
        }
      } else {
        throw 'Failed to download PDF: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Failed to open $attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 240.0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(background: _buildHeader(context)),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSectionCard(
                    context,
                    title: 'Employment Details',
                    icon: Icons.work_outline,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.badge_outlined,
                        'Employee ID',
                        employeeData['employee'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.business_outlined,
                        'Company',
                        employeeData['company'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.group_work_outlined,
                        'Department',
                        employeeData['department'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.engineering_outlined,
                        'Designation',
                        employeeData['designation'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Date of Joining',
                        _formatDate(employeeData['date_of_joining']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.verified_outlined,
                        'Confirmation Date',
                        _formatDate(employeeData['final_confirmation_date']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.timer_off_outlined,
                        'Contract End Date',
                        _formatDate(employeeData['contract_end_date']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.notification_important_outlined,
                        'Notice Period',
                        '${employeeData['notice_number_of_days'] ?? 'N/A'} days',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.toggle_on_outlined,
                        'Status',
                        employeeData['status'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Personal Information',
                    icon: Icons.person_outline,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.cake_outlined,
                        'Date of Birth',
                        _formatDate(employeeData['date_of_birth']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.wc_outlined,
                        'Gender',
                        employeeData['gender'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.family_restroom_outlined,
                        'Marital Status',
                        employeeData['marital_status'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.local_hospital_outlined,
                        'Blood Group',
                        employeeData['blood_group'] ?? 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Health Details',
                    icon: Icons.health_and_safety_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.notes,
                        'Health Details',
                        employeeData['health_details'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.family_restroom,
                        'Family Background',
                        employeeData['family_background'] ?? 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Contact Information',
                    icon: Icons.contact_mail_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.phone_android_outlined,
                        'Mobile',
                        employeeData['cell_number'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.phone_iphone,
                        'Personal Mobile',
                        employeeData['custom_personal_mobile_number'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.phone_callback,
                        'Reference Mobile',
                        employeeData['custom_reference_mobile_number'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.email_outlined,
                        'Company Email',
                        employeeData['company_email'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.mail_outline,
                        'Personal Email',
                        employeeData['personal_email'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Emergency Contact',
                    icon: Icons.emergency_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.person_pin_circle_outlined,
                        'Contact Name',
                        employeeData['person_to_be_contacted'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.phone,
                        'Contact Phone',
                        employeeData['emergency_phone_number'],
                      ),
                      _buildDetailItem(
                        context,
                        Icons.people_alt_outlined,
                        'Relation',
                        employeeData['relation'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Passport Details',
                    icon: Icons.book_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.numbers,
                        'Passport Number',
                        employeeData['passport_number'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_month_outlined,
                        'Valid Upto',
                        _formatDate(employeeData['valid_upto']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Date of Issue',
                        _formatDate(employeeData['date_of_issue']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.location_on_outlined,
                        'Place of Issue',
                        employeeData['place_of_issue'] ?? 'N/A',
                      ),
                      _buildAttachmentItem(
                        context,
                        employeeData['custom_passport_attachment'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Visa Details',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.numbers,
                        'Visa Number',
                        employeeData['custom_visa_number'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_month_outlined,
                        'Valid Upto',
                        _formatDate(employeeData['custom_visa_valid_upto']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Start Date',
                        _formatDate(employeeData['custom_visa_start_date']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.business_center_outlined,
                        'Issuing Department',
                        employeeData['custom_visa_issuing_department_'] ??
                            'N/A',
                      ),
                      _buildAttachmentItem(
                        context,
                        employeeData['custom_visa_attachment'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Labour Card Details',
                    icon: Icons.work_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.numbers,
                        'Labour Card Number',
                        employeeData['custom_labour_card_number'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_month_outlined,
                        'Valid Upto',
                        _formatDate(
                          employeeData['custom_labour_card_valid_upto'],
                        ),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Starting Date',
                        _formatDate(
                          employeeData['custom_labour_card_starting_date'],
                        ),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.business_center_outlined,
                        'Issuing Department',
                        employeeData['custom_labour_card_issuing_department'] ??
                            'N/A',
                      ),
                      _buildAttachmentItem(
                        context,
                        employeeData['custom_labour_card_attachment'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Emirates ID Details',
                    icon: Icons.card_membership_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.numbers,
                        'Emirates ID',
                        employeeData['custom_emirates_id'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_month_outlined,
                        'Valid Upto',
                        _formatDate(
                          employeeData['custom_emirates_id_valid_upto_'],
                        ),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Date of Issue',
                        _formatDate(
                          employeeData['custom_emirates_id_date_of_issue'],
                        ),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.business_center_outlined,
                        'Department of Issue',
                        employeeData['custom_department_of_issue'] ?? 'N/A',
                      ),
                      _buildAttachmentItem(
                        context,
                        employeeData['custom_emirates_id_attachment'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Driving License Details',
                    icon: Icons.drive_eta_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.numbers,
                        'Driving License Number',
                        employeeData['custom_driving_license_number'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_month_outlined,
                        'Expiry Date',
                        _formatDate(
                          employeeData['custom_driving_license_expiry_date'],
                        ),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Issue Date',
                        _formatDate(
                          employeeData['custom_driving_license_issue_date'],
                        ),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.location_on_outlined,
                        'Place of Issue',
                        employeeData['custom_driving_license_place_of_issue'] ??
                            'N/A',
                      ),
                      _buildAttachmentItem(
                        context,
                        employeeData['custom_driving_license_attachment'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    title: 'Insurance Details',
                    icon: Icons.security_outlined,
                    children: [
                      _buildDetailItem(
                        context,
                        Icons.numbers,
                        'Policy Number',
                        employeeData['insurance_policy_number'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_today_outlined,
                        'Issue Date',
                        _formatDate(employeeData['insurance_issue_date']),
                      ),
                      _buildDetailItem(
                        context,
                        Icons.network_check_outlined,
                        'Network',
                        employeeData['insurance_network'] ?? 'N/A',
                      ),
                      _buildDetailItem(
                        context,
                        Icons.calendar_month_outlined,
                        'Expiry Date',
                        _formatDate(employeeData['insurance_expiry_date']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final imageUrl = employeeData['image'] != null
        ? '$serverUrl${employeeData['image']}' // Construct full image URL
        : null;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      httpHeaders: {'Cookie': 'sid=$sid'},
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        radius: 40,
                        backgroundImage: imageProvider,
                      ),
                      placeholder: (context, url) => CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Text(
                          (employeeData['employee_name'] ?? 'U')[0],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        (employeeData['employee_name'] ?? 'U')[0],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              Text(
                employeeData['employee_name'] ?? 'Employee',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black26)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employeeData['designation'] ?? 'N/A',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    IconData icon,
    String label,
    String? value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              value ?? 'N/A',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(BuildContext context, String? attachment) {
    if (attachment == null || attachment.isEmpty) {
      return const SizedBox.shrink();
    }
    final filename = Uri.decodeComponent(attachment.split('/').last);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.attach_file, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attachment',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _launchAttachment(attachment),
              child: Text(
                filename,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCreateView extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final VoidCallback onEmployeeCreated;

  const _EmployeeCreateView({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.onEmployeeCreated,
  });

  @override
  _EmployeeCreateViewState createState() => _EmployeeCreateViewState();
}

class _EmployeeCreateViewState extends State<_EmployeeCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cellNumberController = TextEditingController();
  final _personalMobileController = TextEditingController();
  final _referenceMobileController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _personalEmailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _dateOfJoiningController = TextEditingController();
  final _confirmationDateController = TextEditingController();
  final _contractEndDateController = TextEditingController();
  final _noticeDaysController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _relationController = TextEditingController();
  String? _gender;
  String? _status;
  String? _designation;
  String? _department;
  String? _company;
  bool _isSaving = false;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  List<String> _statusOptions = [];
  List<String> _designations = [];
  List<String> _departments = [];
  List<String> _companies = [];
  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _dateOfJoiningController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _gender = _genderOptions.first;
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _cellNumberController.dispose();
    _personalMobileController.dispose();
    _referenceMobileController.dispose();
    _companyEmailController.dispose();
    _personalEmailController.dispose();
    _dateOfBirthController.dispose();
    _dateOfJoiningController.dispose();
    _confirmationDateController.dispose();
    _contractEndDateController.dispose();
    _noticeDaysController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyPhoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      await Future.wait([
        _fetchDesignations(),
        _fetchStatusOptions(),
        _fetchDepartments(),
        _fetchCompanies(),
      ]);
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(
          context,
          message: 'Failed to load required data. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<void> _fetchGenericDropdown(
    String endpoint,
    Function(List<String>) onData,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.serverUrl}$endpoint'),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final List<String> items;
        if (data['message'] != null && data['message'] is Map) {
          final key = data['message'].keys.first;
          items = List<String>.from(data['message'][key] ?? []);
        } else if (data['data'] != null && data['data'] is List) {
          items = data['data']
              .map<String>((item) => item['name'].toString())
              .toList();
        } else {
          items = [];
        }
        onData(items);
      } else if (mounted) {
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> _fetchDesignations() async => await _fetchGenericDropdown(
    '/api/method/saletracking.saletracking.salestracking_api.salestracking.get_employee_designation_options',
    (data) => setState(() => _designations = data),
  );

  Future<void> _fetchStatusOptions() async => await _fetchGenericDropdown(
    '/api/method/saletracking.saletracking.salestracking_api.salestracking.get_employee_status_options',
    (data) => setState(() => _statusOptions = data),
  );

  Future<void> _fetchDepartments() async => await _fetchGenericDropdown(
    '/api/resource/Department?fields=["name"]',
    (data) => setState(() => _departments = data),
  );

  Future<void> _fetchCompanies() async => await _fetchGenericDropdown(
    '/api/resource/Company?fields=["name"]',
    (data) => setState(() => _companies = data),
  );

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      showApiErrorDialog(
        context,
        message: 'Please fix the errors before saving.',
      );
      return;
    }
    setState(() => _isSaving = true);
    final employeeData = {
      'first_name': _firstNameController.text,
      'middle_name': _middleNameController.text,
      'last_name': _lastNameController.text,
      'employee_name': [
        _firstNameController.text,
        _middleNameController.text,
        _lastNameController.text,
      ].where((e) => e.isNotEmpty).join(' '),
      'gender': _gender,
      'date_of_birth': _dateOfBirthController.text,
      'date_of_joining': _dateOfJoiningController.text,
      'status': _status,
      'designation': _designation,
      'department': _department,
      'company': _company,
      'final_confirmation_date': _confirmationDateController.text,
      'contract_end_date': _contractEndDateController.text,
      'notice_number_of_days': int.tryParse(_noticeDaysController.text) ?? 0,
      'cell_number': _cellNumberController.text,
      'custom_personal_mobile_number': _personalMobileController.text,
      'custom_reference_mobile_number': _referenceMobileController.text,
      'company_email': _companyEmailController.text,
      'personal_email': _personalEmailController.text,
      'person_to_be_contacted': _emergencyContactNameController.text,
      'emergency_phone_number': _emergencyPhoneController.text,
      'relation': _relationController.text,
    };
    try {
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/resource/Employee'),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(employeeData),
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onEmployeeCreated();
      } else {
        if (mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
        }
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDropdowns) {
      return const Center(child: CircularProgressIndicator());
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
        key: widget.key,
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModuleCard(
                title: 'Personal Information',
                context: context,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      labelText: 'First Name *',
                      prefixIcon: Icons.person_outline,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _middleNameController,
                      labelText: 'Middle Name',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Gender *',
                      value: _gender,
                      items: _genderOptions,
                      onChanged: (v) => setState(() => _gender = v),
                      prefixIcon: Icons.wc_outlined,
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context,
                      controller: _dateOfBirthController,
                      labelText: 'Date of Birth',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildModuleCard(
                title: 'Employment Information',
                context: context,
                child: Column(
                  children: [
                    _buildDateField(
                      context,
                      controller: _dateOfJoiningController,
                      labelText: 'Date of Joining *',
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context,
                      controller: _confirmationDateController,
                      labelText: 'Confirmation Date',
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context,
                      controller: _contractEndDateController,
                      labelText: 'Contract End Date',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _noticeDaysController,
                      labelText: 'Notice (days)',
                      prefixIcon: Icons.notification_important_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Status *',
                      value: _status,
                      items: _statusOptions,
                      onChanged: (v) => setState(() => _status = v),
                      validator: (v) => v == null ? 'Required' : null,
                      prefixIcon: Icons.toggle_on_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Designation *',
                      value: _designation,
                      items: _designations,
                      onChanged: (v) => setState(() => _designation = v),
                      validator: (v) => v == null ? 'Required' : null,
                      prefixIcon: Icons.engineering_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Department',
                      value: _department,
                      items: _departments,
                      onChanged: (v) => setState(() => _department = v),
                      prefixIcon: Icons.group_work_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableDropdownField(
                      labelText: 'Company *',
                      value: _company,
                      items: _companies,
                      onChanged: (v) => setState(() => _company = v),
                      validator: (v) => v == null ? 'Required' : null,
                      prefixIcon: Icons.business_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildModuleCard(
                title: 'Contact Information',
                context: context,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _companyEmailController,
                      labelText: 'Company Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && !v.contains('@')) {
                          return 'Enter a valid email';
                        }
                        if (v != null &&
                            v.isNotEmpty &&
                            v == _personalEmailController.text) {
                          return 'Emails cannot be the same';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _personalEmailController,
                      labelText: 'Personal Email',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && !v.contains('@')) {
                          return 'Enter a valid email';
                        }
                        if (v != null &&
                            v.isNotEmpty &&
                            v == _companyEmailController.text) {
                          return 'Emails cannot be the same';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _cellNumberController,
                      labelText: 'Mobile',
                      prefixIcon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _personalMobileController,
                      labelText: 'Personal Mobile',
                      prefixIcon: Icons.phone_iphone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _referenceMobileController,
                      labelText: 'Reference Mobile',
                      prefixIcon: Icons.phone_callback,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildModuleCard(
                title: 'Emergency Contact',
                context: context,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emergencyContactNameController,
                      labelText: 'Contact Name',
                      prefixIcon: Icons.person_pin_circle_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emergencyPhoneController,
                      labelText: 'Contact Phone',
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _relationController,
                      labelText: 'Relation',
                      prefixIcon: Icons.people_alt_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveEmployee,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Employee',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: validator,
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
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
      onTap: () => _selectDate(context, controller),
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
              onTap: () async {
                final result = await _showSearchableDialog(items, value);
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
    List<String> items,
    String? currentValue,
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
              title: const Text('Select an option'),
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

// Add a GlobalKey for Navigator context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
