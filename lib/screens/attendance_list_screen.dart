import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AttendanceListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const AttendanceListScreen(
      {Key? key, required this.serverUrl, required this.sid})
      : super(key: key);

  @override
  _AttendanceListScreenState createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  List<dynamic> _allAttendance = [];
  List<dynamic> _filteredAttendance = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filtering state
  DateTime _selectedMonth = DateTime.now();
  String? _selectedStatus;

  // Dashboard counts
  int _presentCount = 0;
  int _absentCount = 0;
  int _leaveCount = 0;
  int _halfDayCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceList();
    _searchController.addListener(() {
      _filterData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttendanceList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_attendance'),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        setState(() {
          _allAttendance = List.from(data['attendance_list'] ?? []);
          _allAttendance.sort((a, b) => (b['attendance_date'] ?? '9999-12-31')
              .compareTo(a['attendance_date'] ?? '9999-12-31'));
          _filterData();
          _isLoading = false;
        });
      } else {
        throw Exception(
            'Failed to fetch attendance list: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching attendance list: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _filterData() {
    // 1. Filter by Month
    List<dynamic> monthFilteredList = _allAttendance.where((item) {
      if (item['attendance_date'] == null) return false;
      try {
        final itemDate = DateTime.parse(item['attendance_date']);
        return itemDate.year == _selectedMonth.year &&
            itemDate.month == _selectedMonth.month;
      } catch (e) {
        return false;
      }
    }).toList();

    // 2. Calculate Dashboard Counts for the selected month
    int present = 0;
    int absent = 0;
    int onLeave = 0;
    int halfDay = 0;
    for (var item in monthFilteredList) {
      switch (item['status']) {
        case 'Present':
        case 'Work From Home':
          present++;
          break;
        case 'Absent':
          absent++;
          break;
        case 'On Leave':
          onLeave++;
          break;
        case 'Half Day':
          halfDay++;
          break;
      }
    }

    // 3. Create the list for display by filtering by status and search
    List<dynamic> displayList = List.from(monthFilteredList);

    // Filter by selected Status
    if (_selectedStatus != null) {
      displayList = displayList.where((item) {
        final status = item['status'];
        switch (_selectedStatus) {
          case 'Present':
            return status == 'Present' || status == 'Work From Home';
          case 'Absent':
            return status == 'Absent';
          case 'On Leave':
            return status == 'On Leave';
          case 'Half Day':
            return status == 'Half Day';
          default:
            return false;
        }
      }).toList();
    }

    // Filter by Search Query
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      displayList = displayList.where((attendance) {
        final employeeName = (attendance['employee_name'] ?? '').toLowerCase();
        final status = (attendance['status'] ?? '').toLowerCase();
        return employeeName.contains(query) || status.contains(query);
      }).toList();
    }

    // 4. Update state
    setState(() {
      _filteredAttendance = displayList;
      _presentCount = present;
      _absentCount = absent;
      _leaveCount = onLeave;
      _halfDayCount = halfDay;
    });
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + increment, 1);
      // Clear status filter when month changes
      _selectedStatus = null;
    });
    _filterData();
  }

  void _selectStatus(String status) {
    setState(() {
      if (_selectedStatus == status) {
        _selectedStatus = null; // Unselect if tapped again
      } else {
        _selectedStatus = status;
      }
    });
    _filterData();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
      case 'Work From Home':
        return Colors.green;
      case 'Absent':
        return Colors.red;
      case 'On Leave':
        return Colors.orange;
      case 'Half Day':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance',
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Employee or Status...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                      BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAttendance.isEmpty
                    ? Center(
                        child: Text(
                        'No records found.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ))
                    : RefreshIndicator(
                        onRefresh: _fetchAttendanceList,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredAttendance.length,
                          itemBuilder: (context, index) {
                            final attendance = _filteredAttendance[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getStatusColor(attendance['status'])
                                          .withOpacity(0.15),
                                  child: Text(
                                    attendance['employee_name']?[0] ?? 'N',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(
                                            attendance['status'])),
                                  ),
                                ),
                                title: Text(
                                  attendance['employee_name'] ?? 'Unknown',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87),
                                ),
                                subtitle: Text(
                                  'Date: ${_formatDate(attendance['attendance_date'])}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(color: Colors.black54),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        _getStatusColor(attendance['status']),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    attendance['status'] ?? 'N/A',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/attendanceDetails',
                                    arguments: {
                                      'attendance': attendance,
                                      'serverUrl': widget.serverUrl,
                                      'sid': widget.sid,
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
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
          // Month Selector
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
                    fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Counts
          GridView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            children: [
              _buildDashboardCard('Present', _presentCount, Colors.green,
                  _selectedStatus == 'Present'),
              _buildDashboardCard('Absent', _absentCount, Colors.red,
                  _selectedStatus == 'Absent'),
              _buildDashboardCard('On Leave', _leaveCount, Colors.orange,
                  _selectedStatus == 'On Leave'),
              _buildDashboardCard('Half Day', _halfDayCount, Colors.blueAccent,
                  _selectedStatus == 'Half Day'),
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
            border: isSelected ? Border.all(color: color, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]),
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
                        color: Theme.of(context).colorScheme.primary),
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
