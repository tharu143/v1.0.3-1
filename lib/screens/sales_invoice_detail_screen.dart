import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class SalesInvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  final String serverUrl;
  final String sid;

  const SalesInvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _SalesInvoiceDetailScreenState createState() =>
      _SalesInvoiceDetailScreenState();
}

class _SalesInvoiceDetailScreenState extends State<SalesInvoiceDetailScreen> {
  Map<String, dynamic> invoiceDetails = {};
  bool isLoading = true;
  String errorMessage = '';

  // Define unique colors for each of the 26 English letters (blue-centric, same as other screens)
  final Map<String, Color> _letterColors = {
    'A': const Color(0xFF0074c9), // Primary blue
    'B': const Color(0xFF005B99), // Secondary blue
    'C': const Color(0xFF003087), // Darker blue
    'D': const Color(0xFF1E90FF), // Dodger blue
    'E': const Color(0xFF4682B4), // Steel blue
    'F': const Color(0xFF6495ED), // Cornflower blue
    'G': const Color(0xFF00B7EB), // Cyan blue
    'H': const Color(0xFF4169E1), // Royal blue
    'I': const Color(0xFF87CEEB), // Sky blue
    'J': const Color(0xFF1C86EE), // Bright blue
    'K': const Color(0xFF104E8B), // Navy blue
    'L': const Color(0xFF63B8FF), // Light blue
    'M': const Color(0xFF00CED1), // Dark cyan (blue-ish)
    'N': const Color(0xFF5CACEE), // Soft blue
    'O': const Color(0xFF1874CD), // Medium blue
    'P': const Color(0xFF7B68EE), // Medium slate blue
    'Q': const Color(0xFF8470FF), // Light slate blue
    'R': const Color(0xFF6A5ACD), // Slate blue
    'S': const Color(0xFF483D8B), // Dark slate blue
    'T': const Color(0xFF00BFFF), // Deep sky blue
    'U': const Color(0xFF20B2AA), // Light sea blue
    'V': const Color(0xFF3A5FCD), // Medium blue
    'W': const Color(0xFF4A708B), // Dark blue-gray
    'X': const Color(0xFF607B8B), // Blue-gray
    'Y': const Color(0xFF7A67EE), // Soft slate blue
    'Z': const Color(0xFF1034A6), // Deep blue
  };

  @override
  void initState() {
    super.initState();
    fetchInvoiceDetails();
  }

