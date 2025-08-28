import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OpportunityDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final Map<String, dynamic> opportunity;

  const OpportunityDetailScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    required this.opportunity,
  }) : super(key: key);

  @override
  _OpportunityDetailScreenState createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  Map<String, dynamic>? _oppConnections;
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
    fetchOpportunityConnections();
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

  Future<void> fetchOpportunityConnections() async {
    setState(() => _isConnectionsLoading = true);

    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_opportunity_connections';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
      };
      final body = json.encode({
        'opportunity_name': widget.opportunity['name'],
      });

      print(
        'Fetching opportunity connections: URL=$url, Headers=$headers, Body=$body',
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
            _oppConnections = data['message'];
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
      print('Error fetching opportunity connections: $e');
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
        setState(() => _isConnectionsLoading = false);
      }
    }
  }

  void _navigateToCreateQuotation() {
    if (widget.opportunity['opportunity_from'] == 'Lead' &&
        widget.opportunity['party_name'] != null) {
      final leadDataForQuotation = {
        'name': widget.opportunity['party_name'],
        'lead_name': widget.opportunity['party_name'],
        'lead_owner': widget.opportunity['opportunity_owner'],
      };
      Navigator.pushNamed(
        context,
        '/createQuotationFromLead',
        arguments: {
          'serverUrl': widget.serverUrl,
          'sid': widget.sid,
          'email': widget.email,
          'lead': leadDataForQuotation,
        },
      );
    } else {
      showApiErrorDialog(
        context,
        message:
            'Quotations can only be created for opportunities that originated from a Lead.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final opp = widget.opportunity;
    final avatarLetter = opp['name']?.isNotEmpty == true
        ? opp['name'][0].toUpperCase()
        : 'O';
    final avatarColor =
        _letterColors[avatarLetter] ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          opp['name'] ?? 'Opportunity Details',
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
                        opp['name'] ?? 'Opportunity Details',
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
                      _buildDetailRow(context, 'ID', opp['name']),
                      _buildDetailRow(context, 'Title', opp['title']),
                      _buildDetailRow(context, 'From', opp['opportunity_from']),
                      _buildDetailRow(context, 'Party Name', opp['party_name']),
                      _buildDetailRow(context, 'Status', opp['status']),
                      _buildDetailRow(context, 'Type', opp['opportunity_type']),
                      _buildDetailRow(
                        context,
                        'Owner',
                        opp['opportunity_owner'],
                      ),
                      _buildDetailRow(
                        context,
                        'Sales Stage',
                        opp['sales_stage'],
                      ),
                      _buildDetailRow(
                        context,
                        'Probability',
                        '${opp['probability']}%',
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _buildDetailCard(context, 'Organization', [
                      _buildDetailRow(context, 'Company', opp['company']),
                      _buildDetailRow(context, 'Territory', opp['territory']),
                      _buildDetailRow(context, 'Industry', opp['industry']),
                    ]),
                    const SizedBox(height: 8),
                    _buildDetailCard(context, 'Opportunity Value', [
                      _buildDetailRow(
                        context,
                        'Amount',
                        opp['opportunity_amount'],
                      ),
                      _buildDetailRow(context, 'Total', opp['total']),
                    ]),
                    const SizedBox(height: 8),
                    _buildDetailCard(context, 'Address & Contact', [
                      _buildDetailRow(context, 'Country', opp['country']),
                      _buildDetailRow(context, 'City', opp['city']),
                      _buildDetailRow(context, 'State', opp['state']),
                      _buildDetailRow(context, 'Phone', opp['phone']),
                      _buildDetailRow(context, 'Email', opp['contact_email']),
                      _buildDetailRow(context, 'Website', opp['website']),
                    ]),
                    const SizedBox(height: 8),
                    _buildItemsCard(context, 'Items', opp['items']),
                    const SizedBox(height: 8),
                    _buildNotesCard(context, 'Notes', opp['notes']),
                    const SizedBox(height: 8),
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
                : _oppConnections != null
                ? Column(
                    children: [
                      _buildConnectionSection(
                        context,
                        label: 'Quotations',
                        items: _oppConnections!['quotations'] as List?,
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
                    softWrap: true,
                    maxLines: null,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildItemsCard(
    BuildContext context,
    String title,
    List<dynamic>? items,
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
            if (items == null || items.isEmpty)
              Text(
                'No items in this opportunity.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
              )
            else
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['item_name'] ?? 'No Name',
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true,
                        maxLines: null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${item['qty']?.toString() ?? 'N/A'} | Rate: ${item['rate']?.toString() ?? 'N/A'} | Amount: ${item['amount']?.toString() ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.grey[700],
                        ),
                        softWrap: true,
                        maxLines: null,
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
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stripHtmlIfNeeded(note['note']),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.grey[800],
                        ),
                        softWrap: true,
                        maxLines: null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By: ${note['added_by']?.toString() ?? 'N/A'} on ${note['added_on']?.toString() ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.grey[600],
                        ),
                        softWrap: true,
                        maxLines: null,
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
              softWrap: true,
              maxLines: null,
            ),
          ),
        ],
      ),
    );
  }
}
