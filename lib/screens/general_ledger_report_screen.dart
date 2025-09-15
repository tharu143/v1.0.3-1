import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/error_handler.dart';

class GeneralLedgerReportScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const GeneralLedgerReportScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _GeneralLedgerReportScreenState createState() =>
      _GeneralLedgerReportScreenState();
}

class _GeneralLedgerReportScreenState extends State<GeneralLedgerReportScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Map<String, String>> _customers = [];
  List<Map<String, String>> _filteredCustomers = [];
  Map<String, String>? _selectedCustomer;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _isLoadingCustomers = true;
  bool _isGeneratingReport = false;

  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoadingCustomers = true);

    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_customers1';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['status'] == 'success') {
          final List<dynamic> customerList = data['message']['customers'];
          setState(() {
            _customers = customerList.map((customer) {
              return {
                'name': customer['name'].toString(),
                'customer_name': customer['customer_name'].toString(),
              };
            }).toList();
            _filteredCustomers = _customers;
          });
        } else {
          if (mounted) {
            showApiErrorDialog(context,
                message: 'Failed to load customer data.');
          }
        }
      } else {
        if (mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
      }
    } finally {
      setState(() => _isLoadingCustomers = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  void _showCustomerSearch() {
    setState(() {
      _filteredCustomers = _customers;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, controller) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) {
                        modalState(() {
                          _filteredCustomers = _customers
                              .where((customer) =>
                                  customer['customer_name']!
                                      .toLowerCase()
                                      .contains(value.toLowerCase()) ||
                                  customer['name']!
                                      .toLowerCase()
                                      .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Search Customer',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return ListTile(
                          title: Text(customer['customer_name']!),
                          subtitle: Text(customer['name']!),
                          onTap: () {
                            setState(() {
                              _selectedCustomer = customer;
                              _customerController.text =
                                  customer['customer_name']!;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isGeneratingReport = true);

    final fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate!);
    final toDateStr = DateFormat('yyyy-MM-dd').format(_toDate!);

    final url =
        '${widget.serverUrl}/api/method/custom_printersbay.api.general_ledger_report.generate_general_ledger_pdf?from_date=$fromDateStr&to_date=$toDateStr&customer=${_selectedCustomer!['name']}';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final pdfUrl = '${widget.serverUrl}${data["message"]["file_url"]}';
        final fileName = data["message"]["file_name"];
        Navigator.pushNamed(context, '/pdfViewer', arguments: {
          'pdfUrl': pdfUrl,
          'fileName': fileName,
        });
      } else {
        if (mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'General Ledger Report',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: _buildFormControls(),
        ),
      ),
    );
  }

  Widget _buildFormControls() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _isLoadingCustomers
                ? const Center(child: CircularProgressIndicator())
                : TextFormField(
                    controller: _customerController,
                    readOnly: true,
                    onTap: _isLoadingCustomers ? null : _showCustomerSearch,
                    decoration: const InputDecoration(
                      labelText: 'Select Customer',
                      prefixIcon: Icon(Icons.person_search),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Please select a customer' : null,
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fromDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'From Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () => _selectDate(context, true),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Select a date' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _toDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'To Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () => _selectDate(context, false),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Select a date' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isGeneratingReport ? null : _generateReport,
              icon: _isGeneratingReport
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isGeneratingReport ? 'Generating...' : 'Generate Report'),
            ),
          ],
        ),
      ),
    );
  }
}

