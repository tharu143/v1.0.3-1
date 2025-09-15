import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class QuotationDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final Map<String, dynamic> quotation;

  const QuotationDetailScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    required this.quotation,
  });

  @override
  _QuotationDetailScreenState createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  Map<String, dynamic>? _qConnections;
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
    fetchQuotationConnections();
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

  Future<void> fetchQuotationConnections() async {
    setState(() => _isConnectionsLoading = true);

    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_quotation_connections';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
      };
      final body = json.encode({'quotation_name': widget.quotation['name']});

      print(
        'Fetching quotation connections: URL=$url, Headers=$headers, Body=$body',
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
            _qConnections = data['message'];
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
      print('Error fetching quotation connections: $e');
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
        setState(() => _isConnectionsLoading = false);
      }
    }
  }

  void _navigateToCreateSalesOrder() {
    Navigator.pushNamed(
      context,
      '/createSalesOrderFromQuotation',
      arguments: {
        'serverUrl': widget.serverUrl,
        'sid': widget.sid,
        'email': widget.email,
        'quotation': widget.quotation,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final avatarLetter = q['name']?.isNotEmpty == true
        ? q['name'][0].toUpperCase()
        : 'Q';
    final avatarColor =
        _letterColors[avatarLetter] ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          q['name'] ?? 'Quotation Details',
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
                        q['name'] ?? 'Quotation Details',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        softWrap: true,
                        maxLines: null,
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
                      _buildDetailRow(context, 'ID', q['name']),
                      _buildDetailRow(context, 'Title', q['title']),
                      _buildDetailRow(context, 'Party Name', q['party_name']),
                      _buildDetailRow(context, 'Status', q['status']),
                      _buildDetailRow(context, 'Date', q['transaction_date']),
                      _buildDetailRow(context, 'Valid Till', q['valid_till']),
                      _buildDetailRow(context, 'Order Type', q['order_type']),
                      _buildDetailRow(context, 'Owner', q['owner']),
                    ]),
                    const SizedBox(height: 8),
                    _buildDetailCard(context, 'Contact Info', [
                      _buildDetailRow(
                        context,
                        'Contact Person',
                        q['contact_person'],
                      ),
                      _buildDetailRow(
                        context,
                        'Contact Email',
                        q['contact_email'],
                      ),
                      _buildDetailRow(
                        context,
                        'Contact Mobile',
                        q['contact_mobile'],
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _buildDetailCard(context, 'Totals', [
                      _buildDetailRow(
                        context,
                        'Total Quantity',
                        q['total_qty'],
                      ),
                      _buildDetailRow(context, 'Net Total', q['net_total']),
                      _buildDetailRow(
                        context,
                        'Taxes and Charges',
                        q['total_taxes_and_charges'],
                      ),
                      _buildDetailRow(
                        context,
                        'Grand Total',
                        q['base_grand_total'],
                      ),
                      _buildDetailRow(context, 'In Words', q['base_in_words']),
                    ]),
                    const SizedBox(height: 8),
                    _buildItemsCard(context, 'Items', q['items']),
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
                : _qConnections != null
                ? _buildConnectionSection(
                    context,
                    label: 'Sales Orders',
                    items: _qConnections!['sales_orders'] as List?,
                    onAdd: _navigateToCreateSalesOrder,
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
                final itemName = item as String?;
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
                'No items in this quotation.',
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
