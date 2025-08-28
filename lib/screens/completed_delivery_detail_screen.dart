import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CompletedDeliveryDetailScreen extends StatefulWidget {
  final String noteId;
  final String serverUrl;
  final String sid;

  const CompletedDeliveryDetailScreen({
    Key? key,
    required this.noteId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CompletedDeliveryDetailScreenState createState() =>
      _CompletedDeliveryDetailScreenState();
}

class _CompletedDeliveryDetailScreenState
    extends State<CompletedDeliveryDetailScreen> {
  Map<String, dynamic>? deliveryNote;
  bool isLoading = true;
  int retryCount = 0;
  static const maxRetries = 3;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDeliveryNoteDetail();
  }

  Future<void> fetchDeliveryNoteDetail() async {
    if (retryCount >= maxRetries) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.salestracking.get_delivery_note_detail";
    final headers = {
      'Cookie': 'sid=${widget.sid}', // Ensure sid is correctly passed
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Add basic auth as fallback (optional, based on Postman)
      'Authorization':
          'Basic ${base64Encode(utf8.encode('administrator:123'))}',
    };

    print('Request URL: $url');
    print('Request Headers: $headers');
    print('Request Params: note_id=${widget.noteId}');

    try {
      final response = await http.get(
        Uri.parse('$url?note_id=${widget.noteId}'), // Match Postman params
        headers: headers,
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          deliveryNote = data['message']['data'];
          isLoading = false;

          if (deliveryNote?['custom_custom_delivery_status'] != 'Completed') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This screen is only for Completed notes'),
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
            ? 'Server error (417): The "saletracking" module is missing or misconfigured. Please contact your administrator or check the sid.'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Completed Note Details',
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
                  deliveryNote!['custom_custom_delivery_status'] != 'Completed'
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 40,
                              color: Colors.teal,
                            ),
                            SizedBox(width: 10),
                            Text(
                              deliveryNote!['name'] ?? 'No Name',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        _buildDetailRow(
                          'Customer',
                          deliveryNote!['customer_name'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Company',
                          deliveryNote!['company'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Title',
                          deliveryNote!['title'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Posting Date',
                          formatDate(deliveryNote!['posting_date']) ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Posting Time',
                          formatTime(deliveryNote!['posting_time']) ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Status',
                          deliveryNote!['status'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Base Total Taxes and Charges',
                          '${deliveryNote!['base_total_taxes_and_charges'] ?? 0.0}',
                        ),
                        _buildDetailRow(
                          'Base Grand Total',
                          '${deliveryNote!['base_grand_total'] ?? 0.0}',
                        ),
                        _buildDetailRow(
                          'Rounding Adjustment',
                          '${deliveryNote!['rounding_adjustment'] ?? 0.0}',
                        ),
                        _buildDetailRow(
                          'Discount Amount',
                          '${deliveryNote!['discount_amount'] ?? 0.0}',
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Shipping Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        _buildDetailRow(
                          'Mode of Transport',
                          deliveryNote!['mode_of_transport'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'LR Date',
                          formatDate(deliveryNote!['lr_date']) ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Distance',
                          '${deliveryNote!['distance'] ?? 0.0}',
                        ),
                        _buildDetailRow(
                          'Vehicle Type',
                          deliveryNote!['gst_vehicle_type'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Customer Address',
                          deliveryNote!['customer_address'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Address Display',
                          deliveryNote!['address_display'] ?? 'N/A',
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Delivery Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        _buildDetailRow(
                          'Delivery Status',
                          deliveryNote!['custom_custom_delivery_status'] ??
                              'N/A',
                        ),
                        _buildDetailRow(
                          'Airway Bill Number',
                          deliveryNote!['custom_air_way_bill_number'] ?? 'N/A',
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Images',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 10),
                        _buildAirwayBillImage(),
                        _buildSignatureImage(),
                        _buildAdditionalImages(),
                        SizedBox(height: 20),
                        Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        ..._buildItemsList(deliveryNote!['items'] ?? []),
                        SizedBox(height: 20),
                        Text(
                          'Sales Team',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        _buildSalesTeamRow(
                          deliveryNote!['sales_team']?.isNotEmpty == true
                              ? deliveryNote!['sales_team'][0]
                              : {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemsList(List<dynamic> items) {
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item['item_code'] ?? 'No Item',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            Text(
              'Qty: ${item['qty'] ?? 0}',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            Text(
              'Warehouse: ${item['warehouse'] ?? 'N/A'}',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSalesTeamRow(Map<String, dynamic> team) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Sales Person', team['sales_person'] ?? 'N/A'),
          _buildDetailRow(
            'Allocated %',
            '${team['allocated_percentage'] ?? 0.0}',
          ),
          _buildDetailRow(
            'Allocated Amount',
            '${team['allocated_amount'] ?? 0.0}',
          ),
          _buildDetailRow('Incentives', '${team['incentives'] ?? 'N/A'}'),
        ],
      ),
    );
  }

  Widget _buildAirwayBillImage() {
    final airwayBillImageUrl = deliveryNote!['custom_air_way_bill_image'];
    if (airwayBillImageUrl != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Image.network(
          "${widget.serverUrl}$airwayBillImageUrl",
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'Error loading Airway Bill image',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.red),
            );
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'No Airway Bill Image Available',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
      ),
    );
  }

  Widget _buildSignatureImage() {
    final signatureUrl = deliveryNote!['custom_signature'];
    if (signatureUrl != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Image.network(
          "${widget.serverUrl}$signatureUrl",
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'Error loading Signature',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.red),
            );
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'No Signature Available',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
      ),
    );
  }

  Widget _buildAdditionalImages() {
    final images = deliveryNote!['images'] as List<dynamic>? ?? [];
    if (images.isNotEmpty) {
      return Column(
        children: images.map((image) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.network(
              "${widget.serverUrl}${image['file_url']}",
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  'Error loading image',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.red),
                );
              },
            ),
          );
        }).toList(),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'No Additional Images Available',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
      ),
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr ?? 'N/A';
    }
  }

  String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'N/A';
    try {
      DateTime dateTime = DateFormat('HH:mm:ss.SSSSSS').parse(timeStr);
      return DateFormat('HH:mm:ss').format(dateTime);
    } catch (e) {
      return timeStr;
    }
  }
}
