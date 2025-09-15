import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/error_handler.dart';

class CreateOpportunityFromLeadScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final String leadId;
  final String partyName; // This is the friendly name for display
  final String? opportunityOwner;

  const CreateOpportunityFromLeadScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    required this.leadId,
    required this.partyName,
    this.opportunityOwner,
  }) : super(key: key);

  @override
  _CreateOpportunityFromLeadScreenState createState() =>
      _CreateOpportunityFromLeadScreenState();
}

class _CreateOpportunityFromLeadScreenState
    extends State<CreateOpportunityFromLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  // Opportunity fields
  String? _series = 'CRM-OPP-.2024.-';
  final String _opportunityFrom = 'Lead';
  String? _partyNameForDisplay;
  String? _status = 'Open';
  final String _company = 'KEPLER TECH LLC';
  final TextEditingController _transactionDateController =
      TextEditingController();
  final TextEditingController _opportunityDiscussionController =
      TextEditingController();
  final TextEditingController _leadIdController = TextEditingController();
  String? _selectedOpportunityOwner;

  // Item table fields
  final List<Map<String, dynamic>> _items = [
    {
      'itemCode': null,
      'itemName': null,
      'uom': null,
      'qty': TextEditingController(text: '1.000'),
      'rate': 0.0,
      'rateController': TextEditingController(text: '0.00'),
      'amount': 0.0,
    },
  ];

  // API-fetched data
  List<String> seriesList = [];
  List<Map<String, dynamic>> itemList = [];
  List<String> opportunityOwnerEmails = [];

  bool isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _partyNameForDisplay = widget.partyName; // For UI
    _leadIdController.text = widget.leadId; // For Payload
    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _selectedOpportunityOwner = widget.opportunityOwner;

    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _fetchNamingSeries(),
      _fetchItems(),
      _fetchOpportunityOwners(),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _transactionDateController.dispose();
    _opportunityDiscussionController.dispose();
    _leadIdController.dispose();
    for (var item in _items) {
      item['qty'].dispose();
      item['rateController'].dispose();
    }
    super.dispose();
  }

  Future<void> _fetchNamingSeries() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_opportunity_naming_series';
    try {
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
            if (!seriesList.contains('CRM-OPP-.2024.-')) {
              seriesList.insert(0, 'CRM-OPP-.2024.-');
            }
            _series = 'CRM-OPP-.2024.-';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching naming series: $e');
      if (mounted) {
        setState(() {
          seriesList = ['CRM-OPP-.2024.-', 'CRM-OPP-.YYYY.-'];
          _series = 'CRM-OPP-.2024.-';
        });
      }
    }
  }

  Future<void> _fetchOpportunityOwners() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\",\"=\",1]]";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body)['data'];
        if (mounted) {
          setState(() {
            opportunityOwnerEmails = data
                .map((user) => user['email'] as String)
                .toList();
            if (_selectedOpportunityOwner != null &&
                !opportunityOwnerEmails.contains(_selectedOpportunityOwner)) {
              opportunityOwnerEmails.add(_selectedOpportunityOwner!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching opportunity owners: $e');
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

  Future<void> _createOpportunity() async {
    if (!_formKey.currentState!.validate()) {
      showApiErrorDialog(
        context,
        message: 'Please fix the errors before saving.',
      );
      return;
    }

    setState(() => isLoading = true);

    final itemsPayload = _items
        .where((item) => item['itemCode'] != null)
        .map(
          (item) => {
            "item_code": item['itemCode'],
            "item_name": item['itemName'],
            "uom": item['uom'],
            "qty": double.tryParse(item['qty'].text) ?? 0.0,
            "rate": item['rate'],
            "amount": item['amount'],
          },
        )
        .toList();

    final body = jsonEncode({
      "data": {
        "naming_series": _series,
        "opportunity_from": _opportunityFrom,
        "lead": _leadIdController.text,
        "party_name": _leadIdController.text, // Use Lead ID for party_name
        "status": _status,
        "company": _company,
        "transaction_date": _transactionDateController.text,
        "items": itemsPayload,
        "opportunity_discussion": _opportunityDiscussionController.text,
        "opportunity_owner": _selectedOpportunityOwner,
      },
    });

    try {
      final response = await http.post(
        Uri.parse("${widget.serverUrl}/api/resource/Opportunity"),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opportunity created successfully!',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          int count = 0;
          Navigator.of(context).popUntil((_) => count++ >= 2);
        }
      } else {
        if (mounted)
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _addItemRow() {
    setState(() {
      _items.add({
        'itemCode': null,
        'itemName': null,
        'uom': null,
        'qty': TextEditingController(text: '1.000'),
        'rate': 0.0,
        'rateController': TextEditingController(text: '0.00'),
        'amount': 0.0,
      });
    });
  }

  void _removeItemRow(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index]['qty'].dispose();
        _items[index]['rateController'].dispose();
        _items.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Opportunity from Lead',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModuleCard(
                        title: 'Opportunity Details',
                        context: context,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: TextEditingController(
                                text: _partyNameForDisplay,
                              ),
                              labelText: 'Party Name (Display)',
                              readOnly: true,
                              prefixIcon: Icons.person,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _leadIdController,
                              labelText: 'Lead ID (Party for API)',
                              readOnly: true,
                              prefixIcon: Icons.link,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Series',
                              value: _series,
                              items: seriesList,
                              onChanged: (value) =>
                                  setState(() => _series = value),
                              validator: (value) => value == null
                                  ? 'Please select a series'
                                  : null,
                              prefixIcon: Icons.format_list_numbered,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Opportunity Owner',
                              value: _selectedOpportunityOwner,
                              items: opportunityOwnerEmails,
                              onChanged: (value) => setState(
                                () => _selectedOpportunityOwner = value,
                              ),
                              validator: (value) => value == null
                                  ? 'Please select an owner'
                                  : null,
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Status',
                              value: _status,
                              items: const [
                                'Open',
                                'Quotation',
                                'Converted',
                                'Lost',
                                'Replied',
                                'Closed',
                              ],
                              onChanged: (value) =>
                                  setState(() => _status = value),
                              validator: (value) => value == null
                                  ? 'Please select a status'
                                  : null,
                              prefixIcon: Icons.info_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _transactionDateController,
                              labelText: 'Opportunity Date',
                              readOnly: true,
                              onTap: () => _selectDate(
                                context,
                                _transactionDateController,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Please select a date'
                                  : null,
                              prefixIcon: Icons.calendar_today,
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
                      _buildModuleCard(
                        title: 'More Information',
                        context: context,
                        child: _buildTextField(
                          controller: _opportunityDiscussionController,
                          labelText: 'Opportunity Discussion',
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          prefixIcon: Icons.notes,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : _createOpportunity,
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
                                'Save Opportunity',
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
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
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
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
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
      validator: validator,
      isExpanded: true,
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
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
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
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Search by Item Code or Name',
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
                            onTap: () {
                              Navigator.of(context).pop(selectedItem);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        final item = _items[index];
        final selectedItem = result;
        item['itemCode'] = selectedItem['item_code'];
        item['itemName'] = selectedItem['item_name'];
        item['uom'] = selectedItem['uom'];
        item['rate'] =
            (selectedItem['latest_price']?['price_list_rate'] as num?)
                ?.toDouble() ??
            0.0;
        item['rateController'].text = item['rate'].toStringAsFixed(2);
        final qty = double.tryParse(item['qty'].text) ?? 1.0;
        item['amount'] = qty * item['rate'];
      });
    }
  }

  Widget _buildItemsTable(BuildContext context) {
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
                    child: Text(item['itemCode'] ?? 'Select Item'),
                  ),
                ),
                if (item['itemName'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item['itemName'],
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
                        onTap: () => item['qty'].selectAll(),
                        validator: (v) =>
                            v == null || v.isEmpty || double.tryParse(v) == null
                            ? 'Invalid'
                            : null,
                        onChanged: (value) {
                          setState(() {
                            final qty = double.tryParse(value) ?? 0.0;
                            item['amount'] = qty * item['rate'];
                          });
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
                        onTap: () => item['rateController'].selectAll(),
                        validator: (v) =>
                            v == null || v.isEmpty || double.tryParse(v) == null
                            ? 'Invalid'
                            : null,
                        onChanged: (value) {
                          setState(() {
                            final rate = double.tryParse(value) ?? 0.0;
                            item['rate'] = rate;
                            final qty =
                                double.tryParse(item['qty'].text) ?? 0.0;
                            item['amount'] = qty * rate;
                          });
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
