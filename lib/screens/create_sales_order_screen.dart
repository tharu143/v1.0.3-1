import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  const CreateSalesOrderScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CreateSalesOrderScreenState createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _series;
  final TextEditingController _transactionDateController =
      TextEditingController();
  String? _customer;
  String? _orderType = 'Sales';
  String? _costCenter;
  String? _salesPerson;
  final TextEditingController _poNoController = TextEditingController();
  final TextEditingController _poDateController = TextEditingController();
  final List<Map<String, dynamic>> _items = [
    {
      'itemCode': null,
      'itemName': null,
      'deliveryDate': TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
      'qty': TextEditingController(),
      'uom': null,
      'rate': 0.0,
      'rateController': TextEditingController(),
      'priceHistoryRates': <double>[],
      'amount': 0.0,
      'isExpanded': false, // Added for edit toggle
    },
  ];
  List<String> seriesList = [];
  List<String> customerList = [];
  List<Map<String, dynamic>> itemList = [];
  List<String> costCenterList = [];
  List<String> salesPersonList = [];
  bool isLoading = false;

  // Define unique colors for each of the 26 English letters (blue-centric)
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
    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    fetchNamingSeries();
    fetchCustomers();
    fetchItems();
    fetchCostCenters();
    fetchSalesPersons();
  }

  @override
  void dispose() {
    _transactionDateController.dispose();
    _poNoController.dispose();
    _poDateController.dispose();
    for (var item in _items) {
      item['deliveryDate'].dispose();
      item['qty'].dispose();
      item['rateController'].dispose();
    }
    super.dispose();
  }

  // Error handling utilities
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

  String _stripHtmlIfNeeded(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  String getUserFriendlyMessage(int statusCode, String message) {
    final cleanMessage = _stripHtmlIfNeeded(_parseFrappeException(message));
    if (cleanMessage.contains('Incorrect date value')) {
      return "Invalid date format: Please ensure dates are valid and in the correct format (e.g., YYYY-MM-DD). $cleanMessage";
    }
    if (cleanMessage.contains('LinkValidationError')) {
      return "Invalid reference: One or more linked fields (e.g., Customer, Cost Center) do not exist in ERPNext. $cleanMessage";
    }
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

  // API Methods
  Future<void> fetchNamingSeries() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_sales_order_naming_series';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] == null ||
            data['message']['naming_series_options'] == null) {
          throw http.Response(
            'Invalid response: No naming series options found',
            response.statusCode,
          );
        }
        setState(() {
          seriesList = List<String>.from(
            data['message']['naming_series_options'] ?? [],
          );
          seriesList.removeWhere((item) => item.isEmpty);
          if (seriesList.isEmpty) {
            throw Exception('No valid naming series available');
          }
          seriesList.sort((a, b) => a == seriesList.first ? -1 : 1);
          _series = seriesList.isNotEmpty ? seriesList[0] : null;
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching naming series: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    }
  }

  Future<void> fetchCustomers() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_customers';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw http.Response(
            'API returned unsuccessful status',
            response.statusCode,
          );
        }
        setState(() {
          customerList = List<String>.from(
            (data['message']['customers'] ?? []).map((item) => item['name']),
          );
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching customers: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    }
  }

  Future<void> fetchItems() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_items_with_price_history';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Expect': '',
    };
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw http.Response(
            'API returned unsuccessful status',
            response.statusCode,
          );
        }
        setState(() {
          itemList = List<Map<String, dynamic>>.from(
            data['message']['items'] ?? [],
          );
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching items: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    }
  }

  Future<void> fetchCostCenters() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_cost_centers';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Expect': '',
    };
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] is! List) {
          throw http.Response(
            'API returned unexpected format',
            response.statusCode,
          );
        }
        setState(() {
          costCenterList = List<String>.from(
            (data['message'] ?? []).map((item) => item['name']),
          );
          _costCenter = costCenterList.isNotEmpty ? costCenterList[0] : null;
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching cost centers: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    }
  }

  Future<void> fetchSalesPersons() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_sales_person';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] != 'success') {
          throw http.Response(
            'API returned unsuccessful status',
            response.statusCode,
          );
        }
        setState(() {
          salesPersonList = List<String>.from(
            (data['message']['data'] ?? []).map((item) => item['name']),
          );
          if (salesPersonList.isNotEmpty) {
            _salesPerson = salesPersonList[0];
          }
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching sales persons: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    }
  }

  Future<void> _createSalesOrder() async {
    if (!_formKey.currentState!.validate()) {
      showErrorDialog(
        context,
        'Form Error',
        'Please fix the errors in the form.',
      );
      return;
    }
    setState(() => isLoading = true);
    final url = "${widget.serverUrl}/api/resource/Sales Order";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final items = _items.map((item) {
      return {
        "item_code": item['itemCode'],
        "item_name": item['itemName'],
        "delivery_date": item['deliveryDate'].text,
        "qty": double.tryParse(item['qty'].text) ?? 0.0,
        "uom": item['uom'],
        "rate": item['rate'],
        "amount": item['amount'],
      };
    }).toList();
    final salesTeam = _salesPerson != null
        ? [
            {"sales_person": _salesPerson, "allocated_percentage": 100.00},
          ]
        : [];
    final body = jsonEncode({
      "naming_series": _series,
      "transaction_date": _transactionDateController.text,
      "customer": _customer,
      "order_type": _orderType,
      "po_no": _poNoController.text.isNotEmpty ? _poNoController.text : null,
      "po_date": _poDateController.text.isNotEmpty
          ? _poDateController.text
          : null,
      "items": items,
      "company": "KEPLER TECH LLC",
      "currency": "AED",
      "selling_price_list": "CLARITY CRYSTAL PHOTO STUDIO - BRANCH",
      "cost_center": _costCenter,
      "status": "Draft",
      "sales_team": salesTeam,
    });
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showErrorDialog(
          context,
          'Success',
          'Sales Order created successfully!',
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Sales Order creation error: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onBackground,
            ),
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addItemRow() {
    setState(() {
      _items.add({
        'itemCode': null,
        'itemName': null,
        'deliveryDate': TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        'qty': TextEditingController(),
        'uom': null,
        'rate': 0.0,
        'rateController': TextEditingController(),
        'priceHistoryRates': <double>[],
        'amount': 0.0,
        'isExpanded': false,
      });
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      if (_items.length > 1) {
        _items[index]['deliveryDate'].dispose();
        _items[index]['qty'].dispose();
        _items[index]['rateController'].dispose();
        _items.removeAt(index);
      }
    });
  }

  double getTotalQuantity() {
    return _items.fold(
      0.0,
      (sum, item) => sum + (double.tryParse(item['qty'].text) ?? 0.0),
    );
  }

  double getTotalAmount() {
    return _items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  String _getAvatarText(String? customer) {
    if (customer != null && customer.isNotEmpty) {
      final words = customer.trim().split(RegExp(r'\s+'));
      if (words.length >= 2) {
        return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
      }
      return customer[0].toUpperCase();
    }
    return 'N';
  }

  Color _getAvatarColor(String? customer) {
    if (customer == null || customer.isEmpty)
      return _letterColors['N'] ?? Theme.of(context).colorScheme.primary;
    return _letterColors[customer[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = _getAvatarText(_customer);
    final avatarColor = _getAvatarColor(_customer);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Create Sales Order',
          style: TextStyle(
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
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
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
                    child: Row(
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
                            'Sales Order Info',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Naming Series Section
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
                          'Naming Series',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          value: _series,
                          items: seriesList,
                          onChanged: (value) => setState(() => _series = value),
                          validator: (value) => value == null
                              ? 'Please select a naming series'
                              : null,
                          icon: Icons.format_list_numbered,
                        ),
                      ],
                    ),
                  ),
                ),
                // Transaction Date Section
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
                          'Transaction Date',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _transactionDateController,
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: () =>
                              _selectDate(context, _transactionDateController),
                          validator: (value) =>
                              value!.isEmpty ? 'Please select a date' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                // Customer Section
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
                          'Customer',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildSearchableDropdownField(
                          value: _customer,
                          items: customerList,
                          onChanged: (value) => setState(() {
                            _customer = value;
                          }),
                          validator: (value) =>
                              value == null ? 'Please select a customer' : null,
                          icon: Icons.person,
                        ),
                      ],
                    ),
                  ),
                ),
                // Order Type Section
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
                          'Order Type',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          value: _orderType,
                          items: ['Sales', 'Maintenance', 'Shopping Cart'],
                          onChanged: (value) =>
                              setState(() => _orderType = value),
                          validator: (value) => value == null
                              ? 'Please select an order type'
                              : null,
                          icon: Icons.category,
                        ),
                      ],
                    ),
                  ),
                ),
                // Purchase Order Details Section
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
                          'Purchase Order Details',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _poNoController,
                          icon: Icons.receipt,
                          onChanged: (value) => setState(() {}),
                        ),
                        if (_poNoController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _poDateController,
                            icon: Icons.calendar_today,
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _poDateController),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Cost Center Section
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
                          'Cost Center',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildSearchableDropdownField(
                          value: _costCenter,
                          items: costCenterList,
                          onChanged: (value) =>
                              setState(() => _costCenter = value),
                          validator: (value) => value == null
                              ? 'Please select a cost center'
                              : null,
                          icon: Icons.account_balance,
                        ),
                      ],
                    ),
                  ),
                ),
                // Sales Person Section
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
                          'Sales Person',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildSearchableDropdownField(
                          value: _salesPerson,
                          items: salesPersonList,
                          onChanged: (value) =>
                              setState(() => _salesPerson = value),
                          icon: Icons.person_outline,
                        ),
                      ],
                    ),
                  ),
                ),
                // Items Section
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
                          'Items',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildItemsList(context),
                      ],
                    ),
                  ),
                ),
                // Totals Section
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
                          'Totals',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Quantity',
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  getTotalQuantity().toStringAsFixed(3),
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total (AED)',
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'AED ${getTotalAmount().toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Submit Button
                ElevatedButton(
                  onPressed: isLoading ? null : _createSalesOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isLoading ? 2 : 4,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Sales Order',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addItemRow,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
        elevation: 6,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller == _poNoController
              ? "Customer's Purchase Order (PO No)"
              : "Customer's Purchase Order Date",
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
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
                blurRadius: 8,
                offset: const Offset(0, 4),
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 12,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == _series ? 'Naming Series' : 'Order Type',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
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
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.isEmpty
                ? [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Loading...'),
                    ),
                  ]
                : items
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
            onChanged: items.isEmpty ? null : onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            validator: validator,
            style: Theme.of(context).textTheme.bodyMedium,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField({
    required String? value,
    required List<String> items,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == _customer
              ? 'Customer'
              : value == _costCenter
              ? 'Cost Center'
              : 'Sales Person',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
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
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownSearch<String>(
            items: (String filter, LoadProps? loadProps) => Future.value(
              items
                  .where(
                    (item) => item.toLowerCase().contains(filter.toLowerCase()),
                  )
                  .toList(),
            ),
            selectedItem: value,
            onChanged: onChanged,
            validator: validator,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  labelText: 'Search',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItem) {
              return GestureDetector(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedItem ?? 'Select',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: selectedItem == null
                                    ? Colors.grey
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onBackground,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context) {
    return Column(
      children: _items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        if (item['rateController'].text.isEmpty ||
            double.tryParse(item['rateController'].text) != item['rate']) {
          item['rateController'].text = item['rate'].toStringAsFixed(2);
        }
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  item['itemCode'] ?? 'Select Item',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item['itemCode'] == null
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                subtitle: Text(
                  'Amount: AED ${item['amount'].toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        item['isExpanded'] ? Icons.expand_less : Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          item['isExpanded'] = !item['isExpanded'];
                        });
                      },
                    ),
                    if (_items.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItemRow(index),
                      ),
                  ],
                ),
              ),
              if (item['isExpanded'])
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownSearch<String>(
                        items: (String filter, LoadProps? loadProps) =>
                            Future.value(
                              itemList
                                  .map((item) => item['item_code'] as String)
                                  .toList(),
                            ),
                        selectedItem: item['itemCode'],
                        onChanged: (value) {
                          setState(() {
                            item['itemCode'] = value;
                            final selectedItem = itemList.firstWhere(
                              (element) => element['item_code'] == value,
                              orElse: () => {
                                'item_name': '',
                                'uom': '',
                                'latest_price': {'price_list_rate': 0.0},
                                'price_history': [],
                              },
                            );
                            item['itemName'] = selectedItem['item_name'];
                            item['uom'] = selectedItem['uom'];
                            List<double> priceHistoryRates =
                                (selectedItem['price_history'] as List<dynamic>)
                                    .where(
                                      (price) => price['currency'] == 'AED',
                                    )
                                    .map<double>(
                                      (price) =>
                                          (price['price_list_rate'] as num)
                                              .toDouble(),
                                    )
                                    .toList();
                            final latestPrice =
                                (selectedItem['latest_price']['price_list_rate']
                                        as num)
                                    .toDouble();
                            if (selectedItem['latest_price']['currency'] ==
                                    'AED' &&
                                !priceHistoryRates.contains(latestPrice)) {
                              priceHistoryRates.add(latestPrice);
                            }
                            priceHistoryRates.sort((a, b) => b.compareTo(a));
                            item['priceHistoryRates'] = priceHistoryRates;
                            item['rate'] = latestPrice;
                            item['rateController'].text = item['rate']
                                .toStringAsFixed(2);
                            item['qty'].text = '1.000';
                            final qty =
                                double.tryParse(item['qty'].text) ?? 0.0;
                            item['amount'] = qty * item['rate'];
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Select an item' : null,
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              labelText: 'Search Item Code',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                        dropdownBuilder: (context, selectedItem) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            child: Text(
                              selectedItem ?? 'Select Item Code',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: selectedItem == null
                                        ? Colors.grey
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onBackground,
                                  ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item['deliveryDate'],
                        decoration: InputDecoration(
                          labelText: 'Delivery Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, item['deliveryDate']),
                        validator: (value) =>
                            value!.isEmpty ? 'Select a delivery date' : null,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item['qty'],
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) =>
                            value!.isEmpty || double.tryParse(value) == null
                            ? 'Enter a valid quantity'
                            : null,
                        onChanged: (value) {
                          setState(() {
                            final qty = double.tryParse(value) ?? 0.0;
                            item['amount'] = qty * item['rate'];
                          });
                        },
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<double>(
                              value:
                                  item['priceHistoryRates'].isNotEmpty &&
                                      item['priceHistoryRates'].contains(
                                        item['rate'],
                                      )
                                  ? item['rate']
                                  : null,
                              items: item['priceHistoryRates']
                                  .map<DropdownMenuItem<double>>((rate) {
                                    return DropdownMenuItem<double>(
                                      value: rate,
                                      child: Text(
                                        rate.toStringAsFixed(2),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: item['priceHistoryRates'].isNotEmpty
                                  ? (value) {
                                      setState(() {
                                        item['rate'] = value ?? 0.0;
                                        item['rateController'].text =
                                            item['rate'].toStringAsFixed(2);
                                        final qty =
                                            double.tryParse(item['qty'].text) ??
                                            0.0;
                                        item['amount'] = qty * item['rate'];
                                      });
                                    }
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Rate (AED)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                              isExpanded: true,
                              disabledHint: Text(
                                'No rates',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: item['rateController'],
                              decoration: InputDecoration(
                                labelText: 'Kepler Rate',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  value!.isEmpty ||
                                      double.tryParse(value) == null
                                  ? 'Enter a valid rate'
                                  : null,
                              onEditingComplete: () {
                                setState(() {
                                  final rate =
                                      double.tryParse(
                                        item['rateController'].text,
                                      ) ??
                                      0.0;
                                  item['rate'] = rate;
                                  if (rate == rate.truncateToDouble()) {
                                    item['rateController'].text = rate
                                        .toStringAsFixed(2);
                                  }
                                  final qty =
                                      double.tryParse(item['qty'].text) ?? 0.0;
                                  item['amount'] = qty * item['rate'];
                                });
                              },
                              onTap: () {
                                item['rateController'].selection =
                                    TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          item['rateController'].text.length,
                                    );
                              },
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
