import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // For date formatting

class TaskDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String taskName; // The unique ID of the task

  const TaskDetailScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.taskName,
  }) : super(key: key);

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? taskDetails;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTaskDetails();
  }

  Future<void> _fetchTaskDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = '${widget.serverUrl}/api/resource/Task/${widget.taskName}';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          taskDetails = data['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load task details: ${response.statusCode}';
          isLoading = false;
        });
        print(
            'Failed to load task details: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching task details: $e';
        isLoading = false;
      });
      print('Error fetching task details: $e');
    }
  }

  // Function to remove HTML tags from a string
  String _removeHtmlTags(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Widget _buildInfoCard({required String title, required Widget content}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: valueStyle ?? const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          taskDetails?['subject'] ?? 'Task Details',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary))
            : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Basic Information
                        _buildInfoCard(
                          title: 'Basic Information',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Name', taskDetails?['name']),
                              _buildDetailRow(
                                  'Subject', taskDetails?['subject']),
                              _buildDetailRow('Status', taskDetails?['status'],
                                  valueStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: taskDetails?['status'] == 'Completed'
                                        ? Colors.green
                                        : (taskDetails?['status'] == 'Open'
                                            ? Colors.blue
                                            : Colors.red),
                                  )),
                              _buildDetailRow(
                                  'Priority', taskDetails?['priority']),
                              _buildDetailRow('Type', taskDetails?['type']),
                              _buildDetailRow(
                                  'Project', taskDetails?['project']),
                              _buildDetailRow('Issue', taskDetails?['issue']),
                            ],
                          ),
                        ),

                        // Dates and Times
                        _buildInfoCard(
                          title: 'Dates & Times',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                'Expected Start Date',
                                taskDetails?['exp_start_date'],
                              ),
                              _buildDetailRow(
                                'Expected End Date',
                                taskDetails?['exp_end_date'],
                              ),
                              _buildDetailRow('Expected Time (hours)',
                                  taskDetails?['expected_time']?.toString()),
                              _buildDetailRow('Actual Time (hours)',
                                  taskDetails?['actual_time']?.toString()),
                              _buildDetailRow(
                                  'Creation Date',
                                  taskDetails?['creation'] != null
                                      ? DateFormat('yyyy-MM-dd HH:mm').format(
                                          DateTime.parse(
                                              taskDetails!['creation']))
                                      : 'N/A'),
                              _buildDetailRow(
                                  'Modified Date',
                                  taskDetails?['modified'] != null
                                      ? DateFormat('yyyy-MM-dd HH:mm').format(
                                          DateTime.parse(
                                              taskDetails!['modified']))
                                      : 'N/A'),
                            ],
                          ),
                        ),

                        // Progress
                        _buildInfoCard(
                          title: 'Progress',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Progress (%)',
                                  taskDetails?['progress']?.toString()),
                              _buildDetailRow('Task Weight',
                                  taskDetails?['task_weight']?.toString()),
                            ],
                          ),
                        ),

                        // Description
                        if (taskDetails?['description'] != null &&
                            taskDetails!['description'].isNotEmpty)
                          _buildInfoCard(
                            title: 'Description',
                            content: Text(
                              _removeHtmlTags(taskDetails![
                                  'description']), // Remove HTML tags
                              style: const TextStyle(
                                fontSize: 14.0,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                        // Other Details
                        _buildInfoCard(
                          title: 'Other Details',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Owner', taskDetails?['owner']),
                              _buildDetailRow(
                                  'Company', taskDetails?['company']),
                              _buildDetailRow(
                                  'Department', taskDetails?['department']),
                              _buildDetailRow('Docstatus',
                                  taskDetails?['docstatus']?.toString()),
                              _buildDetailRow(
                                  'Parent Task', taskDetails?['parent_task']),
                              _buildDetailRow('Is Milestone',
                                  taskDetails?['is_milestone']?.toString()),
                              _buildDetailRow('Is Group',
                                  taskDetails?['is_group']?.toString()),
                              _buildDetailRow('Is Template',
                                  taskDetails?['is_template']?.toString()),
                              _buildDetailRow(
                                  'Total Costing Amount',
                                  taskDetails?['total_costing_amount']
                                      ?.toString()),
                              _buildDetailRow(
                                  'Total Expense Claim',
                                  taskDetails?['total_expense_claim']
                                      ?.toString()),
                              _buildDetailRow(
                                  'Total Billing Amount',
                                  taskDetails?['total_billing_amount']
                                      ?.toString()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
