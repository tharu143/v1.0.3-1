import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SalesInvoiceScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<String>? filterIds;

  const SalesInvoiceScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    this.filterIds,
  }) : super(key: key);

  @override
  _SalesInvoiceScreenState createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  List<dynamic> salesInvoices = [];
  List<dynamic> filteredInvoices = [];
  List<String>? filterIds;
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 0;
  final int pageSize = 20;
  bool hasMore = true;
  TextEditingController searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  String? searchQuery;
  bool isSessionValid = true;
  DateTimeRange? selectedDateRange;
  String errorMessage = '';

  // Define unique colors for each of the 26 English letters (blue-centric, same as customer_list_screen.dart)
  final Map<String, Color> _letterColors = {
    'A': const Color(0xFF0074c9), // Primary blue
    'B': const Color(0xFF005B99), // Secondary blue
    'C': const Color(0xFF003087), // Darker blue
    'D': const Color(0xFF1E90FF), // Dodger blue
    'E': const Color(0xFF4682B4), // Steel blue
    'F': const Color(0xFF6495ED), // Cornflower blue
    'G': const Color(0xFF00B7EB), // Cyan blue
    'H': const Color(0xFF4169E1), // Royal blue
    'I': const Color(0xFF87CEEB), // Sky blue
    'J': const Color(0xFF1C86EE), // Bright blue
    'K': const Color(0xFF104E8B), // Navy blue
    'L': const Color(0xFF63B8FF), // Light blue
    'M': const Color(0xFF00CED1), // Dark cyan (blue-ish)
    'N': const Color(0xFF5CACEE), // Soft blue
    'O': const Color(0xFF1874CD), // Medium blue
    'P': const Color(0xFF7B68EE), // Medium slate blue
    'Q': const Color(0xFF8470FF), // Light slate blue
    'R': const Color(0xFF6A5ACD), // Slate blue
    'S': const Color(0xFF483D8B), // Dark slate blue
    'T': const Color(0xFF00BFFF), // Deep sky blue
    'U': const Color(0xFF20B2AA), // Light sea blue
    'V': const Color(0xFF3A5FCD), // Medium blue
    'W': const Color(0xFF4A708B), // Dark blue-gray
    'X': const Color(0xFF607B8B), // Blue-gray
    'Y': const Color(0xFF7A67EE), // Soft slate blue
    'Z': const Color(0xFF1034A6), // Deep blue
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
      if (arguments != null && arguments.containsKey('filterIds')) {
        filterIds = List<String>.from(arguments['filterIds']);
        print('Filter IDs received: $filterIds');
      } else {
        filterIds = widget.filterIds;
      }
      await validateSession();
      if (isSessionValid) {
        fetchSalesInvoices();
      }
    });
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 300), () {
      filterInvoices(searchController.text);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      fetchSalesInvoices(loadMore: true);
    }
  }

  Future<void> validateSession() async {
    final url = "${widget.serverUrl}/api/method/frappe.auth.get_logged_user";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };

    try {
      print('Validating session: $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 4));
      print('Session Validation Response Status: ${response.statusCode}');
      print('Session Validation Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null) {
          print('Session is valid for user: ${data['message']}');
          setState(() {
            isSessionValid = true;
          });
        } else {
          throw Exception('Invalid session response');
        }
      } else {
        throw Exception('Session validation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error validating session: $e');
      setState(() {
        isSessionValid = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _refreshSalesInvoices() async {
    setState(() {
      currentPage = 0;
      salesInvoices.clear();
      filteredInvoices.clear();
      hasMore = true;
      searchQuery = null;
      searchController.clear();
      selectedDateRange = null;
      errorMessage = '';
    });
    await fetchSalesInvoices();
  }

  Future<void> fetchSalesInvoices({bool loadMore = false}) async {
    if (loadMore && !hasMore) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
      errorMessage = '';
    });

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_sales_invoices?page=$currentPage&page_size=$pageSize";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };

    try {
      print('Fetching sales invoices from API: $url');
      print('Headers: $headers');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message']['error'] != null) {
          throw Exception(data['message']['error']);
        }
        if (data['message']['message'] ==
                'Sales Invoices fetched successfully.' ||
            data['message']['message'] == 'No Sales Invoices found.') {
          setState(() {
            List<dynamic> newInvoices = List.from(
              data['message']['sales_invoices'] ?? [],
            );
            if (filterIds != null && filterIds!.isNotEmpty) {
              newInvoices = newInvoices
                  .where((invoice) => filterIds!.contains(invoice['name']))
                  .toList();
            }
            if (!loadMore) {
              salesInvoices = newInvoices;
            } else {
              salesInvoices.addAll(newInvoices);
            }
            filteredInvoices = List.from(salesInvoices)
              ..sort(
                (a, b) => (b['posting_date'] ?? '9999-12-31').compareTo(
                  a['posting_date'] ?? '9999-12-31',
                ),
              );
            if (searchQuery != null && searchQuery!.isNotEmpty) {
              filterInvoices(searchQuery!);
            }
            currentPage++;
            hasMore =
                data['message']['has_more'] == true &&
                (filterIds == null || filterIds!.isEmpty);
            isLoading = false;
            isLoadingMore = false;
          });
          print('Fetched sales invoices: ${salesInvoices.length}');
        } else {
          throw Exception(
            data['message']['message'] ?? 'Failed to load invoices',
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching invoices: $e');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
        errorMessage = 'Error fetching invoices: $e';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void filterInvoices(String query) {
    setState(() {
      searchQuery = query;
      filteredInvoices =
          salesInvoices.where((invoice) {
            final name = (invoice['name'] ?? '').toLowerCase();
            final customer = (invoice['customer_name'] ?? '').toLowerCase();
            final matchesSearchQuery =
                query.isEmpty ||
                name.contains(query.toLowerCase()) ||
                customer.contains(query.toLowerCase());
            bool matchesDateRange = true;
            if (selectedDateRange != null) {
              final postingDateStr = invoice['posting_date'];
              if (postingDateStr != null && postingDateStr.isNotEmpty) {
                try {
                  final postingDate = DateTime.parse(postingDateStr);
                  matchesDateRange =
                      postingDate.isAfter(
                        selectedDateRange!.start.subtract(
                          const Duration(days: 1),
                        ),
                      ) &&
                      postingDate.isBefore(
                        selectedDateRange!.end.add(const Duration(days: 1)),
                      );
                } catch (e) {
                  matchesDateRange = false;
                }
              } else {
                matchesDateRange = false;
              }
            }
            return matchesSearchQuery && matchesDateRange;
          }).toList()..sort(
            (a, b) => (b['posting_date'] ?? '9999-12-31').compareTo(
              a['posting_date'] ?? '9999-12-31',
            ),
          );
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDateRange) {
      setState(() {
        selectedDateRange = picked;
      });
      filterInvoices(searchController.text);
    }
  }

  // Generate avatar text from the first letter of each word (up to two letters)
  String _getAvatarText(String? customerName, String invoiceId) {
    if (customerName == null || customerName.isEmpty) {
      return invoiceId.isNotEmpty ? invoiceId[0].toUpperCase() : 'N';
    }
    final words = customerName.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
    }
    return customerName[0].toUpperCase();
  }

  // Get avatar color based on the first letter of the customer name or invoice ID
  Color _getAvatarColor(String? customerName, String invoiceId) {
    final name = customerName ?? (invoiceId.isNotEmpty ? invoiceId : 'N');
    return _letterColors[name[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSessionValid) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Text(
            'Session expired. Redirecting to login...',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Sales Invoices',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshSalesInvoices,
            tooltip: 'Refresh Invoices',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search and Filter Section
              Container(
                padding: const EdgeInsets.all(16.0),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search & Filter',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by Invoice ID or Customer',
                              hintStyle: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground.withOpacity(0.6),
                                  ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.6),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
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
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.date_range,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () => _selectDateRange(context),
                          tooltip: 'Select Date Range',
                        ),
                      ],
                    ),
                    if (selectedDateRange != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Date Range: ${formatDate(selectedDateRange!.start.toString())} - ${formatDate(selectedDateRange!.end.toString())}',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                selectedDateRange = null;
                              });
                              filterInvoices(searchController.text);
                            },
                            tooltip: 'Clear Date Range',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Invoice List Section
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: RefreshIndicator(
                    onRefresh: _refreshSalesInvoices,
                    color: Theme.of(context).colorScheme.primary,
                    child: isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                errorMessage,
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onBackground,
                                      fontSize: 18,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : filteredInvoices.isEmpty
                        ? Center(
                            child: Text(
                              'No invoices found',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontSize: 18,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                filteredInvoices.length + (hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredInvoices.length && hasMore) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: ElevatedButton(
                                    onPressed: isLoadingMore
                                        ? null
                                        : () => fetchSalesInvoices(
                                            loadMore: true,
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 3,
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                    ),
                                    child: isLoadingMore
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text(
                                            'Load More',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                  ),
                                );
                              }
                              final invoice = filteredInvoices[index];
                              final avatarText = _getAvatarText(
                                invoice['customer_name'],
                                invoice['name'],
                              );
                              final avatarColor = _getAvatarColor(
                                invoice['customer_name'],
                                invoice['name'],
                              );

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: avatarColor.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: avatarColor,
                                      child: Text(
                                        avatarText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      invoice['name'] ?? 'No Invoice ID',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: 18,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          invoice['customer_name'] ??
                                              'No Customer',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onBackground
                                                    .withOpacity(0.7),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Date: ${formatDate(invoice['posting_date'])}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onBackground
                                                    .withOpacity(0.7),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Total: ${invoice['currency'] ?? ''} ${invoice['grand_total']?.toStringAsFixed(2) ?? '0.00'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onBackground
                                                    .withOpacity(0.7),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/salesInvoiceDetail',
                                        arguments: {
                                          'invoiceId': invoice['name'],
                                          'serverUrl': widget.serverUrl,
                                          'sid': widget.sid,
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
