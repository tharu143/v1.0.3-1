import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> attendance;
  final String serverUrl;
  final String sid;

  const AttendanceDetailsScreen({
    Key? key,
    required this.attendance,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _AttendanceDetailsScreenState createState() =>
      _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String? status) {
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

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Present':
      case 'Work From Home':
        return Icons.check_circle_outline;
      case 'Absent':
        return Icons.cancel_outlined;
      case 'On Leave':
        return Icons.beach_access_outlined;
      case 'Half Day':
        return Icons.hourglass_bottom_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240.0, // Increased height for better spacing
            backgroundColor: Theme.of(context).colorScheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.info_outline), text: 'Details'),
                Tab(icon: Icon(Icons.person_outline), text: 'Employee'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsView(),
                _buildEmployeeInfoView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final status = widget.attendance['status'] ?? 'N/A';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7)
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                child: Text(
                  widget.attendance['employee_name']?[0] ?? 'U',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.attendance['employee_name'] ?? 'Details',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black26)]),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'General Information',
          icon: Icons.article_outlined,
          children: [
            _buildDetailItem(
                Icons.fingerprint, 'Attendance ID', widget.attendance['name']),
            _buildDetailItem(Icons.calendar_today_outlined, 'Date',
                formatDate(widget.attendance['attendance_date'])),
            _buildDetailItem(Icons.business_outlined, 'Company',
                widget.attendance['company']),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Work Details',
          icon: Icons.work_outline,
          children: [
            _buildDetailItem(Icons.hourglass_empty_outlined, 'Working Hours',
                widget.attendance['working_hours']?.toString()),
            _buildDetailItem(Icons.call_missed_outgoing_outlined, 'Late Entry',
                widget.attendance['late_entry'] == 1 ? 'Yes' : 'No'),
            _buildDetailItem(Icons.call_missed_outlined, 'Early Exit',
                widget.attendance['early_exit'] == 1 ? 'No' : 'Yes'),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeeInfoView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Employee Information',
          icon: Icons.person_search_outlined,
          children: [
            _buildDetailItem(Icons.badge_outlined, 'Employee ID',
                widget.attendance['employee']),
            _buildDetailItem(Icons.person_outline, 'Employee Name',
                widget.attendance['employee_name']),
            _buildDetailItem(Icons.group_work_outlined, 'Department',
                widget.attendance['department']),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Record Information',
          icon: Icons.edit_note_outlined,
          children: [
            _buildDetailItem(Icons.person_add_alt_1_outlined, 'Created By',
                widget.attendance['owner']),
            _buildDetailItem(Icons.access_time_outlined, 'Created On',
                formatDateTime(widget.attendance['creation'])),
            _buildDetailItem(Icons.person_outline, 'Modified By',
                widget.attendance['modified_by']),
            _buildDetailItem(Icons.update_outlined, 'Modified On',
                formatDateTime(widget.attendance['modified'])),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
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
                Icon(icon,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
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

  Widget _buildDetailItem(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${value ?? 'N/A'}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d, y, hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }
}
