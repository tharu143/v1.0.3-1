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
  // New state for filtering by leave type
  String? _selectedLeaveType;

  // Status counts
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _openCount = 0;
  int _cancelledCount = 0;
  int _draftCount = 0;

  // State variable to hold leave type counts
  Map<String, int> _leaveTypeCounts = {};

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
    Map<String, int> leaveTypeCounts = {};

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
      final leaveType = item['leave_type'];
      if (leaveType != null) {
        leaveTypeCounts[leaveType] = (leaveTypeCounts[leaveType] ?? 0) + 1;
      }
    }

    List<dynamic> displayList = List.from(monthFilteredList);

    // Apply filters. Only one filter (status or type) can be active at a time.
    if (_selectedStatus != null) {
      displayList = displayList
          .where((item) => item['status'] == _selectedStatus)
          .toList();
    } else if (_selectedLeaveType != null) {
      displayList = displayList
          .where((item) => item['leave_type'] == _selectedLeaveType)
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
      _leaveTypeCounts = leaveTypeCounts;
    });
  }
  
  String _calculateLeaveDuration(String? fromDateStr, String? toDateStr) {
    if (fromDateStr == null || toDateStr == null) return 'N/A';
    try {
      final fromDate = DateTime.parse(fromDateStr);
      final toDate = DateTime.parse(toDateStr);
      final duration = toDate.difference(fromDate).inDays + 1;
      return '$duration ${duration == 1 ? 'Day' : 'Days'}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + increment, 1);
      _selectedStatus = null;
      _selectedLeaveType = null;
    });
    _filterData();
  }

  void _selectStatus(String status) {
    setState(() {
      _selectedStatus = (_selectedStatus == status) ? null : status;
      // Deselect leave type when a status is selected to avoid conflicting filters
      _selectedLeaveType = null;
    });
    _filterData();
  }

  // New function to handle selecting a leave type
  void _selectLeaveType(String leaveType) {
    setState(() {
      _selectedLeaveType = (_selectedLeaveType == leaveType) ? null : leaveType;
      // Deselect status when a leave type is selected
      _selectedStatus = null;
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildDashboard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredLeaveApplications.length,
                          itemBuilder: (context, index) {
                            final leave = _filteredLeaveApplications[index];
                            return _buildLeaveItemCard(leave);
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

  // New neat card for the leave list
  Widget _buildLeaveItemCard(Map<String, dynamic> leave) {
    final statusColor = _getStatusColor(leave['status']);
    final duration = _calculateLeaveDuration(leave['from_date'], leave['to_date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
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
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              leave['employee_name'] ?? 'No name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              leave['status'] ?? 'N/A',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        leave['leave_type'] ?? 'No type',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            duration,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final leaveTypes = _leaveTypeCounts.entries.toList();
    final typeColors = [
      Colors.teal, Colors.purple, Colors.indigo, Colors.blueGrey,
      Colors.brown, Colors.deepOrange, Colors.pink
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
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
          ),
          const SizedBox(height: 15),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildStatusCard('Approved', _approvedCount, Colors.green, isSelected: _selectedStatus == 'Approved', onTap: () => _selectStatus('Approved')),
                _buildStatusCard('Rejected', _rejectedCount, Colors.red, isSelected: _selectedStatus == 'Rejected', onTap: () => _selectStatus('Rejected')),
                _buildStatusCard('Open', _openCount, Colors.orange, isSelected: _selectedStatus == 'Open', onTap: () => _selectStatus('Open')),
                _buildStatusCard('Cancelled', _cancelledCount, Colors.grey, isSelected: _selectedStatus == 'Cancelled', onTap: () => _selectStatus('Cancelled')),
                _buildStatusCard('Draft', _draftCount, Colors.blueAccent, isSelected: _selectedStatus == 'Draft', onTap: () => _selectStatus('Draft')),
              ],
            ),
          ),
          
          if (_leaveTypeCounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(leaveTypes.length, (index) {
                  final leaveType = leaveTypes[index];
                  final color = typeColors[index % typeColors.length];
                  return _buildLeaveTypeChip(leaveType.key, leaveType.value, color, isSelected: _selectedLeaveType == leaveType.key, onTap: () => _selectLeaveType(leaveType.key));
                }),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, int count, Color color,
      {bool isSelected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: isSelected ? Border.all(color: color, width: 2.5) : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(count.toString(),
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeChip(String title, int count, Color color,
      {bool isSelected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: isSelected ? color : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.white.withOpacity(0.8),
              ),
              child: Text(count.toString(), style: TextStyle(color: isSelected ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

