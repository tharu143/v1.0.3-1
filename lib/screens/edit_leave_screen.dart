import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class EditLeaveScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final Map<String, dynamic> leave;
  final VoidCallback onLeaveUpdated;

  const EditLeaveScreen({
    required this.serverUrl,
    required this.sid,
    required this.leave,
    required this.onLeaveUpdated,
  });

  @override
  _EditLeaveScreenState createState() => _EditLeaveScreenState();
}

class _EditLeaveScreenState extends State<EditLeaveScreen> {
  File? attachment;
  String? attachmentName;

  Future<void> _pickAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          attachment = File(result.files.single.path!);
          attachmentName = result.files.single.name;
        });
        print('Attachment picked: $attachmentName');
      }
    } catch (e) {
      print('Error picking attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error picking attachment: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _uploadAttachment(String leaveId) async {
    if (attachment == null) return null;

    final url = '${widget.serverUrl}/api/method/upload_file';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Accept': 'application/json',
    };

    var request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll(headers)
      ..fields['doctype'] = 'Leave Application'
      ..fields['docname'] = leaveId
      ..fields['fieldname'] = 'attachment'
      ..files.add(await http.MultipartFile.fromPath('file', attachment!.path,
          filename: attachmentName));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Upload Attachment Response Status: ${response.statusCode}');
      print('Upload Attachment Response Body: $responseBody');
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data['message']['file_url'] as String?;
      } else {
        throw Exception(
            'Failed to upload attachment: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Error uploading attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error uploading attachment: $e'),
            backgroundColor: Colors.red),
      );
      return null;
    }
  }

  Future<void> _submitLeaveApplication() async {
    final leaveId = widget.leave['name'];
    final url = '${widget.serverUrl}/api/resource/Leave Application/$leaveId';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // First, upload the attachment if it exists
    String? fileUrl;
    if (attachment != null) {
      fileUrl = await _uploadAttachment(leaveId);
      if (fileUrl == null) return; // Stop if attachment upload fails
    }

    // Then, update the leave application with the attachment and status
    final body = json.encode({
      'status': 'Open',
      if (fileUrl != null) 'attachment': fileUrl,
    });

    try {
      final response =
          await http.put(Uri.parse(url), headers: headers, body: body);
      print('Leave Update Response Status: ${response.statusCode}');
      print('Leave Update Response Body: ${response.body}');
      if (response.statusCode == 200) {
        Navigator.pop(context);
        widget.onLeaveUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Leave application submitted successfully (ID: $leaveId)'),
              backgroundColor: Colors.green),
        );
      } else {
        throw Exception(
            'Failed to submit leave: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error submitting leave application: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error submitting leave application: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Sick Leave Application',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Leave ID: ${widget.leave['name']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Employee: ${widget.leave['employee_name']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Leave Type: ${widget.leave['leave_type']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'From Date: ${widget.leave['from_date']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'To Date: ${widget.leave['to_date']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason: ${widget.leave['reason'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                            attachmentName ?? 'Attach Medical Certificate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      attachment != null ? _submitLeaveApplication : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: Size(double.infinity,
                        MediaQuery.of(context).size.height * 0.07),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Submit Leave Application',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
