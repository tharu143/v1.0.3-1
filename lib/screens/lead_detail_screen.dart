import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeadDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final Map<String, dynamic> lead;

  const LeadDetailScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    required this.lead,
  }) : super(key: key);

  @override
  _LeadDetailScreenState createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Map<String, dynamic>? _leadConnections;
  bool _isConnectionsLoading = true;

  final Map<String, Color> _letterColors = {
    'A': const Color(0xFF0074c9),
    'B': const Color(0xFF005B99),
    'C': const Color(0xFF003087),
    'D': const Color(0xFF1E90FF),
    'E': const Color(0xFF4682B4),
    'F': const Color(0xFF6495ED),
    'G': const Color(0xFF00B7EB),
    'H': const Color(0xFF4169E1),
    'I': const Color(0xFF87CEEB),
    'J': const Color(0xFF1C86EE),
    'K': const Color(0xFF104E8B),
    'L': const Color(0xFF63B8FF),
    'M': const Color(0xFF00CED1),
    'N': const Color(0xFF5CACEE),
    'O': const Color(0xFF1874CD),
    'P': const Color(0xFF7B68EE),
    'Q': const Color(0xFF8470FF),
    'R': const Color(0xFF6A5ACD),
    'S': const Color(0xFF483D8B),
    'T': const Color(0xFF00BFFF),
    'U': const Color(0xFF20B2AA),
    'V': const Color(0xFF3A5FCD),
    'W': const Color(0xFF4A708B),
    'X': const Color(0xFF607B8B),
    'Y': const Color(0xFF7A67EE),
    'Z': const Color(0xFF1034A6),
  };

  @override
  void initState() {
    super.initState();
    fetchLeadConnections();
  }

  String _parseFrappeException(String responseBody) {
    try {
      final data = json.decode(responseBody);
      if (data['exception'] != null && data['exception'] is String) {
        List parts = data['exception'].split(':');
        if (parts.length > 1) {
          return parts.sublist(1).join(':').trim();
        }
        return data['exception'];
      }
      if (data['_server_messages'] != null) {
        final serverMessages = json.decode(data['_server_messages']);
        if (serverMessages is List && serverMessages.isNotEmpty) {
          return serverMessages
              .map((msg) => json.decode(msg)['message'].toString())
              .join('\n');
        }
      }
      if (data['message'] != null && data['message'] is String) {
        return data['message'];
      }
      return responseBody;
    } catch (e) {
      return responseBody;
    }
  }

  String _stripHtmlIfNeeded(String? text) {
    if (text == null) return 'N/A';
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  String getUserFriendlyMessage(int statusCode, String message) {
    final cleanMessage = _stripHtmlIfNeeded(_parseFrappeException(message));
    switch (statusCode) {
      case 200:
        return "Success: $cleanMessage";
      case 400:
        return "Bad Request: Please check your input. $cleanMessage";
      case 401:
        return "Unauthorized: Please check your credentials or session. $cleanMessage";
      case 403:
        return "Forbidden: You do not have permission to perform this action. $cleanMessage";
      case 404:
        return "Not Found: The requested resource could not be found. $cleanMessage";
      case 409:
        return "Conflict: The resource already exists or there is a conflict. $cleanMessage";
      case 417:
        return "Expectation Failed: The server could not meet the expectation. $cleanMessage";
      case 422:
        return "Unprocessable Entity: Please check the data you provided. $cleanMessage";
      case 500:
        return "Internal Server Error: Something went wrong on the server. Please try again later. $cleanMessage";
      default:
        return "An unexpected error occurred (Status Code: $statusCode). $cleanMessage";
    }
  }

  void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: title == 'Success'
                ? Theme.of(context).colorScheme.secondary
                : Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          _stripHtmlIfNeeded(message),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void showApiErrorDialog(
    BuildContext context, {
    int? statusCode,
    String message = "An unknown error occurred.",
  }) {
    String friendlyMessage;
    if (statusCode != null) {
      friendlyMessage = getUserFriendlyMessage(statusCode, message);
    } else {
      friendlyMessage = _stripHtmlIfNeeded(_parseFrappeException(message));
    }
    showErrorDialog(context, 'Error', friendlyMessage);
  }

  Future<void> fetchLeadConnections() async {
    setState(() => _isConnectionsLoading = true);

    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_lead_connections';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
      };
      final body = json.encode({'lead_name': widget.lead['name']});

      print(
        'Fetching lead connections: URL=$url, Headers=$headers, Body=$body',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _leadConnections = data['message'];
            _isConnectionsLoading = false;
          });
        }
      } else {
        if (mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
          setState(() => _isConnectionsLoading = false);
        }
      }
    } catch (e) {
      print('Error fetching lead connections: $e');
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
        setState(() => _isConnectionsLoading = false);
      }
    }
  }

  void _navigateToCreateOpportunity() {
    Navigator.pushNamed(
      context,
      '/createOpportunityFromLead',
      arguments: {
        'serverUrl': widget.serverUrl,
        'sid': widget.sid,
        'email': widget.email,
        'leadId': widget.lead['name'],
        'partyName': widget.lead['lead_name'],
        'opportunityOwner': widget.lead['lead_owner'],
      },
    );
  }

  void _navigateToCreateQuotation() {
    Navigator.pushNamed(
      context,
      '/createQuotationFromLead',
      arguments: {
        'serverUrl': widget.serverUrl,
        'sid': widget.sid,
        'email': widget.email,
        'lead': widget.lead,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final avatarLetter = lead['name']?.isNotEmpty == true
        ? lead['name'][0].toUpperCase()
        : 'L';
    final avatarColor =
        _letterColors[avatarLetter] ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          lead['name'] ?? 'Lead Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary, // 0xFF0074c9
                Theme.of(
                  context,
                ).colorScheme.secondary.withOpacity(0.8), // 0xFF005B99
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              margin: const EdgeInsets.only(
                top: 24,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: avatarColor,
                      radius: 30,
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lead['name'] ?? 'Lead Details',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailCard(context, 'Basic Information', [
                      _buildDetailRow(context, 'Lead ID', lead['name']),
                      _buildDetailRow(context, 'Lead Name', lead['lead_name']),
                      _buildDetailRow(context, 'Status', lead['status']),
                      _buildDetailRow(context, 'Source', lead['source']),
                      _buildDetailRow(
                        context,
                        'Lead Owner',
                        lead['lead_owner'],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailCard(context, 'Contact Info', [
                      _buildDetailRow(context, 'Phone', lead['phone']),
                      _buildDetailRow(context, 'Mobile No', lead['mobile_no']),
                      _buildDetailRow(context, 'Email', lead['email_id']),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailCard(context, 'Organization', [
                      _buildDetailRow(
                        context,
                        'Company Name',
                        lead['company_name'],
                      ),
                      _buildDetailRow(context, 'Industry', lead['industry']),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailCard(context, 'Address & Contacts', [
                      _buildDetailRow(context, 'Territory', lead['territory']),
                      _buildDetailRow(context, 'City', lead['city']),
                      _buildDetailRow(context, 'Country', lead['country']),
                    ]),
                    const SizedBox(height: 16),
                    _buildNotesCard(context, 'Notes', lead['notes']),
                    const SizedBox(height: 16),
                    _buildConnectionsCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Connections',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, thickness: 1),
            _isConnectionsLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : _leadConnections != null
                ? Column(
                    children: [
                      _buildConnectionSection(
                        context,
                        label: 'Opportunities',
                        items: _leadConnections!['opportunities'] as List?,
                        onAdd: _navigateToCreateOpportunity,
                      ),
                      const SizedBox(height: 12),
                      _buildConnectionSection(
                        context,
                        label: 'Quotations',
                        items: _leadConnections!['quotations'] as List?,
                        onAdd: _navigateToCreateQuotation,
                      ),
                    ],
                  )
                : Text(
                    'Could not load connections.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(
    BuildContext context, {
    required String label,
    required List<dynamic>? items,
    VoidCallback? onAdd,
  }) {
    final int count = items?.length ?? 0;
    final bool hasItems = items != null && items.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                count.toString(),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge!.copyWith(color: Colors.grey[800]),
                textAlign: TextAlign.start,
              ),
            ),
            if (onAdd != null)
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                onPressed: onAdd,
                tooltip: 'Create new $label',
              ),
          ],
        ),
        if (hasItems)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final itemName = item['name'] as String?;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    '- ${itemName ?? "Unknown"}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesCard(
    BuildContext context,
    String title,
    List<dynamic>? notes,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, thickness: 1),
            if (notes == null || notes.isEmpty)
              Text(
                'No notes available.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
              )
            else
              ...notes.map((note) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stripHtmlIfNeeded(note['note']),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By: ${note['added_by'] ?? 'N/A'} on ${note['added_on'] ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Divider(),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(color: Colors.grey[800]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
