import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'create_leave_screen.dart';
import 'leave_details_screen.dart';

class LeaveApplicationListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const LeaveApplicationListScreen({
    required this.serverUrl,
    required this.sid,
    super.key,
  });

  @override
  _LeaveApplicationListScreenState createState() =>
      _LeaveApplicationListScreenState();
}

class _LeaveApplicationListScreenState
    extends State<LeaveApplicationListScreen> {
  List<Map<String, dynamic>> _allLeaveApplications = [];
  List<Map<String, dynamic>> _filteredLeaveApplications = [];
  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = true;
  bool _isLoadingEmployees = true;
  bool _isNavigating = false;

  final TextEditingController _searchController = TextEditingController();

  DateTime _selectedMonth = DateTime.now();
  String? _selectedStatus;

  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _openCount = 0;
  int _cancelledCount = 0;
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    fetchLeaveData();
    _searchController.addListener(() {
      _filterData();
    });
  }

  Future<void> fetchLeaveData() async {
    await Future.wait([
      fetchLeaveApplications(),
      fetchEmployees(),
    ]);
  }

  Future<void> fetchLeaveApplications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_leave_application';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            _allLeaveApplications = List<Map<String, dynamic>>.from(
                data['message']['leave_applications'] ?? []);
            _allLeaveApplications.sort((a, b) => (b['creation'] ?? '9999-12-31')
                .compareTo(a['creation'] ?? '9999-12-31'));
          });
        } else {
          throw Exception('API Error: ${data['message']['message']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _filterData();
      });
    }
  }

  Future<void> fetchEmployees() async {
    if (!mounted) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_employee';
      final headers = {'Cookie': 'sid=${widget.sid}'};
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            _employees = List<Map<String, dynamic>>.from(
                data['message']['employees'] ?? []);
          });
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingEmployees = false);
    }
  }

  void _filterData() {
    List<dynamic> monthFilteredList = _allLeaveApplications.where((item) {
      // Corrected to use 'from_date' for filtering, as 'posting_date' is not in the API response
      if (item['from_date'] == null) return false;
      try {
        final itemDate = DateTime.parse(item['from_date']);
        return itemDate.year == _selectedMonth.year &&
            itemDate.month == _selectedMonth.month;
      } catch (e) {
        return false;
      }
    }).toList();

    int approved = 0, rejected = 0, open = 0, cancelled = 0, draft = 0;
    for (var item in monthFilteredList) {
      switch (item['status']) {
        case 'Approved':
          approved++;
          break;
        case 'Rejected':
          rejected++;
          break;
        case 'Open':
          open++;
          break;
        case 'Cancelled':
          cancelled++;
          break;
        case 'Draft':
          draft++;
          break;
      }
    }

    List<dynamic> displayList = List.from(monthFilteredList);

    if (_selectedStatus != null) {
      displayList = displayList
          .where((item) => item['status'] == _selectedStatus)
          .toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      displayList = displayList.where((leave) {
        final employeeName = (leave['employee_name'] ?? '').toLowerCase();
        final leaveId = (leave['name'] ?? '').toLowerCase();
        return employeeName.contains(query) || leaveId.contains(query);
      }).toList();
    }

    setState(() {
      _filteredLeaveApplications = List<Map<String, dynamic>>.from(displayList);
      _approvedCount = approved;
      _rejectedCount = rejected;
      _openCount = open;
      _cancelledCount = cancelled;
      _draftCount = draft;
    });
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + increment, 1);
      _selectedStatus = null;
    });
    _filterData();
  }

  void _selectStatus(String status) {
    setState(() {
      _selectedStatus = (_selectedStatus == status) ? null : status;
    });
    _filterData();
  }

  void _navigateToCreateLeaveScreen() {
    if (_isNavigating) return;
    if (_isLoadingEmployees) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading employees...')),
      );
      return;
    }
    setState(() => _isNavigating = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateLeaveScreen(
          serverUrl: widget.serverUrl,
          sid: widget.sid,
          employees: _employees,
          onLeaveCreated: fetchLeaveApplications,
        ),
      ),
    ).then((_) => setState(() => _isNavigating = false));
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Open':
        return Colors.orange;
      case 'Cancelled':
        return Colors.grey;
      case 'Draft':
        return Colors.blueAccent;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leave Applications',
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildDashboard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Employee or Leave ID...',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLeaveApplications.isEmpty
                    ? Center(
                        child: Text(
                            'No applications found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.'))
                    : RefreshIndicator(
                        onRefresh: fetchLeaveApplications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredLeaveApplications.length,
                          itemBuilder: (context, index) {
                            final leave = _filteredLeaveApplications[index];
                            final statusColor =
                                _getStatusColor(leave['status']);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      statusColor.withOpacity(0.15),
                                  child: Text(
                                    (leave['employee_name'] ?? 'N')[0]
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: statusColor),
                                  ),
                                ),
                                title: Text(leave['employee_name'] ?? 'No name',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(leave['leave_type'] ?? 'No type',
                                    style:
                                        TextStyle(color: Colors.grey.shade600)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    leave['status'] ?? 'N/A',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LeaveDetailsScreen(
                                      serverUrl: widget.serverUrl,
                                      sid: widget.sid,
                                      leave: leave,
                                      onLeaveUpdated: fetchLeaveApplications,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateLeaveScreen,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: _isNavigating
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
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
                  onPressed: () => _changeMonth(-1)),
              Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 16),
          GridView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8),
            children: [
              _buildDashboardCard('Approved', _approvedCount, Colors.green,
                  _selectedStatus == 'Approved'),
              _buildDashboardCard('Rejected', _rejectedCount, Colors.red,
                  _selectedStatus == 'Rejected'),
              _buildDashboardCard(
                  'Open', _openCount, Colors.orange, _selectedStatus == 'Open'),
              _buildDashboardCard('Cancelled', _cancelledCount, Colors.grey,
                  _selectedStatus == 'Cancelled'),
              _buildDashboardCard('Draft', _draftCount, Colors.blueAccent,
                  _selectedStatus == 'Draft'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
      String title, int count, Color color, bool isSelected) {
    return InkWell(
      onTap: () => _selectStatus(title),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: isSelected ? Border.all(color: color, width: 2.5) : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(count.toString(),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
