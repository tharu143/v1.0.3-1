import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/payment_entry.dart';
import '../services/api_service.dart';

class PaymentEntryCreateScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const PaymentEntryCreateScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });

  @override
  _PaymentEntryCreateScreenState createState() =>
      _PaymentEntryCreateScreenState();
}

class _PaymentEntryCreateScreenState extends State<PaymentEntryCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late PaymentEntry _paymentEntry;
  final _partyTypes = ['Customer', 'Supplier', 'Employee', 'Shareholder'];
  final _paymentTypes = ['Receive', 'Pay', 'Internal Transfer'];
  final _modesOfPayment = ['Cash', 'Bank Transfer', 'Cheque'];
  List<String> _namingSeriesOptions = [];
  List<String> _partyList = [];
  List<String> _costCenters = [];
  bool _isLoadingParties = false;
  bool _isLoadingInitialData = true;
  bool _isLoadingCostCenters = false;
  final TextEditingController _transactionIdController =
      TextEditingController();
  final TextEditingController _referenceDateController =
      TextEditingController();
  static const String _cashAccount = 'Cash - KT';
  static const String _bankAccount =
      '870817074101 - EMIRATES ISLAMIC BANK - KT';
  static const String _debtorsAccount = 'Debtors - KT';
  static const String _defaultCurrency = 'AED';

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
    _paymentEntry = PaymentEntry(
      paymentType: 'Receive',
      postingDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      company: 'KEPLER TECH LLC',
      pdcCleared: false,
    );
    _fetchInitialData();
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _referenceDateController.dispose();
    super.dispose();
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

  Future<void> _fetchInitialData() async {
    setState(() => _isLoadingInitialData = true);

    try {
      // Fetch naming series
      final namingSeriesResponse = await ApiService.fetchNamingSeries(
        widget.serverUrl,
        widget.sid,
      );
      if (mounted) {
        setState(() {
          _namingSeriesOptions = namingSeriesResponse.toSet().toList();
          if (_namingSeriesOptions.isNotEmpty) {
            _paymentEntry.namingSeries = _namingSeriesOptions[0];
          }
        });
      }

      // Set default mode of payment
      if (mounted) {
        setState(() {
          _paymentEntry.modeOfPayment = _modesOfPayment[0];
        });
      }

      // Fetch cost centers
      await _fetchCostCenters();

      // Update accounts based on payment type and mode of payment
      _updateAccounts();

      // Fetch parties if party type is selected
      if (_paymentEntry.partyType != null) {
        await _fetchParties(_paymentEntry.partyType!);
      }

      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
    } catch (e) {
      print('Error fetching initial data: $e');
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
        showApiErrorDialog(context, message: e.toString());
      }
    }
  }

  Future<void> _fetchCostCenters() async {
    setState(() {
      _isLoadingCostCenters = true;
      _costCenters = [];
      _paymentEntry.costCenter = null;
    });

    try {
      final response = await ApiService.fetchCostCenters(
        widget.serverUrl,
        widget.sid,
      );
      final List<dynamic> costCenterData = response['message'];
      final List<String> costCenterNames = costCenterData
          .map((item) => item['name'].toString())
          .toList();

      if (mounted) {
        setState(() {
          _costCenters = costCenterNames;
          if (_costCenters.isNotEmpty) {
            _paymentEntry.costCenter = _costCenters[0];
          }
          _isLoadingCostCenters = false;
        });
      }

      if (_costCenters.isEmpty && mounted) {
        showApiErrorDialog(context, message: 'No Cost Centers found');
      }
    } catch (e) {
      print('Error fetching Cost Centers: $e');
      if (mounted) {
        setState(() => _isLoadingCostCenters = false);
        showApiErrorDialog(context, message: 'Error fetching Cost Centers: $e');
      }
    }
  }

  void _updateAccounts() {
    String paidToAccount;
    String paidFromAccount;
    String paidToCurrency = _defaultCurrency;
    String paidFromCurrency = _defaultCurrency;

    if (_paymentEntry.paymentType == 'Receive') {
      paidFromAccount = _debtorsAccount;
      paidToAccount = _paymentEntry.modeOfPayment == 'Cash'
          ? _cashAccount
          : _bankAccount;
    } else if (_paymentEntry.paymentType == 'Pay') {
      paidToAccount = _debtorsAccount;
      paidFromAccount = _paymentEntry.modeOfPayment == 'Cash'
          ? _cashAccount
          : _bankAccount;
    } else {
      paidToAccount = _cashAccount;
      paidFromAccount = _bankAccount;
    }

    setState(() {
      _paymentEntry.paidTo = paidToAccount;
      _paymentEntry.paidFrom = paidFromAccount;
      _paymentEntry.paidToAccountCurrency = paidToCurrency;
      _paymentEntry.paidFromAccountCurrency = paidFromCurrency;
    });
  }

  Future<void> _fetchParties(String partyType) async {
    setState(() {
      _isLoadingParties = true;
      _partyList = [];
      _paymentEntry.party = null;
    });

    try {
      List<String> parties;
      switch (partyType) {
        case 'Customer':
          parties = await ApiService.fetchCustomers(
            widget.serverUrl,
            widget.sid,
          );
          break;
        case 'Supplier':
          parties = await ApiService.fetchSuppliers(
            widget.serverUrl,
            widget.sid,
          );
          break;
        case 'Employee':
          parties = await ApiService.fetchEmployees(
            widget.serverUrl,
            widget.sid,
          );
          break;
        case 'Shareholder':
          parties = await ApiService.fetchShareholders(
            widget.serverUrl,
            widget.sid,
          );
          break;
        default:
          parties = [];
      }

      if (mounted) {
        setState(() {
          _partyList = parties;
          _isLoadingParties = false;
          if (_partyList.isNotEmpty) {
            _paymentEntry.party = _partyList[0];
          }
        });
      }

      if (_partyList.isEmpty && mounted) {
        showApiErrorDialog(context, message: 'No $partyType found');
      }
    } catch (e) {
      print('Error fetching $partyType: $e');
      if (mounted) {
        setState(() => _isLoadingParties = false);
        showApiErrorDialog(context, message: 'Error fetching $partyType: $e');
      }
    }
  }

  Future<void> _createPaymentEntry() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final paymentEntryData = {
        'naming_series': _paymentEntry.namingSeries,
        'payment_type': _paymentEntry.paymentType,
        'posting_date': _paymentEntry.postingDate,
        'company': _paymentEntry.company,
        'mode_of_payment': _paymentEntry.modeOfPayment,
        'party_type': _paymentEntry.partyType,
        'party': _paymentEntry.party,
        'paid_from': _paymentEntry.paidFrom,
        'paid_to': _paymentEntry.paidTo,
        'paid_from_account_currency': _paymentEntry.paidFromAccountCurrency,
        'paid_to_account_currency': _paymentEntry.paidToAccountCurrency,
        'paid_amount': _paymentEntry.paidAmount,
        'received_amount': _paymentEntry.paidAmount,
        'pdc_cleared': _paymentEntry.pdcCleared,
        'cost_center': _paymentEntry.costCenter,
        if (_paymentEntry.modeOfPayment != 'Cash')
          'reference_no': _paymentEntry.referenceNo,
        if (_paymentEntry.modeOfPayment != 'Cash')
          'reference_date': _paymentEntry.referenceDate,
      };

      print('Creating payment entry: Data=$paymentEntryData');

      await ApiService.createPaymentEntry(
        widget.serverUrl,
        widget.sid,
        paymentEntryData,
      );

      if (mounted) {
        showErrorDialog(
          context,
          'Success',
          'Payment Entry Created Successfully\nAmount: ${_paymentEntry.paidAmount?.toStringAsFixed(2)} AED',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error creating Payment Entry: $e');
      if (mounted) {
        showApiErrorDialog(
          context,
          message: 'Error creating Payment Entry: $e',
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && mounted) {
      setState(() {
        _paymentEntry.postingDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectReferenceDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && mounted) {
      setState(() {
        _paymentEntry.referenceDate = DateFormat('yyyy-MM-dd').format(picked);
        _referenceDateController.text = _paymentEntry.referenceDate!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarLetter = widget.sid.isNotEmpty
        ? widget.sid[0].toUpperCase()
        : 'P';
    final avatarColor =
        _letterColors[avatarLetter] ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Create Payment Entry',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
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
            // Container(
            //   margin: const EdgeInsets.only(
            //     top: 24,
            //     left: 16,
            //     right: 16,
            //     bottom: 16,
            //   ),
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(12),
            //     color: Theme.of(context).colorScheme.surface,
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withOpacity(0.1),
            //         blurRadius: 10,
            //         offset: const Offset(0, 4),
            //       ),
            //     ],
            //   ),
            //   child: Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Row(
            //       children: [
            //         CircleAvatar(
            //           backgroundColor: avatarColor,
            //           radius: 30,
            //           child: Text(
            //             avatarLetter,
            //             style: const TextStyle(
            //               color: Colors.white,
            //               fontWeight: FontWeight.bold,
            //               fontSize: 20,
            //             ),
            //           ),
            //         ),
            //         const SizedBox(width: 12),
            //         Expanded(
            //           child: Text(
            //             'Create Payment Entry',
            //             style: Theme.of(context).textTheme.titleLarge!.copyWith(
            //               color: Theme.of(context).colorScheme.primary,
            //               fontWeight: FontWeight.bold,
            //               fontSize: 20,
            //             ),
            //             maxLines: null,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchableDropdownField(
                        label: 'Series',
                        value: _paymentEntry.namingSeries,
                        items: _namingSeriesOptions,
                        onChanged: (value) =>
                            setState(() => _paymentEntry.namingSeries = value),
                        validator: (value) =>
                            value == null ? 'Please select a series' : null,
                        icon: Icons.list,
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        label: 'Posting Date',
                        controller: TextEditingController(
                          text: _paymentEntry.postingDate ?? '',
                        ),
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        validator: (value) =>
                            value!.isEmpty ? 'Please select a date' : null,
                      ),
                      const SizedBox(height: 8),
                      _buildSearchableDropdownField(
                        label: 'Payment Type',
                        value: _paymentEntry.paymentType,
                        items: _paymentTypes,
                        onChanged: (value) {
                          setState(() {
                            _paymentEntry.paymentType = value;
                            if (value == 'Internal Transfer') {
                              _paymentEntry.partyType = null;
                              _paymentEntry.party = null;
                              _partyList = [];
                            }
                            _updateAccounts();
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select a payment type'
                            : null,
                        icon: Icons.payment,
                      ),
                      const SizedBox(height: 8),
                      _buildSearchableDropdownField(
                        label: 'Mode of Payment',
                        value: _paymentEntry.modeOfPayment,
                        items: _modesOfPayment,
                        onChanged: (value) {
                          setState(() {
                            _paymentEntry.modeOfPayment = value;
                            if (value == 'Cash') {
                              _paymentEntry.referenceNo = null;
                              _paymentEntry.referenceDate = null;
                              _transactionIdController.clear();
                              _referenceDateController.clear();
                            }
                            _updateAccounts();
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select a mode of payment'
                            : null,
                        icon: Icons.money,
                      ),
                      const SizedBox(height: 8),
                      if (_paymentEntry.modeOfPayment != 'Cash') ...[
                        _buildTextField(
                          label: 'Cheque/Reference No',
                          controller: _transactionIdController,
                          icon: Icons.receipt,
                          onChanged: (value) =>
                              _paymentEntry.referenceNo = value,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter Cheque/Reference No'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          label: 'Cheque/Reference Date',
                          controller: _referenceDateController,
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: () => _selectReferenceDate(context),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please select Cheque/Reference Date'
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_paymentEntry.paymentType == 'Receive')
                        Row(
                          children: [
                            Checkbox(
                              value: _paymentEntry.pdcCleared,
                              onChanged: (value) => setState(
                                () => _paymentEntry.pdcCleared = value,
                              ),
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            Text(
                              'PDC Cleared',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontSize: 16,
                                  ),
                            ),
                          ],
                        ),
                      if (_paymentEntry.paymentType != 'Internal Transfer') ...[
                        const SizedBox(height: 8),
                        _buildSearchableDropdownField(
                          label: 'Party Type',
                          value: _paymentEntry.partyType,
                          items: _partyTypes,
                          onChanged: (value) {
                            setState(() {
                              _paymentEntry.partyType = value;
                              if (value != null) _fetchParties(value);
                            });
                          },
                          validator: (value) => value == null
                              ? 'Please select a party type'
                              : null,
                          icon: Icons.group,
                        ),
                        const SizedBox(height: 8),
                        _buildSearchableDropdownField(
                          label: 'Party',
                          value: _paymentEntry.party,
                          items: _partyList,
                          onChanged: (value) =>
                              setState(() => _paymentEntry.party = value),
                          validator: (value) =>
                              value == null ? 'Please select a party' : null,
                          suffixIcon: _isLoadingParties
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          icon: Icons.person,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildTextField(
                        label: 'Paid Amount (AED)',
                        controller: TextEditingController(
                          text: _paymentEntry.paidAmount?.toString() ?? '',
                        ),
                        icon: Icons.monetization_on,
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            _paymentEntry.paidAmount = double.tryParse(value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter the amount'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _buildSearchableDropdownField(
                        label: 'Cost Center',
                        value: _paymentEntry.costCenter,
                        items: _costCenters,
                        onChanged: (value) =>
                            setState(() => _paymentEntry.costCenter = value),
                        validator: (value) => value == null
                            ? 'Please select a cost center'
                            : null,
                        suffixIcon: _isLoadingCostCenters
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        icon: Icons.account_balance,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoadingInitialData
                            ? null
                            : _createPaymentEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoadingInitialData
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save Payment Entry',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              hintText: 'Enter $label',
              hintStyle: const TextStyle(color: Colors.grey),
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
            validator: validator,
            maxLines: null,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownSearch<String>(
            items: (String filter, LoadProps? loadProps) async {
              return items
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList();
            },
            selectedItem: value,
            onChanged: onChanged,
            validator: validator,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search $label',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              menuProps: const MenuProps(backgroundColor: Colors.white),
            ),
            dropdownBuilder: (context, selectedItem) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedItem ?? 'Select $label',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                        maxLines: null,
                      ),
                    ),
                    if (suffixIcon != null) suffixIcon,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
