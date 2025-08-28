// lib/screens/create_quotation_screen.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/error_handler.dart';

class CreateQuotationScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final Map<String, dynamic>? lead; // Optional lead data

  const CreateQuotationScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    this.lead,
  }) : super(key: key);

  @override
  _CreateQuotationScreenState createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form State
  String? _series;
  String _quotationTo = 'Lead';
  String? _partyName;
  String? _customerName;
  String _orderType = 'Sales';
  String? _currency;
  String? _priceList;
  bool _ignorePricingRule = false;
  bool _disableRoundedTotal = false;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _validTillController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

  List<Map<String, dynamic>> _items = [];

  // API Data
  List<String> _seriesList = [];
  List<Map<String, dynamic>> _partyList = [];
  List<Map<String, dynamic>> _itemList = [];
  List<String> _currencyList = [];
  List<String> _priceLists = [];

  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _debounce;

  // Calculated Totals
  double _totalQty = 0;
  double _totalAmount = 0;
  double _grandTotal = 0;
  double _totalTaxes = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _addItemRow();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await Future.wait([_fetchInitialDropdowns(), _fetchItems()]);

    // Pre-fill form if navigating from a lead
    if (widget.lead != null) {
      _quotationTo = 'Lead';
      _partyName = widget.lead!['name']; // This is the ID for the backend
      _customerName = widget.lead!['lead_name']; // This is for display
      await _fetchPartyData(_quotationTo);
    } else {
      await _fetchPartyData(_quotationTo);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchInitialDropdowns() async {
    // Fetch Naming Series
    try {
      final seriesUrl =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_quotation_naming_series';
      final seriesRes = await http.post(
        Uri.parse(seriesUrl),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'doctype': 'Quotation'}),
      );
      if (seriesRes.statusCode == 200) {
        final data = json.decode(seriesRes.body);
        _seriesList = List<String>.from(data['message'] ?? []);
        if (_seriesList.isNotEmpty) _series = _seriesList[0];
      }
    } catch (e) {
      debugPrint("Error fetching naming series: $e");
    }

    // Fetch Currencies and Price Lists (simplified)
    _currencyList = ['AED', 'USD', 'EUR', 'INR'];
    _priceLists = ['Standard Selling', 'Standard Buying'];
    _currency = 'AED';
    _priceList = 'Standard Selling';
  }

  Future<void> _fetchPartyData(String partyType) async {
    String endpoint;
    String dataKey;
    if (partyType == 'Lead') {
      endpoint =
          '/api/method/saletracking.saletracking.salestracking_api.role_api.get_leads';
      dataKey = 'data';
    } else if (partyType == 'Customer') {
      endpoint =
          '/api/method/saletracking.saletracking.salestracking_api.role_api.get_customers1';
      dataKey = 'customers';
    } else {
      // Opportunity
      endpoint =
          '/api/method/saletracking.saletracking.salestracking_api.role_api.get_opportunities';
      dataKey = 'data';
    }

    try {
      final response = await http.post(
        Uri.parse(widget.serverUrl + endpoint),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'email': widget.email}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _partyList = List<Map<String, dynamic>>.from(
              data['message'][dataKey] ?? [],
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching party data for $partyType: $e");
      if (mounted)
        showApiErrorDialog(
          context,
          message: "Failed to fetch $partyType list.",
        );
    }
  }

  Future<void> _fetchItems() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_items_with_price_history1';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _itemList = List<Map<String, dynamic>>.from(
              data['message']['items'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching items: $e');
    }
  }

  void _calculateTotals() {
    double totalQty = 0;
    double totalAmount = 0;
    for (var item in _items) {
      totalQty += double.tryParse(item['qty'].text) ?? 0.0;
      totalAmount += item['amount'] ?? 0.0;
    }
    setState(() {
      _totalQty = totalQty;
      _totalAmount = totalAmount;
      _grandTotal = _totalAmount + _totalTaxes;
    });
  }

  void _addItemRow() {
    setState(() {
      _items.add({
        'item_code': null,
        'item_name': null,
        'uom': null,
        'qty': TextEditingController(text: '1.0'),
        'rateController': TextEditingController(text: '0.00'),
        'rate': 0.0,
        'amount': 0.0,
      });
    });
    _calculateTotals();
  }

  void _removeItemRow(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index]['qty'].dispose();
        _items[index]['rateController'].dispose();
        _items.removeAt(index);
      });
      _calculateTotals();
    }
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) {
      showApiErrorDialog(
        context,
        message: 'Please fix the errors before saving.',
      );
      return;
    }
    setState(() => _isSaving = true);

    final itemsPayload = _items
        .where((item) => item['item_code'] != null)
        .map(
          (item) => {
            "item_code": item['item_code'],
            "qty": double.tryParse(item['qty'].text) ?? 0.0,
            "rate": item['rate'],
            "amount": item['amount'],
          },
        )
        .toList();

    final payload = {
      "doctype": "Quotation",
      "naming_series": _series,
      "quotation_to": _quotationTo,
      "party_name":
          _partyName, // This will be the Lead ID, Customer Name, or Opp ID
      "transaction_date": _dateController.text,
      "valid_till": _validTillController.text,
      "order_type": _orderType,
      "currency": _currency,
      "selling_price_list": _priceList,
      "ignore_pricing_rule": _ignorePricingRule ? 1 : 0,
      "items": itemsPayload,
      "tc_name": _termsController.text,
      "notes": _notesController.text,
    };

    try {
      final response = await http.post(
        Uri.parse("${widget.serverUrl}/api/resource/Quotation"),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dateController.dispose();
    _validTillController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    for (var item in _items) {
      item['qty'].dispose();
      item['rateController'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Quotation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildModuleCard(
                      title: 'Details',
                      context: context,
                      child: Column(
                        children: [
                          _buildDropdownField(
                            labelText: 'Series',
                            value: _series,
                            items: _seriesList,
                            onChanged: (v) => setState(() => _series = v),
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            labelText: 'Quotation To',
                            value: _quotationTo,
                            items: ['Lead', 'Customer', 'Opportunity'],
                            onChanged: (value) {
                              setState(() {
                                _quotationTo = value!;
                                _partyName = null;
                                _customerName = null;
                                _partyList = [];
                              });
                              _fetchPartyData(value!);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSearchableDropdown(
                            labelText: _quotationTo,
                            value: _customerName,
                            onTap: () => _showPartySearchDialog(),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _dateController,
                            labelText: 'Date',
                            readOnly: true,
                            onTap: () => _selectDate(context, _dateController),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _validTillController,
                            labelText: 'Valid Till',
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _validTillController),
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            labelText: 'Order Type',
                            value: _orderType,
                            items: ['Sales', 'Maintenance', 'Shopping Cart'],
                            onChanged: (v) => setState(() => _orderType = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModuleCard(
                      title: 'Items',
                      context: context,
                      child: _buildItemsTable(),
                    ),
                    const SizedBox(height: 16),
                    _buildModuleCard(
                      title: 'Address & Contact',
                      context: context,
                      child: Text(
                        'Address and contact details will be fetched from selected $_quotationTo.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModuleCard(
                      title: 'Terms',
                      context: context,
                      child: _buildTextField(
                        controller: _termsController,
                        labelText: 'Terms and Conditions',
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModuleCard(
                      title: 'More Info',
                      context: context,
                      child: _buildTextField(
                        controller: _notesController,
                        labelText: 'Notes',
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveQuotation,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Quotation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper Widgets
  Widget _buildModuleCard({
    required String title,
    required Widget child,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Colors.grey),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: value,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildSearchableDropdown({
    required String labelText,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        child: Text(value ?? 'Select $labelText'),
      ),
    );
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
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _showPartySearchDialog() async {
    String searchQuery = '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredList = _partyList.where((party) {
              final name = party['name']?.toString().toLowerCase() ?? '';
              final customerName =
                  party['customer_name']?.toString().toLowerCase() ??
                  party['lead_name']?.toString().toLowerCase() ??
                  '';
              final query = searchQuery.toLowerCase();
              return name.contains(query) || customerName.contains(query);
            }).toList();

            return AlertDialog(
              title: Text('Select $_quotationTo'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      autofocus: true,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, i) {
                          final party = filteredList[i];
                          return ListTile(
                            title: Text(party['name'] ?? ''),
                            subtitle: Text(
                              party['customer_name'] ??
                                  party['lead_name'] ??
                                  '',
                            ),
                            onTap: () => Navigator.of(context).pop(party),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _partyName = result['name'];
        _customerName = result['customer_name'] ?? result['lead_name'];
      });
    }
  }

  Future<void> _showItemSearchDialog(int index) async {
    String searchQuery = '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = _itemList.where((item) {
              final itemCode =
                  item['item_code']?.toString().toLowerCase() ?? '';
              final itemName =
                  item['item_name']?.toString().toLowerCase() ?? '';
              final query = searchQuery.toLowerCase();
              return itemCode.contains(query) || itemName.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Select Item'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      autofocus: true,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, i) {
                          final selectedItem = filteredItems[i];
                          return ListTile(
                            title: Text(selectedItem['item_code'] ?? ''),
                            subtitle: Text(selectedItem['item_name'] ?? ''),
                            onTap: () =>
                                Navigator.of(context).pop(selectedItem),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        final item = _items[index];
        item['item_code'] = result['item_code'];
        item['item_name'] = result['item_name'];
        item['uom'] = result['uom'];
        item['rate'] =
            (result['latest_price']?['price_list_rate'] as num?)?.toDouble() ??
            0.0;
        item['rateController'].text = item['rate'].toStringAsFixed(2);
        final qty = double.tryParse(item['qty'].text) ?? 1.0;
        item['amount'] = qty * item['rate'];
      });
      _calculateTotals();
    }
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_items.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeItemRow(index),
                      ),
                  ],
                ),
                InkWell(
                  onTap: () => _showItemSearchDialog(index),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Item",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(item['item_code'] ?? 'Select Item'),
                  ),
                ),
                if (item['item_name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item['item_name'],
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: item['qty'],
                        labelText: 'Qty',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onTap: () =>
                            (item['qty'] as TextEditingController).selectAll(),
                        onChanged: (value) {
                          setState(() {
                            final qty = double.tryParse(value) ?? 0.0;
                            item['amount'] = qty * item['rate'];
                          });
                          _calculateTotals();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        controller: item['rateController'],
                        labelText: 'Rate (AED)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onTap: () =>
                            (item['rateController'] as TextEditingController)
                                .selectAll(),
                        onChanged: (value) {
                          setState(() {
                            final rate = double.tryParse(value) ?? 0.0;
                            item['rate'] = rate;
                            final qty =
                                double.tryParse(item['qty'].text) ?? 0.0;
                            item['amount'] = qty * rate;
                          });
                          _calculateTotals();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Amount: AED ${item['amount'].toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Quantity: $_totalQty',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Total: AED ${_totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

extension SelectAllExtension on TextEditingController {
  void selectAll() {
    if (text.isEmpty) return;
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}
