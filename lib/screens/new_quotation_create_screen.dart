import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/error_handler.dart';

// A new screen for creating a Quotation with dynamic party selection.
class NewQuotationCreateScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const NewQuotationCreateScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _NewQuotationCreateScreenState createState() =>
      _NewQuotationCreateScreenState();
}

class _NewQuotationCreateScreenState extends State<NewQuotationCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- FORM FIELDS ---
  String? _series;
  // This field controls which party list is shown. Default is 'Lead'.
  String _quotationToSource = 'Lead';
  String? _selectedPartyValue; // Stores the ID of the selected party
  final TextEditingController _partyDisplayController =
      TextEditingController(); // To display the party name
  final String _orderType = 'Sales';
  String? _selectedQuotationOwner;
  final String _company = 'KEPLER TECH LLC';

  // Controllers
  final TextEditingController _transactionDateController =
      TextEditingController();
  final TextEditingController _validTillController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

  final List<Map<String, dynamic>> _items = [];

  // --- API DATA LISTS ---
  bool isLoading = true;
  List<Map<String, String>> allParties = []; // Combined list of all parties
  List<Map<String, String>> filteredPartyList =
      []; // List filtered by _quotationToSource
  List<String> seriesList = [];
  List<String> quotationOwnerEmails = [];
  List<Map<String, dynamic>> itemList = [];

  @override
  void initState() {
    super.initState();
    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _selectedQuotationOwner = widget.email;
    _initializeData();
    _addItemRow();
  }

  @override
  void dispose() {
    _transactionDateController.dispose();
    _validTillController.dispose();
    _termsController.dispose();
    _partyDisplayController.dispose();
    for (var item in _items) {
      item['qty']?.dispose();
      item['rateController']?.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _fetchAllParties(),
      _fetchNamingSeries(),
      _fetchItems(),
      _fetchQuotationOwners(),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // Fetches all potential parties (Leads, Customers, etc.) and stores them in one list.
  Future<void> _fetchAllParties() async {
    final List<Map<String, String>> combinedParties = [];
    // Fetch Leads
    try {
      final leadsUrl =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_leads';
      final leadsResponse = await http.get(
        Uri.parse(leadsUrl),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (leadsResponse.statusCode == 200) {
        final leadsData =
            json.decode(leadsResponse.body)['message']['data'] as List;
        for (var lead in leadsData) {
          combinedParties.add({
            "value": lead['name'],
            "display": lead['lead_name'],
            "type": "Lead",
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching leads: $e');
    }

    // Fetch Customers
    try {
      final customersUrl =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_customers1';
      final customersResponse = await http.get(
        Uri.parse(customersUrl),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (customersResponse.statusCode == 200) {
        final customersData =
            json.decode(customersResponse.body)['message']['customers'] as List;
        for (var customer in customersData) {
          combinedParties.add({
            "value": customer['name'],
            "display": customer['customer_name'],
            "type": "Customer",
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }

    if (mounted) {
      setState(() {
        allParties = combinedParties;
        _updateFilteredPartyList(); // Initial filter based on default source
      });
    }
  }

  // This function filters the 'allParties' list based on the selected 'Quotation To' source.
  void _updateFilteredPartyList() {
    setState(() {
      filteredPartyList = allParties
          .where((party) => party['type'] == _quotationToSource)
          .toList();
    });
  }

  Future<void> _fetchNamingSeries() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_quotation_naming_series';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'doctype': 'Quotation'}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          seriesList = List<String>.from(
            data['message']['naming_series_options'] ?? [],
          );
          if (seriesList.isNotEmpty) {
            _series = seriesList[0];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching quotation naming series: $e');
    }
  }

  Future<void> _fetchQuotationOwners() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\",\"=\",1]]";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200 && mounted) {
        List<dynamic> data = json.decode(response.body)['data'];
        setState(() {
          quotationOwnerEmails = data
              .map((user) => user['email'] as String)
              .toList();
          if (_selectedQuotationOwner != null &&
              !quotationOwnerEmails.contains(_selectedQuotationOwner)) {
            quotationOwnerEmails.add(_selectedQuotationOwner!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching quotation owners: $e');
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
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(
          () => itemList = List<Map<String, dynamic>>.from(
            data['message']['items'] ?? [],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching items: $e');
    }
  }

  Future<void> _createQuotation() async {
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
      "doctype": "Quotation",
      "naming_series": _series,
      "quotation_to": _quotationToSource,
      "party_name": _selectedPartyValue,
      "order_type": _orderType,
      "company": _company,
      "transaction_date": _transactionDateController.text,
      "valid_till": _validTillController.text,
      "items": itemsPayload,
      "terms": _termsController.text,
      "owner": _selectedQuotationOwner,
    });

    try {
      final response = await http.post(
        Uri.parse("${widget.serverUrl}/api/resource/Quotation"),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quotation created successfully!',
              style: TextStyle(color: Colors.white),
            ),
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _addItemRow() {
    setState(
      () => _items.add({
        'itemCode': null,
        'itemName': null,
        'uom': null,
        'qty': TextEditingController(text: '1.000'),
        'rate': 0.0,
        'rateController': TextEditingController(text: '0.00'),
        'amount': 0.0,
      }),
    );
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
          'Create Quotation',
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
                        title: 'Quotation Details',
                        context: context,
                        child: Column(
                          children: [
                            _buildDropdownField(
                              labelText: 'Quotation To',
                              value: _quotationToSource,
                              items: const [
                                'Lead',
                                'Customer',
                              ], // Simplified for available APIs
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _quotationToSource = v;
                                    _selectedPartyValue = null;
                                    _partyDisplayController.clear();
                                    _updateFilteredPartyList();
                                  });
                                }
                              },
                              prefixIcon: Icons.source,
                            ),
                            const SizedBox(height: 16),
                            _buildPartySearchField(),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Series',
                              value: _series,
                              items: seriesList,
                              onChanged: (v) => setState(() => _series = v),
                              validator: (v) => v == null ? 'Required' : null,
                              prefixIcon: Icons.format_list_numbered,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Quotation Owner',
                              value: _selectedQuotationOwner,
                              items: quotationOwnerEmails,
                              onChanged: (v) =>
                                  setState(() => _selectedQuotationOwner = v),
                              validator: (v) => v == null ? 'Required' : null,
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _transactionDateController,
                              labelText: 'Date',
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
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _validTillController,
                              labelText: 'Valid Till',
                              readOnly: true,
                              onTap: () =>
                                  _selectDate(context, _validTillController),
                              prefixIcon: Icons.event_available,
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
                        title: 'Terms and Conditions',
                        context: context,
                        child: _buildTextField(
                          controller: _termsController,
                          labelText: 'Terms',
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          prefixIcon: Icons.notes,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : _createQuotation,
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
                                'Save Quotation',
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
        tooltip: 'Add Item',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildPartySearchField() {
    return TextFormField(
      controller: _partyDisplayController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: _quotationToSource, // Dynamic label
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: const Icon(Icons.business),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showPartySearchDialog(),
        ),
      ),
      onTap: () => _showPartySearchDialog(),
      validator: (value) => value == null || value.isEmpty
          ? 'Please select a $_quotationToSource' // Dynamic validation message
          : null,
    );
  }

  Future<void> _showPartySearchDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final searchResults = filteredPartyList.where((party) {
              final displayName = party['display']?.toLowerCase() ?? '';
              return displayName.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: Text('Select $_quotationToSource'), // Dynamic title
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
                        itemCount: searchResults.length,
                        itemBuilder: (context, i) {
                          final party = searchResults[i];
                          return ListTile(
                            title: Text(party['display'] ?? ''),
                            onTap: () => Navigator.of(context).pop(party),
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
        _selectedPartyValue = result['value'];
        _partyDisplayController.text = result['display'] ?? '';
      });
    }
  }

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
    final validValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      value: validValue,
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
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
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
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
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
                            onTap: () =>
                                Navigator.of(context).pop(selectedItem),
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
}