  Future<void> fetchInvoiceDetails() async {
    final url =
        "${widget.serverUrl}/api/resource/Sales Invoice/${widget.invoiceId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          invoiceDetails = data['data'] ?? {};
          isLoading = false;
          errorMessage = '';
        });
      } else {
        throw Exception(
          'Failed to load sales invoice details: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Error: $error');
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching sales invoice details: $error';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching sales invoice details: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final items = invoiceDetails['items'] as List<dynamic>? ?? [];

    final totalQuantity = items.fold(
      0,
      (sum, item) => sum + (item['qty'] as num? ?? 0).toInt(),
    );
    final totalAmount = items.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num? ?? 0).toDouble(),
    );
    final vatAmount = totalAmount * 0.05;
    final grandTotal = totalAmount + vatAmount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'Kepler Tech LLC, Office No: 1 - Abdullah Al Awar Building - Dubai - United Arab Emirates\n+971 4 323 1008, info@keplertech.ae, www.keplertechllc.com',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  logoImage != null
                      ? pw.Image(logoImage, width: 70, height: 70)
                      : pw.Text(
                          'KEPLER',
                          style: const pw.TextStyle(fontSize: 16),
                        ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        invoiceDetails['name'] ?? '',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              // Customer Section
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Customer Name:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          invoiceDetails['customer_name'] ?? 'N/A',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          formatDate(invoiceDetails['posting_date']) ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Tax Id:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(invoiceDetails['tax_id'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Company TRN:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          invoiceDetails['company_tax_id'] ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Address:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          removeHtmlTags(invoiceDetails['address_display']) ??
                              'N/A',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Payment Terms:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          invoiceDetails['payment_terms_template'] ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              // Item Table with AED prefix
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _pdfTableHeader('Sr'),
                      _pdfTableHeader('Item'),
                      _pdfTableHeader('Quantity'),
                      _pdfTableHeader('Rate'),
                      _pdfTableHeader('Amount'),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _pdfTableCell(index.toString()),
                        _pdfTableCell(
                          item['item_code'] ?? item['item_name'] ?? '',
                        ),
                        _pdfTableCell(item['qty'].toString()),
                        _pdfTableCell('AED ${item['rate'] ?? 0}'),
                        _pdfTableCell('AED ${item['amount'] ?? 0}'),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 200),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Quantity: $totalQuantity',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total: AED $totalAmount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'VAT @ 5%: AED $vatAmount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Grand Total: AED $grandTotal',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              // In Words
              pw.Text(
                'In Words: AED ${numberToWords(grandTotal.toInt())} and ${((grandTotal - grandTotal.toInt()) * 100).toInt()} Fils only.',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _pdfTableHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  String removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    final RegExp exp = RegExp(
      r'<[^>]*>',
      multiLine: true,
      caseSensitive: false,
    );
    return htmlString.replaceAll(exp, '').trim();
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }

  String numberToWords(int number) {
    final units = [
      'Zero',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 20) return units[number];
    if (number < 100)
      return '${tens[number ~/ 10]} ${units[number % 10]}'.trim();
    if (number < 1000)
      return '${units[number ~/ 100]} Hundred ${numberToWords(number % 100)}'
          .trim();
    if (number < 1000000)
      return '${numberToWords(number ~/ 1000)} Thousand ${numberToWords(number % 1000)}'
          .trim();
    return 'Too large';
  }

  Future<void> _printSalesInvoice() async {
    if (invoiceDetails.isEmpty) return;
    final pdf = await generatePdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    if (invoiceDetails.isEmpty) return;
    final pdf = await generatePdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'sales_invoice_${invoiceDetails['name']}.pdf',
    );
  }

  // Generate avatar text from the first letter of each word (up to two letters)
  String _getAvatarText(String? customerName, String invoiceId) {
    if (customerName == null || customerName.isEmpty) {
      return invoiceId.isNotEmpty ? invoiceId[0].toUpperCase() : 'N';
    }
    final words = customerName.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
    }
    return customerName[0].toUpperCase();
  }

  // Get avatar color based on the first letter of the customer name or invoice ID
  Color _getAvatarColor(String? customerName, String invoiceId) {
    final name = customerName ?? (invoiceId.isNotEmpty ? invoiceId : 'N');
    return _letterColors[name[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = _getAvatarText(
      invoiceDetails['customer_name'],
      invoiceDetails['name'] ?? 'N',
    );
    final avatarColor = _getAvatarColor(
      invoiceDetails['customer_name'],
      invoiceDetails['name'] ?? 'N',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          invoiceDetails['name'] ?? 'Sales Invoice Details',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printSalesInvoice,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveAsPdf,
            tooltip: 'Save as PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.red,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchInvoiceDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : invoiceDetails.isEmpty
              ? Center(
                  child: Text(
                    'Sales invoice not found',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 18,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Invoice Info Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: avatarColor,
                                    radius: 30,
                                    child: Text(
                                      avatarText,
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
                                      'Invoice Info',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Invoice ID',
                                invoiceDetails['name'],
                              ),
                              _buildInfoRow(
                                'Customer',
                                invoiceDetails['customer'],
                              ),
                              _buildInfoRow(
                                'Customer Name',
                                invoiceDetails['customer_name'],
                              ),
                              _buildInfoRow('Status', invoiceDetails['status']),
                              _buildInfoRow(
                                'Posting Date',
                                formatDate(invoiceDetails['posting_date']),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Financial Info Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                              Text(
                                'Financial Info',
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Grand Total',
                                '${invoiceDetails['grand_total']} ${invoiceDetails['currency']}',
                              ),
                              _buildInfoRow(
                                'Net Total',
                                '${invoiceDetails['net_total']} ${invoiceDetails['currency']}',
                              ),
                              _buildInfoRow(
                                'Base Grand Total',
                                '${invoiceDetails['base_grand_total']} ${invoiceDetails['currency']}',
                              ),
                              _buildInfoRow(
                                'Base Net Total',
                                '${invoiceDetails['base_net_total']} ${invoiceDetails['currency']}',
                              ),
                              _buildInfoRow(
                                'Total Taxes and Charges',
                                '${invoiceDetails['total_taxes_and_charges']} ${invoiceDetails['currency']}',
                              ),
                              _buildInfoRow(
                                'Payment Terms',
                                invoiceDetails['payment_terms_template'],
                              ),
                            ],
                          ),
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
