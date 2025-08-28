import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
// Import the new TaskDetailScreen
import 'task_detail_screen.dart'; // Make sure this path is correct

class TaskListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const TaskListScreen({required this.serverUrl, required this.sid, super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<dynamic> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  // Fetch tasks from the server
  Future<void> fetchTasks() async {
    setState(() => isLoading = true);
    final url =
        '${widget.serverUrl}/api/resource/Task?fields=["name","subject","status","exp_end_date"]';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          tasks = jsonDecode(response.body)['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load tasks: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching tasks: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks', style: TextStyle(color: Colors.white)),
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
              Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.1), // Adjusted for a softer gradient base
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary))
            : tasks.isEmpty
                ? const Center(
                    child: Text(
                      'No tasks found',
                      style: TextStyle(
                          color: Colors.black54,
                          fontSize:
                              18), // Adjusted text color for readability on background
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(
                            vertical: 8.0), // Added vertical margin
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0), // Added padding
                          title: Text(
                            task['subject'] ?? 'Untitled Task',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16, // Slightly larger title
                            ),
                          ),
                          subtitle: Text(
                            'Due: ${task['exp_end_date'] ?? 'N/A'}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 14),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: task['status'] == 'Completed'
                                  ? Colors.green.shade100
                                  : (task['status'] == 'Open'
                                      ? Colors.blue.shade100
                                      : Colors.red.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task['status'] ?? 'Open',
                              style: TextStyle(
                                color: task['status'] == 'Completed'
                                    ? Colors.green.shade800
                                    : (task['status'] == 'Open'
                                        ? Colors.blue.shade800
                                        : Colors.red.shade800),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () {
                            // Navigate to TaskDetailScreen with task name
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailScreen(
                                  serverUrl: widget.serverUrl,
                                  sid: widget.sid,
                                  taskName: task[
                                      'name'], // Pass the unique task name (ID)
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/createTask',
            arguments: {
              'serverUrl': widget.serverUrl,
              'sid': widget.sid,
            }).then(
            (_) => fetchTasks()), // Refresh list when returning from CreateTask
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        tooltip: 'Create New Task',
      ),
    );
  }
}
