import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// This screen is for creating a new sales order.
// Make sure you have this file in your project.
import 'create_sales_order_screen.dart';

class SalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const SalesOrderScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });

  @override
  _SalesOrderScreenState createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  // State variables for managing data and UI
  List<dynamic> salesOrders = [];
  List<dynamic> filteredSalesOrders = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 0;
  final int pageSize = 20;
  bool hasMoreData = true;
  Map<String, dynamic>? selectedOrder;

  // Controllers and timers for UI interaction
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  // State for filters
  DateTimeRange? selectedDateRange;
  bool filterBySalesInvoice = false;
  bool filterByDeliveryNote = false;
  bool filterByNotCreatedDeliveryNote = false;
  bool filterByNotCreatedSalesInvoice = false;
  bool isFilterActive = false;

  // State for filter counts
  int salesInvoiceCount = 0;
  int deliveryNoteCount = 0;
  int notCreatedDeliveryNoteCount = 0;
  int notCreatedSalesInvoiceCount = 0;

  // Cache for connection details
  final Map<String, Map<String, dynamic>> connectionCache = {};

  // UI constants
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
    _fetchData(loadMore: false);
    _scrollController.addListener(_onScroll);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Load more data when user reaches the end of the list
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMoreData) {
      _fetchData(loadMore: true);
    }
  }

  void _onSearchChanged() {
    // Debounce to avoid sending too many requests while typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _evaluateFilters);
  }

  void _evaluateFilters() {
    final bool currentlyActive =
        searchController.text.isNotEmpty ||
        selectedDateRange != null ||
        filterBySalesInvoice ||
        filterByDeliveryNote ||
        filterByNotCreatedDeliveryNote ||
        filterByNotCreatedSalesInvoice;

    if (isFilterActive != currentlyActive) {
      setState(() {
        isFilterActive = currentlyActive;
      });
    }

    // If any filter is active, we need to fetch all data. Otherwise, we reset to the paginated view.
    if (isFilterActive) {
      _fetchData(loadMore: false, useFilteredApi: true);
    } else {
      _refreshSalesOrders();
    }
  }

  void _applyLocalFilters() {
    List<dynamic> tempFilteredList = List.from(salesOrders);
    final query = searchController.text.toLowerCase();

    // Apply search query locally
    if (query.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((order) {
        final name = (order['name'] ?? '').toLowerCase();
        final customer = (order['customer'] ?? '').toLowerCase();
        return name.contains(query) || customer.contains(query);
      }).toList();
    }

    // Apply status chip filters
    if (filterBySalesInvoice) {
      tempFilteredList = tempFilteredList
          .where(
            (order) =>
                (connectionCache[order['name']]?['sales_invoices'] as List?)
                    ?.isNotEmpty ??
                false,
          )
          .toList();
    } else if (filterByDeliveryNote) {
      tempFilteredList = tempFilteredList
          .where(
            (order) =>
                (connectionCache[order['name']]?['delivery_notes'] as List?)
                    ?.isNotEmpty ??
                false,
          )
          .toList();
    } else if (filterByNotCreatedDeliveryNote) {
      tempFilteredList = tempFilteredList
          .where(
            (order) =>
                (connectionCache[order['name']]?['delivery_notes'] as List?)
                    ?.isEmpty ??
                true,
          )
          .toList();
    } else if (filterByNotCreatedSalesInvoice) {
      tempFilteredList = tempFilteredList
          .where(
            (order) =>
                (connectionCache[order['name']]?['sales_invoices'] as List?)
                    ?.isEmpty ??
                true,
          )
          .toList();
    }

    setState(() {
      filteredSalesOrders = tempFilteredList;
    });
  }

  Future<void> _refreshSalesOrders() async {
    // Reset all filters and state, then fetch fresh data
    setState(() {
      currentPage = 0;
      salesOrders.clear();
      filteredSalesOrders.clear();
      hasMoreData = true;
      searchController.clear();
      selectedDateRange = null;
      filterBySalesInvoice = false;
      filterByDeliveryNote = false;
      filterByNotCreatedDeliveryNote = false;
      filterByNotCreatedSalesInvoice = false;
      connectionCache.clear();
      selectedOrder = null;
      isFilterActive = false;
      salesInvoiceCount = 0;
      deliveryNoteCount = 0;
      notCreatedDeliveryNoteCount = 0;
      notCreatedSalesInvoiceCount = 0;
    });
    await _fetchData(loadMore: false);
  }

  // --- API and Data Handling ---

  Future<void> _fetchData({
    required bool loadMore,
    bool useFilteredApi = false,
  }) async {
    if ((loadMore && !hasMoreData) || isLoadingMore) return;
    if (!mounted) return;

    setState(() {
      if (loadMore)
        isLoadingMore = true;
      else
        isLoading = true;
    });

    final String apiMethod = useFilteredApi
        ? "get_sales_orders_detailed1"
        : "get_sales_orders_detailed";
    final Map<String, String> queryParams = {};

    if (useFilteredApi) {
      if (searchController.text.isNotEmpty)
        queryParams['search_term'] = searchController.text;
      if (selectedDateRange != null) {
        queryParams['from_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(selectedDateRange!.start);
        queryParams['to_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(selectedDateRange!.end);
      }
    } else {
      queryParams['page'] = currentPage.toString();
      queryParams['page_size'] = pageSize.toString();
    }

    final uri = Uri.parse(
      "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.$apiMethod",
    ).replace(queryParameters: queryParams);
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        if (data == null || data['status'] != 'success') {
          throw http.Response(
            data?['message'] ?? 'Failed to load data',
            response.statusCode,
          );
        }

        final List<dynamic> newOrders = List.from(data['sales_orders'] ?? []);

        setState(() {
          if (loadMore)
            salesOrders.addAll(newOrders);
          else
            salesOrders = newOrders;

          if (!useFilteredApi) {
            currentPage++;
            hasMoreData = data['has_more'] == true;
          } else {
            hasMoreData = false;
          }
        });

        // After updating the list, fetch connections and update counts
        await _processConnectionsAndRecalculateCounts(newOrders);
        _applyLocalFilters();
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching data: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<void> _processConnectionsAndRecalculateCounts(
    List<dynamic> newOrders,
  ) async {
    final List<Future> connectionFutures = [];
    for (var order in newOrders) {
      if (connectionCache[order['name']] == null) {
        connectionFutures.add(fetchConnections(order['name'] ?? ''));
      }
    }
    await Future.wait(connectionFutures);

    int siCount = 0;
    int dnCount = 0;
    int notDnCount = 0;
    int notSiCount = 0;

    for (var order in salesOrders) {
      // Iterate over the full list
      final connections = connectionCache[order['name']];
      final bool hasSalesInvoices =
          (connections?['sales_invoices'] as List?)?.isNotEmpty ?? false;
      final bool hasDeliveryNotes =
          (connections?['delivery_notes'] as List?)?.isNotEmpty ?? false;

      if (hasSalesInvoices)
        siCount++;
      else
        notSiCount++;

      if (hasDeliveryNotes)
        dnCount++;
      else
        notDnCount++;
    }

    if (mounted) {
      setState(() {
        salesInvoiceCount = siCount;
        deliveryNoteCount = dnCount;
        notCreatedDeliveryNoteCount = notDnCount;
        notCreatedSalesInvoiceCount = notSiCount;
      });
    }
  }

  Future<Map<String, dynamic>> fetchConnections(String salesOrderId) async {
    if (salesOrderId.isEmpty)
      return {'sales_invoices': [], 'delivery_notes': []};
    if (connectionCache.containsKey(salesOrderId))
      return connectionCache[salesOrderId]!;

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.salestracking.get_sales_order_connections?sales_order_name=$salesOrderId";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']?['status'] == 'success') {
          if (mounted)
            setState(() => connectionCache[salesOrderId] = data['message']);
          return data['message'];
        }
      }
      throw http.Response(response.body, response.statusCode);
    } catch (e) {
      print('Error fetching connections for $salesOrderId: $e');
      return {'sales_invoices': [], 'delivery_notes': []};
    }
  }

  // --- UI and Widgets ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          selectedOrder != null
              ? (selectedOrder!['name'] ?? 'Details')
              : 'Sales Orders',
        ),
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
        actions: selectedOrder == null
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshSalesOrders,
                ),
              ]
            : null,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (selectedOrder != null)
              setState(() => selectedOrder = null);
            else
              Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: selectedOrder == null
            ? _buildListView(context)
            : _buildDetailsView(context),
      ),
      floatingActionButton: selectedOrder == null
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSalesOrderScreen(
                      serverUrl: widget.serverUrl,
                      sid: widget.sid,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  showErrorDialog(
                    context,
                    'Success',
                    'Sales order created successfully!',
                  );
                  _refreshSalesOrders();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildListView(BuildContext context) {
    return Column(
      children: [
        // Filters Section
        Container(
          padding: const EdgeInsets.all(16.0),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Order or Customer',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.date_range,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _selectDateRange(context),
                  ),
                ],
              ),
              if (selectedDateRange != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${formatDate(selectedDateRange!.start)} - ${formatDate(selectedDateRange!.end)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() => selectedDateRange = null);
                        _evaluateFilters();
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'DN Pending ($notCreatedDeliveryNoteCount)',
                      isSelected: filterByNotCreatedDeliveryNote,
                      color: _letterColors['N']!,
                      onTap: () {
                        setState(() {
                          filterByNotCreatedDeliveryNote =
                              !filterByNotCreatedDeliveryNote;
                          if (filterByNotCreatedDeliveryNote) {
                            filterBySalesInvoice = false;
                            filterByDeliveryNote = false;
                            filterByNotCreatedSalesInvoice = false;
                          }
                        });
                        _evaluateFilters();
                      },
                    ),
                    _buildFilterChip(
                      label: 'SI Pending ($notCreatedSalesInvoiceCount)',
                      isSelected: filterByNotCreatedSalesInvoice,
                      color: _letterColors['I']!,
                      onTap: () {
                        setState(() {
                          filterByNotCreatedSalesInvoice =
                              !filterByNotCreatedSalesInvoice;
                          if (filterByNotCreatedSalesInvoice) {
                            filterBySalesInvoice = false;
                            filterByDeliveryNote = false;
                            filterByNotCreatedDeliveryNote = false;
                          }
                        });
                        _evaluateFilters();
                      },
                    ),
                    _buildFilterChip(
                      label: 'Invoiced ($salesInvoiceCount)',
                      isSelected: filterBySalesInvoice,
                      color: _letterColors['S']!,
                      onTap: () {
                        setState(() {
                          filterBySalesInvoice = !filterBySalesInvoice;
                          if (filterBySalesInvoice) {
                            filterByDeliveryNote = false;
                            filterByNotCreatedDeliveryNote = false;
                            filterByNotCreatedSalesInvoice = false;
                          }
                        });
                        _evaluateFilters();
                      },
                    ),
                    _buildFilterChip(
                      label: 'Delivered ($deliveryNoteCount)',
                      isSelected: filterByDeliveryNote,
                      color: _letterColors['D']!,
                      onTap: () {
                        setState(() {
                          filterByDeliveryNote = !filterByDeliveryNote;
                          if (filterByDeliveryNote) {
                            filterBySalesInvoice = false;
                            filterByNotCreatedDeliveryNote = false;
                            filterByNotCreatedSalesInvoice = false;
                          }
                        });
                        _evaluateFilters();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Sales Orders List Section
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshSalesOrders,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSalesOrders.isEmpty
                    ? Center(
                        child: Text(
                          'No sales orders found.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount:
                            filteredSalesOrders.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredSalesOrders.length)
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );

                          final order = filteredSalesOrders[index];
                          final avatarText = _getAvatarText(
                            order['name'],
                            order['customer'],
                          );
                          final avatarColor = _getAvatarColor(
                            order['name'],
                            order['customer'],
                          );
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: avatarColor,
                                child: Text(
                                  avatarText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                order['name'] ?? 'No ID',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order['customer'] ?? 'No Customer'),
                                  Text(
                                    'Date: ${formatDate(order['transaction_date'])}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.info_outline),
                              onTap: () => setState(() => selectedOrder = order),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsView(BuildContext context) {
    final avatarText = _getAvatarText(
      selectedOrder!['name'],
      selectedOrder!['customer'],
    );
    final avatarColor = _getAvatarColor(
      selectedOrder!['name'],
      selectedOrder!['customer'],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    'Order Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Order Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Customer', selectedOrder!['customer'], context),
            _buildInfoRow('Status', selectedOrder!['status'], context),
            _buildInfoRow(
              'Delivery Status',
              selectedOrder!['delivery_status'],
              context,
            ),
            _buildInfoRow(
              'Date',
              formatDate(selectedOrder!['transaction_date']),
              context,
            ),
            _buildInfoRow(
              'Grand Total',
              selectedOrder!['grand_total']?.toString() ?? '0',
              context,
            ),
            const SizedBox(height: 24),
            Text(
              'Connections',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: fetchConnections(selectedOrder!['name']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  );

                final data =
                    snapshot.data ??
                    {'sales_invoices': [], 'delivery_notes': []};
                final deliveryNotes = data['delivery_notes'] as List;
                final salesInvoices = data['sales_invoices'] as List;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConnectionRow(
                      'Delivery Notes',
                      deliveryNotes.length,
                      _letterColors['D']!,
                    ),
                    ...deliveryNotes.map(
                      (note) =>
                          _buildConnectionItem(note['name'] ?? 'N/A', context),
                    ),
                    const SizedBox(height: 16),
                    _buildConnectionRow(
                      'Sales Invoices',
                      salesInvoices.length,
                      _letterColors['S']!,
                    ),
                    ...salesInvoices.map(
                      (invoice) => _buildConnectionItem(
                        invoice['name'] ?? 'N/A',
                        context,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Items',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._buildItemsList(selectedOrder!['items'], context),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets and Functions ---

  String _getAvatarText(String? name, String? customer) {
    final text = customer ?? name ?? '';
    if (text.isEmpty) return 'N';
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return text[0].toUpperCase();
  }

  Color _getAvatarColor(String? name, String? customer) {
    final text = customer ?? name ?? '';
    if (text.isEmpty) return _letterColors['N']!;
    return _letterColors[text[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  Widget _buildInfoRow(String label, String? value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildConnectionRow(String label, int count, Color badgeColor) {
    return Row(
      children: [
        Text(
          '$label ($count)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionItem(String name, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        children: [
          Icon(
            Icons.arrow_right,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItemsList(List<dynamic>? items, BuildContext context) {
    if (items == null || items.isEmpty) return [const Text('No items')];
    return items.map((item) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['item_name'] ?? 'Unknown Item',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Quantity', item['qty']?.toString() ?? '0', context),
            _buildInfoRow('Rate', item['rate']?.toString() ?? '0', context),
          ],
        ),
      );
    }).toList();
  }

  String formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final date = dateStr is DateTime
          ? dateStr
          : DateTime.parse(dateStr.toString());
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateStr.toString();
    }
  }

  // --- Error Handling and Dialogs ---

  String _parseFrappeException(String responseBody) {
    try {
      final data = json.decode(responseBody);
      if (data['exception'] != null && data['exception'] is String) {
        List parts = data['exception'].split(':');
        if (parts.length > 1) return parts.sublist(1).join(':').trim();
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
      if (data['message'] != null && data['message'] is String)
        return data['message'];
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
    if (cleanMessage.contains('Incorrect date value'))
      return "Invalid date format. $cleanMessage";
    switch (statusCode) {
      case 400:
        return "Bad Request: $cleanMessage";
      case 401:
        return "Unauthorized: $cleanMessage";
      case 403:
        return "Forbidden: $cleanMessage";
      case 404:
        return "Not Found: $cleanMessage";
      case 500:
        return "Internal Server Error: $cleanMessage";
      default:
        return "Error (Code: $statusCode): $cleanMessage";
    }
  }

  void showErrorDialog(BuildContext context, String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            color: title == 'Success'
                ? Colors.green.shade700
                : Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(_stripHtmlIfNeeded(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
    final friendlyMessage = statusCode != null
        ? getUserFriendlyMessage(statusCode, message)
        : _stripHtmlIfNeeded(_parseFrappeException(message));
    showErrorDialog(context, 'Error', friendlyMessage);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
    );
    if (picked != null && picked != selectedDateRange) {
      setState(() => selectedDateRange = picked);
      _evaluateFilters();
    }
  }
}
