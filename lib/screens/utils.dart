import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

// Utility function to format date (e.g., 18-04-2025)
String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'N/A';
  try {
    DateTime date = DateTime.parse(dateStr);
    return DateFormat('dd-MM-yyyy').format(date);
  } catch (e) {
    return dateStr ?? 'N/A';
  }
}

// Utility function to format time (e.g., 10:10:00)
String formatTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return 'N/A';
  try {
    DateTime dateTime = DateFormat('HH:mm:ss.SSSSSS').parse(timeStr);
    return DateFormat('HH:mm:ss').format(dateTime);
  } catch (e) {
    return timeStr ?? 'N/A';
  }
}

// Utility function to generate customer section for PDF
Future<pw.Widget> generateCustomerSection(
    Map<String, dynamic> deliveryNote) async {
  final hasPoNo =
      deliveryNote['po_no'] != null && deliveryNote['po_no'].isNotEmpty;
  final customerLabels = [
    'Customer Name:',
    'Billing Address:',
    if (deliveryNote['tax_id'] != null && deliveryNote['tax_id'].isNotEmpty)
      'Tax Id:',
    if (deliveryNote['contact_person'] != null &&
        deliveryNote['contact_person'].isNotEmpty)
      'Contact:',
    if (deliveryNote['mobile_no'] != null &&
        deliveryNote['mobile_no'].isNotEmpty)
      'Mobile No:',
  ];
  final customerData = [
    deliveryNote['customer_name'] ?? 'N/A',
    deliveryNote['address_display']?.replaceAll(RegExp(r'<[^>]+>'), '') ??
        'N/A',
    if (deliveryNote['tax_id'] != null && deliveryNote['tax_id'].isNotEmpty)
      deliveryNote['tax_id'],
    if (deliveryNote['contact_person'] != null &&
        deliveryNote['contact_person'].isNotEmpty)
      deliveryNote['contact_person'],
    if (deliveryNote['mobile_no'] != null &&
        deliveryNote['mobile_no'].isNotEmpty)
      deliveryNote['mobile_no'],
  ];
  final orderLabels = [
    'Date:',
    if (hasPoNo) "Customer's Purchase Order No:",
    'Tax Id:',
    'Company Address:',
  ];
  final orderData = [
    formatDate(deliveryNote['posting_date']) ?? 'N/A',
    if (hasPoNo) deliveryNote['po_no'],
    deliveryNote['company_tax_id'] ?? '100022146300003',
    'Office No 1 Al Awar Building D79 Bur Dubai, Dubai, United Arab Emirates\nPhone: +971 4 323 1008, Email: info@keplertech.ae',
  ];

  final maxRows = customerLabels.length > orderLabels.length
      ? customerLabels.length
      : orderLabels.length;

  return pw.Table(
    columnWidths: {
      0: pw.FlexColumnWidth(1),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1),
    },
    children: List.generate(maxRows, (index) {
      return pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: pw.Text(
              index < customerLabels.length ? customerLabels[index] : '',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: pw.Text(
              index < customerData.length ? customerData[index] : '',
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: pw.Text(
              index < orderLabels.length ? orderLabels[index] : '',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: pw.Text(
              index < orderData.length ? orderData[index] : '',
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      );
    }),
  );
}

// Utility function to load logo image for PDF
Future<pw.MemoryImage?> loadLogoImage() async {
  try {
    final byteData = await rootBundle.load('assets/images/logo.png');
    return pw.MemoryImage(byteData.buffer.asUint8List());
  } catch (e) {
    print('Error loading logo: $e');
    return null;
  }
}

// Utility function to remove HTML tags from a string
String removeHtmlTags(String? htmlString) {
  if (htmlString == null || htmlString.isEmpty) return 'N/A';
  final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
  return htmlString.replaceAll(exp, '').trim();
}
