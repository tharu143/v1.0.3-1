import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/error_handler.dart';

class CreateSalesOrderFromQuotationScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final Map<String, dynamic> quotation;

  const CreateSalesOrderFromQuotationScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    required this.quotation,
  }) : super(key: key);

  @override
  _CreateSalesOrderFromQuotationScreenState createState() =>
      _CreateSalesOrderFromQuotationScreenState();
}

class _CreateSalesOrderFromQuotationScreenState
    extends State<CreateSalesOrderFromQuotationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form State & Controllers
  String? _series;
  String? _customer;
  String? _costCenter;
  final String _orderType = 'Sales';
  final TextEditingController _transactionDateController =
      TextEditingController();
  final TextEditingController _poNoController = TextEditingController();
  List<Map<String, dynamic>> _items = [];

  // API Data
  List<String> seriesList = [];
  List<String> costCenterList = [];
  List<Map<String, dynamic>> itemList = []; // To hold all available items
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _customer = widget.quotation['party_name']?.toString() ?? '';
    _poNoController.text = widget.quotation['name'];

    // Pre-fill items from the quotation, now including a delivery date
    _items = (widget.quotation['items'] as List<dynamic>).map((item) {
      return {
        'itemCode': item['item_code'],
        'itemName': item['item_name'],
        'deliveryDate': TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        'qty': TextEditingController(text: (item['qty'] ?? 1.0).toString()),
        'rateController': TextEditingController(
          text: (item['rate'] ?? 0.0).toStringAsFixed(2),
        ),
        'rate': (item['rate'] as num?)?.toDouble() ?? 0.0,
        'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    await Future.wait([
      fetchNamingSeries(),
      fetchCostCenters(),
      fetchItems(), // Fetch all items for the search dialog
    ]);

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _transactionDateController.dispose();
    _poNoController.dispose();
    for (var item in _items) {
      item['qty'].dispose();
      item['rateController'].dispose();
      item['deliveryDate'].dispose();
    }
    super.dispose();
  }

  // --- API Methods ---
  Future<void> fetchNamingSeries() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_sales_order_naming_series';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            seriesList = List<String>.from(
              data['message']['naming_series_options'] ?? [],
            );
            // **FIXED**: Set the first item as the default selected series
            if (seriesList.isNotEmpty) {
              _series = seriesList[0];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching naming series: $e');
    }
  }

  Future<void> fetchCostCenters() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_cost_centers';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          costCenterList = List<String>.from(
            (data['message'] ?? []).map((item) => item['name']),
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching cost centers: $e');
    }
  }

  Future<void> fetchItems() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_items_with_price_history1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            itemList = List<Map<String, dynamic>>.from(
              data['message']['items'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching items: $e');
    }
  }

  Future<void> _createSalesOrder() async {
    if (!_formKey.currentState!.validate()) {
      showApiErrorDialog(
        context,
        message: 'Please fix the errors before saving.',
      );
      return;
    }
    setState(() => isLoading = true);

    final itemsPayload = _items.map((item) {
      return {
        "item_code": item['itemCode'],
        "delivery_date": item['deliveryDate'].text, // Added delivery date
        "qty": double.tryParse(item['qty'].text) ?? 0.0,
        "rate": item['rate'],
        "amount": item['amount'],
      };
    }).toList();

    final body = jsonEncode({
      "naming_series": _series,
      "transaction_date": _transactionDateController.text,
      "customer": _customer,
      "order_type": _orderType,
      "po_no": _poNoController.text,
      "items": itemsPayload,
      "company": "KEPLER TECH LLC",
      "cost_center": _costCenter,
      "items_from_quotation": widget.quotation['name'],
      // **NEW**: Added Sales Team information to the payload
      "sales_team": [
        {"sales_person": widget.email, "allocated_percentage": 100},
      ],
    });

    try {
      final response = await http.post(
        Uri.parse("${widget.serverUrl}/api/resource/Sales Order"),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales Order created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        int count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 2);
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UI & Helper Methods ---
  void _addItemRow() {
    setState(() {
      _items.add({
        'itemCode': null,
        'itemName': null,
        'deliveryDate': TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        'qty': TextEditingController(text: '1.0'),
        'rateController': TextEditingController(text: '0.00'),
        'rate': 0.0,
        'amount': 0.0,
      });
    });
  }

  void _removeItemRow(int index) {
    // Allow removing any item, not just if length > 1
    setState(() {
      _items[index]['qty'].dispose();
      _items[index]['rateController'].dispose();
      _items[index]['deliveryDate'].dispose();
      _items.removeAt(index);
    });
  }

  void _updateItemAmount(int index) {
    final item = _items[index];
    final qty = double.tryParse(item['qty'].text) ?? 0.0;
    final rate = double.tryParse(item['rateController'].text) ?? 0.0;
    setState(() {
      item['rate'] = rate;
      item['amount'] = qty * rate;
    });
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
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _showItemSearchDialog(int index) async {
    String searchQuery = '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = itemList.where((item) {
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
        item['itemCode'] = result['item_code'];
        item['itemName'] = result['item_name'];
        final rate =
            (result['latest_price']?['price_list_rate'] as num?)?.toDouble() ??
            0.0;
        item['rate'] = rate;
        item['rateController'].text = rate.toStringAsFixed(2);
        _updateItemAmount(index);
      });
    }
  }

  Future<void> _showSearchDialog({
    required String title,
    required List<String> items,
    required Function(String) onSelected,
  }) async {
    String searchQuery = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items
                .where(
                  (item) =>
                      item.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Text(title),
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
                          return ListTile(
                            title: Text(filteredItems[i]),
                            onTap: () =>
                                Navigator.of(context).pop(filteredItems[i]),
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
      onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Sales Order from Quotation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildModuleCard(
                        title: 'Sales Order Details',
                        context: context,
                        child: Column(
                          children: [
                            _buildDropdownField(
                              labelText: 'Series',
                              value: _series,
                              items: seriesList,
                              onChanged: (value) =>
                                  setState(() => _series = value),
                              prefixIcon: Icons.format_list_numbered,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: TextEditingController(
                                text: _customer,
                              ),
                              labelText: 'Customer',
                              readOnly: true,
                              prefixIcon: Icons.person,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _transactionDateController,
                              labelText: 'Date',
                              readOnly: true,
                              onTap: () {}, // Date is fixed to today
                              prefixIcon: Icons.calendar_today,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _poNoController,
                              labelText: 'Quotation No. (as PO)',
                              readOnly: true,
                              prefixIcon: Icons.receipt,
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () => _showSearchDialog(
                                title: 'Select Cost Center',
                                items: costCenterList,
                                onSelected: (selectedValue) {
                                  setState(() => _costCenter = selectedValue);
                                },
                              ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Cost Center',
                                  prefixIcon: const Icon(Icons.business),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                child: Text(
                                  _costCenter ?? 'Select Cost Center',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModuleCard(
                        title: 'Items',
                        context: context,
                        child: _buildItemsTable(context),
                      ),
                      const SizedBox(height: 16),
                      // **NEW**: Sales Team Card
                      _buildSalesTeamCard(context),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : _createSalesOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Create Sales Order',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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

  // --- Reusable UI Widgets ---
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

  // **NEW**: Widget for the Sales Team card
  Widget _buildSalesTeamCard(BuildContext context) {
    return _buildModuleCard(
      title: 'Sales Team',
      context: context,
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Sales Person',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'Contribution (%)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text(widget.email)),
              const Expanded(child: Text('100', textAlign: TextAlign.right)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    IconData? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
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

  Widget _buildItemsTable(BuildContext context) {
    return Column(
      children: _items.asMap().entries.map((entry) {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showItemSearchDialog(index),
                      child: Text(
                        item['itemName'] ?? 'Select Item',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeItemRow(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['itemCode'] ?? '',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: item['deliveryDate'],
                labelText: 'Delivery Date',
                readOnly: true,
                onTap: () => _selectDate(context, item['deliveryDate']),
                prefixIcon: Icons.calendar_today,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: item['qty'],
                      labelText: 'Qty',
                      onTap: () => item['qty'].selectAll(),
                      onChanged: (value) => _updateItemAmount(index),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      controller: item['rateController'],
                      labelText: 'Rate (AED)',
                      onTap: () => item['rateController'].selectAll(),
                      onChanged: (value) => _updateItemAmount(index),
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
    );
  }
}

extension SelectAllExtension on TextEditingController {
  void selectAll() {
    if (text.isEmpty) return;
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}
