import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/payment_entry.dart';

class PaymentEntryDetailScreen extends StatefulWidget {
  final PaymentEntry paymentEntry;
  final String serverUrl;
  final String sid;

  const PaymentEntryDetailScreen({
    super.key,
    required this.paymentEntry,
    required this.serverUrl,
    required this.sid,
  });

  @override
  _PaymentEntryDetailScreenState createState() =>
      _PaymentEntryDetailScreenState();
}

class _PaymentEntryDetailScreenState extends State<PaymentEntryDetailScreen> {
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

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.paymentEntry;
    final avatarLetter = entry.name?.isNotEmpty == true
        ? entry.name![0].toUpperCase()
        : 'P';
    final avatarColor =
        _letterColors[avatarLetter] ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          entry.name ?? 'Payment Entry Details',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                        entry.name ?? 'Payment Entry Details',
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
                      _buildInfoRow(context, 'Payment Type', entry.paymentType),
                      _buildInfoRow(
                        context,
                        'Posting Date',
                        formatDate(entry.postingDate),
                      ),
                      _buildInfoRow(context, 'Company', entry.company),
                      _buildInfoRow(
                        context,
                        'Mode of Payment',
                        entry.modeOfPayment,
                      ),
                      _buildInfoRow(context, 'Party Type', entry.partyType),
                      _buildInfoRow(context, 'Party', entry.party),
                      _buildInfoRow(context, 'Party Name', entry.partyName),
                      _buildInfoRow(context, 'Paid From', entry.paidFrom),
                      _buildInfoRow(context, 'Paid To', entry.paidTo),
                      _buildInfoRow(
                        context,
                        'Paid Amount',
                        entry.paidAmount != null
                            ? 'AED ${entry.paidAmount!.toStringAsFixed(2)}'
                            : 'N/A',
                      ),
                      _buildInfoRow(context, 'Status', entry.status),
                      _buildInfoRow(
                        context,
                        'PDC Cleared',
                        entry.pdcCleared == true ? 'Yes' : 'No',
                      ),
                      _buildInfoRow(context, 'Created By', entry.owner),
                      _buildInfoRow(
                        context,
                        'Created On',
                        formatDate(entry.creation),
                      ),
                      _buildInfoRow(context, 'Modified By', entry.modifiedBy),
                      _buildInfoRow(
                        context,
                        'Modified On',
                        formatDate(entry.modified),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _buildDetailCard(context, 'Remarks', [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          _stripHtmlIfNeeded(entry.remarks) ?? 'No remarks',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: Colors.grey[800]),
                          softWrap: true,
                          maxLines: null,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
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

  Widget _buildInfoRow(BuildContext context, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
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
              value ?? 'N/A',
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
