import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'utils.dart';
import 'full_screen_image_viewer.dart';

class DeliveryNoteDetailScreen extends StatefulWidget {
  final String noteId;
  final String serverUrl;
  final String sid;
  const DeliveryNoteDetailScreen({
    Key? key,
    required this.noteId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _DeliveryNoteDetailScreenState createState() =>
      _DeliveryNoteDetailScreenState();
}

class _DeliveryNoteDetailScreenState extends State<DeliveryNoteDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> noteDetails = {};
  bool isLoading = true;
  late TabController _tabController;
  String? _selectedStatus;
  List<File?> _images = [];
  File? _airwayBillImage;
  String? _existingAirwayBillImageUrl;
  final ImagePicker _picker = ImagePicker();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool isSaving = false;
  TextEditingController _airwayBillNoController = TextEditingController();
  String? saveStatusMessage;
  Color? saveStatusColor;

  @override
  void initState() {
    super.initState();
    fetchDeliveryNoteDetails();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signatureController.dispose();
    _airwayBillNoController.dispose();
    super.dispose();
  }

  Future<void> fetchDeliveryNoteDetails() async {
    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_delivery_note_full?name=${widget.noteId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print('Fetch Response Status: ${response.statusCode}');
      print('Fetch Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            noteDetails = data['message']['delivery_note'] ?? {};
            _selectedStatus = noteDetails['custom_custom_delivery_status'];
            _airwayBillNoController.text =
                noteDetails['custom_air_way_bill_number'] ?? '';
            _existingAirwayBillImageUrl =
                noteDetails['custom_air_way_bill_image'];
            isLoading = false;
          });
        } else {
          throw Exception(
            data['message']['message'] ?? 'Failed to fetch details',
          );
        }
      } else {
        throw Exception(
          'Failed to load delivery note details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      print('Error fetching delivery note details: $error');
      setState(() => isLoading = false);
      setState(() {
        saveStatusMessage = 'Error fetching delivery note details: $error';
        saveStatusColor = Colors.red;
      });
    }
  }

