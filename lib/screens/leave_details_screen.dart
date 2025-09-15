import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/error_handler.dart'; // Import the custom error handler

class LeaveDetailsScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final Map<String, dynamic> leave;
  final VoidCallback onLeaveUpdated;

  const LeaveDetailsScreen({
    required this.serverUrl,
    required this.sid,
    required this.leave,
    required this.onLeaveUpdated,
    super.key,
  });

  @override
  _LeaveDetailsScreenState createState() => _LeaveDetailsScreenState();
}

class _LeaveDetailsScreenState extends State<LeaveDetailsScreen>
    with SingleTickerProviderStateMixin {
  File? _attachment;
  String? _attachmentName;
  String? _fetchedAttachmentUrl;
  bool _isUploading = false;
  bool _isLoadingAttachment = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAttachmentUrl();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttachmentUrl() async {
    if (widget.leave['name'] == null) return;
    setState(() => _isLoadingAttachment = true);
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_leave_attachment?leave_application_id=${widget.leave['name']}';
    final headers = {'Cookie': 'sid=${widget.sid}'};
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success' &&
            data['message']['file_url'] != null) {
          if (!mounted) return;
          setState(() {
            _fetchedAttachmentUrl =
                '${widget.serverUrl}${data['message']['file_url']}';
          });
        }
      }
    } catch (e) {
      // Handle error silently for fetching, as it's not critical
      print("Error fetching attachment URL: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAttachment = false);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachment = File(result.files.single.path!);
          _attachmentName = result.files.single.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: "Error picking file: $e");
    }
  }

  Future<void> _uploadOnlyAttachment() async {
    if (_attachment == null) {
      showApiErrorDialog(
        context,
        message: 'Please select a file to upload first.',
      );
      return;
    }
    setState(() => _isUploading = true);

    final leaveId = widget.leave['name'];
    final uploadUrl =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.upload_leave_attachment';
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..headers['Cookie'] = 'sid=${widget.sid}'
      ..fields['leave_application_id'] = leaveId
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          _attachment!.path,
          filename: _attachmentName,
        ),
      );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attachment uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchAttachmentUrl();
          setState(() {
            _attachment = null;
            _attachmentName = null;
          });
        } else {
          if (!mounted) return;
          showApiErrorDialog(
            context,
            message: data['message']['message'] ?? 'Unknown upload error',
          );
        }
      } else {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitForApproval() async {
    final leaveId = widget.leave['name'];
    if (leaveId == null) return;
    if (_attachment == null &&
        _fetchedAttachmentUrl == null &&
        widget.leave['leave_type'] == 'Sick Leave') {
      showApiErrorDialog(
        context,
        message: 'Sick Leave requires a medical certificate to be attached.',
      );
      return;
    }

    setState(() => _isUploading = true);

    if (_attachment != null) {
      final uploadUrl =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.upload_leave_attachment';
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..headers['Cookie'] = 'sid=${widget.sid}'
        ..fields['leave_application_id'] = leaveId
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            _attachment!.path,
            filename: _attachmentName,
          ),
        );

      try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['message']['status'] != 'success') {
            if (!mounted) return;
            showApiErrorDialog(
              context,
              message: data['message']['message'] ?? 'Unknown upload error',
            );
            setState(() => _isUploading = false);
            return;
          }
        } else {
          if (!mounted) return;
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
          setState(() => _isUploading = false);
          return;
        }
      } catch (e) {
        if (!mounted) return;
        showApiErrorDialog(context, message: e.toString());
        setState(() => _isUploading = false);
        return;
      }
    }

    final updateUrl =
        '${widget.serverUrl}/api/resource/Leave Application/$leaveId';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };
    final body = json.encode({'status': 'Open'});

    try {
      final response = await http.put(
        Uri.parse(updateUrl),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        widget.onLeaveUpdated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave submitted for approval!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Helper to check if a filename is an image.
  bool _isImageFile(String? fileName) {
    if (fileName == null) return false;
    final lowercased = fileName.toLowerCase();
    return lowercased.endsWith('.jpg') ||
        lowercased.endsWith('.jpeg') ||
        lowercased.endsWith('.png');
  }

  /// Shows a dialog to preview an image widget.
  void _showPreviewDialog(Widget imageWidget, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  title,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: imageWidget,
                ),
              ),
            ],
          ),
        );
      },
    );
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
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240.0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              tabs: const [
                Tab(icon: Icon(Icons.description_outlined), text: 'Details'),
                Tab(icon: Icon(Icons.attachment_outlined), text: 'Attachment'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDetailsView(), _buildAttachmentView()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.leave['status'] == 'Draft'
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _submitForApproval,
                icon: _isUploading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_outline),
                label: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit for Approval'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    final status = widget.leave['status'] ?? 'N/A';
    final statusColor = _getStatusColor(status);
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
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                child: Text(
                  (widget.leave['employee_name'] ?? 'U')[0],
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.leave['employee_name'] ?? 'Details',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
          title: 'Leave Information',
          icon: Icons.date_range_outlined,
          children: [
            _buildDetailItem(
              Icons.badge_outlined,
              'Leave Type',
              widget.leave['leave_type'],
            ),
            _buildDetailItem(
              Icons.calendar_view_day_outlined,
              'From Date',
              formatDate(widget.leave['from_date']),
            ),
            _buildDetailItem(
              Icons.calendar_view_day,
              'To Date',
              formatDate(widget.leave['to_date']),
            ),
            _buildDetailItem(
              Icons.format_list_numbered_outlined,
              'Total Days',
              widget.leave['total_leave_days']?.toString(),
            ),
            _buildDetailItem(
              Icons.description_outlined,
              'Reason',
              widget.leave['description'],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Approval Information',
          icon: Icons.person_search_outlined,
          children: [
            _buildDetailItem(
              Icons.engineering_outlined,
              'Leave Approver',
              widget.leave['leave_approver'],
            ),
            _buildDetailItem(
              Icons.business_outlined,
              'Company',
              widget.leave['company'],
            ),
            _buildDetailItem(
              Icons.edit_note_outlined,
              'Posting Date',
              formatDate(widget.leave['posting_date']),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentView() {
    bool isSickLeave = widget.leave['leave_type'] == 'Sick Leave';
    bool hasNoAttachmentOnServer = _fetchedAttachmentUrl == null;
    bool isDraft = widget.leave['status'] == 'Draft';

    bool canSelectFile = isDraft || (isSickLeave && hasNoAttachmentOnServer);
    bool showUploadButton =
        !isDraft &&
        isSickLeave &&
        hasNoAttachmentOnServer &&
        _attachment != null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attachment",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(height: 24),
                  if (_isLoadingAttachment)
                    const Center(child: CircularProgressIndicator())
                  else if (_fetchedAttachmentUrl != null)
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.file_present_rounded,
                            color: Colors.blue,
                          ),
                          title: Text(
                            _fetchedAttachmentUrl!.split('/').last,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          onTap: () async {
                            final uri = Uri.parse(_fetchedAttachmentUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                        if (_isImageFile(_fetchedAttachmentUrl))
                          TextButton.icon(
                            onPressed: () => _showPreviewDialog(
                              Image.network(_fetchedAttachmentUrl!),
                              _fetchedAttachmentUrl!.split('/').last,
                            ),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Preview Attachment'),
                          ),
                      ],
                    )
                  else if (_attachmentName != null)
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(_attachmentName!),
                          trailing: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () => setState(() {
                              _attachment = null;
                              _attachmentName = null;
                            }),
                          ),
                        ),
                        if (_isImageFile(_attachmentName))
                          TextButton.icon(
                            onPressed: () {
                              if (_attachment != null) {
                                _showPreviewDialog(
                                  Image.file(_attachment!),
                                  _attachmentName!,
                                );
                              }
                            },
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Preview Selected File'),
                          ),
                      ],
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No attachment found."),
                      ),
                    ),
                ],
              ),
              if (canSelectFile && hasNoAttachmentOnServer)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickAttachment,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(
                        _attachmentName == null
                            ? 'Select Attachment'
                            : 'Change Attachment',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    if (showUploadButton)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : _uploadOnlyAttachment,
                          icon: _isUploading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.cloud_upload),
                          label: _isUploading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Upload Attachment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
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

  Widget _buildDetailItem(IconData icon, String label, dynamic value) {
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
              '${value ?? 'N/A'}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      return DateFormat('MMMM d, y').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }
}
