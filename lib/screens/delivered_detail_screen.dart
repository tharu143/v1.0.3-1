import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'utils.dart';
import 'full_screen_image_viewer.dart';

class DeliveredDetailScreen extends StatefulWidget {
  final String noteId;
  final String serverUrl;
  final String sid;

  const DeliveredDetailScreen({
    Key? key,
    required this.noteId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _DeliveredDetailScreenState createState() => _DeliveredDetailScreenState();
}

class _DeliveredDetailScreenState extends State<DeliveredDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? deliveryNote;
  bool isLoading = true;
  int retryCount = 0;
  static const maxRetries = 3;
  String? errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    fetchDeliveryNoteDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchDeliveryNoteDetail() async {
    if (retryCount >= maxRetries) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Max retries reached. Please check the server or contact support.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_delivery_note_full?name=${widget.noteId}";
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
          deliveryNote = data['message']['delivery_note'];
          isLoading = false;

          if (deliveryNote?['custom_custom_delivery_status'] != 'Delivered') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This screen is only for Delivered notes'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pop(context);
          }
        });
      } else if (response.statusCode == 417 && retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: 2));
        setState(() {
          retryCount++;
          isLoading = false;
        });
        await fetchDeliveryNoteDetail();
      } else {
        throw Exception(
          'Failed to load delivery note: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching delivery note: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString().contains('417')
            ? 'Server error (417): Please check the sid or contact your administrator. Max retries: $retryCount/$maxRetries'
            : 'Error fetching delivery note: $e';
      });
    }
  }

  void onRetry() {
    setState(() {
      retryCount = 0;
      fetchDeliveryNoteDetail();
    });
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FullScreenImageViewer(imageUrl: "${widget.serverUrl}$imageUrl"),
      ),
    );
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();
    final logoImage = await loadLogoImage();
    final totalQuantity = calculateTotalQuantity();
    final hasHsnSac = (deliveryNote!['items'] as List<dynamic>? ?? []).any(
      (item) => item['gst_hsn_code'] != null && item['gst_hsn_code'].isNotEmpty,
    );
    final customerSection = await generateCustomerSection(deliveryNote!);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'Kepler Tech LLC, Office No: 1 - Abdullah Al Awar Building - Dubai - United Arab Emirates\n+971 4 323 1008, info@keplertech.ae, www.keplertechllc.com',
            style: pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  logoImage != null
                      ? pw.Image(logoImage, width: 70, height: 70)
                      : pw.Text('KEPLER', style: pw.TextStyle(fontSize: 16)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Delivery Note',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        deliveryNote!['name'] ?? '',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              customerSection,
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FixedColumnWidth(30),
                  1: pw.FlexColumnWidth(),
                  2: pw.FixedColumnWidth(60),
                  3: pw.FixedColumnWidth(60),
                  if (hasHsnSac) 4: pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _pdfTableHeader('Sr'),
                      _pdfTableHeader('Item Code'),
                      _pdfTableHeader('Quantity'),
                      _pdfTableHeader('Stock UOM'),
                      if (hasHsnSac) _pdfTableHeader('HSN/SAC'),
                    ],
                  ),
                  ...((deliveryNote!['items'] as List<dynamic>?) ?? [])
                      .asMap()
                      .entries
                      .map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        final cells = [
                          _pdfTableCell(index.toString()),
                          _pdfTableCell(item['item_code'] ?? ''),
                          _pdfTableCell(item['qty'].toString()),
                          _pdfTableCell(item['uom'] ?? 'Nos'),
                        ];
                        if (hasHsnSac) {
                          cells.add(_pdfTableCell(item['gst_hsn_code'] ?? ''));
                        }
                        return pw.TableRow(children: cells);
                      })
                      .toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Quantity: $totalQuantity',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
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
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10)),
    );
  }

  int calculateTotalQuantity() {
    if (deliveryNote == null || deliveryNote!['items'] == null) return 0;
    return (deliveryNote!['items'] as List<dynamic>).fold(
      0,
      (sum, item) => sum + (item['qty'] as num).toInt(),
    );
  }

  Future<void> _printDeliveryNote() async {
    if (deliveryNote == null) return;
    final pdf = await generatePdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    if (deliveryNote == null) return;
    final pdf = await generatePdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'delivery_note_${deliveryNote!['name']}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          deliveryNote?['name'] ?? 'Delivered Note Details',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: Colors.white),
            onPressed: _printDeliveryNote,
            tooltip: 'Print',
          ),
          IconButton(
            icon: Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveAsPdf,
            tooltip: 'Save as PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: Theme.of(context).textTheme.bodyMedium,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'General'),
            Tab(icon: Icon(Icons.update), text: 'Updates'),
            Tab(icon: Icon(Icons.payment), text: 'Payment'),
            Tab(icon: Icon(Icons.people), text: 'Team'),
            Tab(icon: Icon(Icons.list_alt), text: 'Items'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Shipping'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : deliveryNote == null ||
                  deliveryNote!['custom_custom_delivery_status'] != 'Delivered'
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage ?? 'No details available or invalid status',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (errorMessage != null && retryCount < maxRetries)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Retry'),
                        ),
                      ),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralInfo(),
                  _buildUpdatesTab(),
                  _buildPaymentInfo(),
                  _buildSalesTeam(),
                  _buildItemsList(),
                  _buildShippingInfo(),
                ],
              ),
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Note ID', deliveryNote!['name'] ?? 'N/A'),
              _buildInfoRow('Title', deliveryNote!['title'] ?? 'N/A'),
              _buildInfoRow(
                'Customer Name',
                deliveryNote!['customer_name'] ?? 'N/A',
              ),
              _buildInfoRow('Company', deliveryNote!['company'] ?? 'N/A'),
              _buildInfoRow(
                'Posting Date',
                formatDate(deliveryNote!['posting_date']) ?? 'N/A',
              ),
              _buildInfoRow(
                'Posting Time',
                formatTime(deliveryNote!['posting_time']) ?? 'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Status',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                deliveryNote!['custom_custom_delivery_status'] ?? 'N/A',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
              ),
              SizedBox(height: 16),
              Text(
                'Airway Bill No',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                deliveryNote!['custom_air_way_bill_number'] ?? 'N/A',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
              ),
              SizedBox(height: 16),
              Text(
                'Images',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: (deliveryNote!['images'] as List<dynamic>? ?? [])
                    .map(
                      (image) => GestureDetector(
                        onTap: () => _showFullScreenImage(image['file_url']),
                        child: Image.network(
                          "${widget.serverUrl}${image['file_url']}",
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            'Error loading image',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(color: Colors.red),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 16),
              Text(
                'Airway Bill Image',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              deliveryNote!['custom_air_way_bill_image'] != null
                  ? GestureDetector(
                      onTap: () => _showFullScreenImage(
                        deliveryNote!['custom_air_way_bill_image'],
                      ),
                      child: Image.network(
                        "${widget.serverUrl}${deliveryNote!['custom_air_way_bill_image']}",
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'Error loading image',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Colors.red),
                        ),
                      ),
                    )
                  : Text(
                      'No airway bill image',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                    ),
              SizedBox(height: 16),
              Text(
                'Digital Signature',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              deliveryNote!['custom_signature'] != null
                  ? GestureDetector(
                      onTap: () => _showFullScreenImage(
                        deliveryNote!['custom_signature'],
                      ),
                      child: Image.network(
                        "${widget.serverUrl}${deliveryNote!['custom_signature']}",
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'Error loading signature',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Colors.red),
                        ),
                      ),
                    )
                  : Text(
                      'No signature available',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Status', deliveryNote!['status'] ?? 'N/A'),
              _buildInfoRow(
                'Base Total Taxes',
                '${deliveryNote!['base_total_taxes_and_charges'] ?? 0.0} ${deliveryNote!['currency'] ?? ''}',
              ),
              _buildInfoRow(
                'Base Grand Total',
                '${deliveryNote!['base_grand_total'] ?? 0.0} ${deliveryNote!['currency'] ?? ''}',
              ),
              _buildInfoRow(
                'Rounding Adjustment',
                '${deliveryNote!['rounding_adjustment'] ?? 0.0} ${deliveryNote!['currency'] ?? ''}',
              ),
              _buildInfoRow(
                'Discount Amount',
                '${deliveryNote!['discount_amount'] ?? 0.0} ${deliveryNote!['currency'] ?? ''}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTeam() {
    final salesTeam = deliveryNote!['sales_team'] as List<dynamic>? ?? [];
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: salesTeam.length,
      itemBuilder: (context, index) {
        final member = salesTeam[index];
        return Card(
          color: Colors.white,
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Sales Person', member['sales_person'] ?? 'N/A'),
                _buildInfoRow(
                  'Allocated Percentage',
                  '${member['allocated_percentage'] ?? 0.0}%',
                ),
                _buildInfoRow(
                  'Allocated Amount',
                  '${member['allocated_amount'] ?? 0.0} ${deliveryNote!['currency'] ?? ''}',
                ),
                _buildInfoRow(
                  'Incentives',
                  '${member['incentives'] ?? 0.0} ${deliveryNote!['currency'] ?? ''}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() {
    final items = deliveryNote!['items'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(16),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 2,
        child: Card(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Table(
              border: TableBorder.all(color: Colors.grey),
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1.0),
                2: FlexColumnWidth(2.0),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Item Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Qty',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Warehouse',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                ...items.map(
                  (item) => TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(item['item_code'] ?? 'N/A'),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(item['qty'].toString() ?? 'N/A'),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(item['warehouse'] ?? 'N/A'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShippingInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                'Customer Address',
                removeHtmlTags(deliveryNote!['customer_address'] ?? 'N/A'),
              ),
              _buildInfoRow(
                'Address Display',
                removeHtmlTags(deliveryNote!['address_display'] ?? 'N/A'),
              ),
              _buildInfoRow(
                'Mode of Transport',
                deliveryNote!['mode_of_transport'] ?? 'N/A',
              ),
              _buildInfoRow(
                'LR Date',
                formatDate(deliveryNote!['lr_date'] ?? 'N/A'),
              ),
              _buildInfoRow(
                'Distance',
                deliveryNote!['distance'].toString() ?? 'N/A',
              ),
              _buildInfoRow(
                'Vehicle Type',
                deliveryNote!['gst_vehicle_type'] ?? 'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
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
}