  Future<void> _pickImage(
    ImageSource source, {
    bool isAirwayBill = false,
  }) async {
    if (noteDetails['custom_custom_delivery_status'] == 'Not Delivered') {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isAirwayBill) {
            _airwayBillImage = File(pickedFile.path);
            _existingAirwayBillImageUrl = null;
          } else {
            _images.add(File(pickedFile.path));
          }
        });
      }
    }
  }

  Future<void> _saveUpdates() async {
    if (noteDetails['custom_custom_delivery_status'] != 'Not Delivered') {
      setState(() {
        saveStatusMessage = 'Updates are only allowed for Not Delivered status';
        saveStatusColor = Colors.red;
      });
      return;
    }

    if (_selectedStatus == null) {
      setState(() {
        saveStatusMessage = 'Please select a status';
        saveStatusColor = Colors.red;
      });
      return;
    }

    setState(() {
      isSaving = true;
      saveStatusMessage = null;
      saveStatusColor = null;
    });

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.update_delivery_note";

    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close',
    };

    final signatureBytes = await _signatureController.toPngBytes();
    String? signatureBase64;
    if (signatureBytes != null && signatureBytes.isNotEmpty) {
      signatureBase64 = base64Encode(signatureBytes);
    } else {
      setState(() {
        saveStatusMessage = 'Please provide a signature';
        saveStatusColor = Colors.red;
        isSaving = false;
      });
      return;
    }

    List<String> imageBase64List = [];
    for (var image in _images) {
      if (image != null) {
        final bytes = await image.readAsBytes();
        imageBase64List.add(base64Encode(bytes));
      }
    }

    String? airwayBillImageBase64;
    if (_airwayBillImage != null) {
      airwayBillImageBase64 = base64Encode(
        await _airwayBillImage!.readAsBytes(),
      );
    }

    final updatedData = {
      'note_id': widget.noteId,
      'custom_custom_delivery_status': _selectedStatus,
      'signature_image': signatureBase64,
      'custom_air_way_bill_number': _airwayBillNoController.text,
    };

    if (imageBase64List.isNotEmpty) {
      updatedData['images'] = jsonEncode(imageBase64List);
    } else {
      updatedData['images'] = null;
    }

    if (airwayBillImageBase64 != null) {
      updatedData['custom_air_way_bill_image'] = airwayBillImageBase64;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(updatedData),
      );
      print('Update Response Status: ${response.statusCode}');
      print('Update Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Parsed Response Data: $responseData');
        if (responseData['message'] != null &&
            responseData['message']['status'] == 'success') {
          setState(() {
            saveStatusMessage = 'Updated Successfully';
            saveStatusColor = Colors.green;
            _images.clear();
            _airwayBillImage = null;
            _existingAirwayBillImageUrl = null;
            _signatureController.clear();
          });
          await fetchDeliveryNoteDetails();
        } else {
          setState(() {
            saveStatusMessage =
                'Failed: ${responseData['message']?['message'] ?? 'Unknown error'}';
            saveStatusColor = Colors.red;
          });
        }
      } else {
        throw Exception(
          'Failed to update delivery note: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      print('Error updating delivery note: $error');
      setState(() {
        saveStatusMessage = 'Failed: $error';
        saveStatusColor = Colors.red;
      });
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();
    final logoImage = await loadLogoImage();
    final customerSection = await generateCustomerSection(noteDetails);
    final totalQuantity = calculateTotalQuantity();
    final hasHsnSac = (noteDetails['items'] as List<dynamic>? ?? []).any(
      (item) => item['gst_hsn_code'] != null && item['gst_hsn_code'].isNotEmpty,
    );

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
                        noteDetails['name'] ?? '',
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
                  ...((noteDetails['items'] as List<dynamic>? ?? [])
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
                      .toList()),
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
    if (noteDetails.isEmpty || noteDetails['items'] == null) return 0;
    return (noteDetails['items'] as List<dynamic>).fold(
      0,
      (sum, item) => sum + (item['qty'] as num).toInt(),
    );
  }

  Future<void> _printDeliveryNote() async {
    if (noteDetails.isEmpty) return;
    final pdf = await generatePdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    if (noteDetails.isEmpty) return;
    final pdf = await generatePdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'delivery_note_${noteDetails['name']}.pdf',
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          noteDetails['name'] ?? 'Delivery Note Details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
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
          isScrollable: true,
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
            : noteDetails.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Delivery note not found',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    if (saveStatusMessage != null) ...[
                      SizedBox(height: 16),
                      Text(
                        saveStatusMessage!,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: saveStatusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
              _buildInfoRow('Note ID', noteDetails['name']),
              _buildInfoRow('Title', noteDetails['title']),
              _buildInfoRow('Customer Name', noteDetails['customer_name']),
              _buildInfoRow('Company', noteDetails['company']),
              _buildInfoRow(
                'Posting Date',
                formatDate(noteDetails['posting_date']),
              ),
              _buildInfoRow(
                'Posting Time',
                formatTime(noteDetails['posting_time']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    final isNotDelivered =
        noteDetails['custom_custom_delivery_status'] == 'Not Delivered';
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
              if (!isNotDelivered)
                Text(
                  _selectedStatus ?? 'N/A',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: ['Not Delivered', 'Delivered']
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: isNotDelivered
                      ? (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        }
                      : null,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
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
              if (!isNotDelivered)
                Text(
                  noteDetails['custom_air_way_bill_number'] ?? 'N/A',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                )
              else
                TextField(
                  controller: _airwayBillNoController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                ),
              SizedBox(height: 16),
              Text(
                'Upload Images',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: (noteDetails['images'] as List<dynamic>? ?? [])
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
              if (_images.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _images.map((image) {
                    if (image != null) {
                      return Image.file(
                        image,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      );
                    }
                    return SizedBox.shrink();
                  }).toList(),
                ),
              if (isNotDelivered)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: Icon(Icons.photo_library),
                        label: Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
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
              _existingAirwayBillImageUrl != null
                  ? GestureDetector(
                      onTap: () =>
                          _showFullScreenImage(_existingAirwayBillImageUrl!),
                      child: Image.network(
                        "${widget.serverUrl}$_existingAirwayBillImageUrl",
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
              if (_airwayBillImage != null)
                Image.file(
                  _airwayBillImage!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              if (isNotDelivered)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _pickImage(ImageSource.gallery, isAirwayBill: true),
                        icon: Icon(Icons.photo_library),
                        label: Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _pickImage(ImageSource.camera, isAirwayBill: true),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
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
              noteDetails['custom_signature'] != null
                  ? GestureDetector(
                      onTap: () =>
                          _showFullScreenImage(noteDetails['custom_signature']),
                      child: Image.network(
                        "${widget.serverUrl}${noteDetails['custom_signature']}",
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
              if (isNotDelivered)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Signature(
                        controller: _signatureController,
                        height: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _signatureController.clear(),
                      icon: Icon(Icons.clear),
                      label: Text('Clear Signature'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveUpdates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Save Updates',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                    if (saveStatusMessage != null) ...[
                      SizedBox(height: 16),
                      Text(
                        saveStatusMessage!,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: saveStatusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
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
              _buildInfoRow('Status', noteDetails['status']),
              _buildInfoRow(
                'Base Total Taxes',
                '${noteDetails['base_total_taxes_and_charges'] ?? 0} ${noteDetails['currency'] ?? ''}',
              ),
              _buildInfoRow(
                'Base Grand Total',
                '${noteDetails['base_grand_total'] ?? 0} ${noteDetails['currency'] ?? ''}',
              ),
              _buildInfoRow(
                'Rounding Adjustment',
                '${noteDetails['rounding_adjustment'] ?? 0} ${noteDetails['currency'] ?? ''}',
              ),
              _buildInfoRow(
                'Discount Amount',
                '${noteDetails['discount_amount'] ?? 0} ${noteDetails['currency'] ?? ''}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTeam() {
    final salesTeam = noteDetails['sales_team'] as List<dynamic>? ?? [];
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
                _buildInfoRow('Sales Person', member['sales_person']),
                _buildInfoRow(
                  'Allocated Percentage',
                  '${member['allocated_percentage'] ?? 0}%',
                ),
                _buildInfoRow(
                  'Allocated Amount',
                  '${member['allocated_amount'] ?? 0} ${noteDetails['currency'] ?? ''}',
                ),
                _buildInfoRow(
                  'Incentives',
                  '${member['incentives'] ?? 0} ${noteDetails['currency'] ?? ''}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() {
    final items = noteDetails['items'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.primary,
            ),
            headingTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            columns: const [
              DataColumn(label: Text('Item Code')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Warehouse')),
            ],
            rows: items
                .map(
                  (item) => DataRow(
                    cells: [
                      DataCell(Text(item['item_code'] ?? 'N/A')),
                      DataCell(Text(item['qty'].toString())),
                      DataCell(Text(item['warehouse'] ?? 'N/A')),
                    ],
                  ),
                )
                .toList(),
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
                removeHtmlTags(noteDetails['customer_address']),
              ),
              _buildInfoRow(
                'Address Display',
                removeHtmlTags(noteDetails['address_display']),
              ),
              _buildInfoRow(
                'Shipping Address Name',
                removeHtmlTags(noteDetails['shipping_address_name'] ?? 'N/A'),
              ),
              _buildInfoRow(
                'Mode of Transport',
                noteDetails['mode_of_transport'],
              ),
              _buildInfoRow('LR Date', formatDate(noteDetails['lr_date'])),
              _buildInfoRow('Distance', noteDetails['distance'].toString()),
              _buildInfoRow('Vehicle Type', noteDetails['gst_vehicle_type']),
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
