import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/payment_entry.dart';
import 'payment_entry_detail_screen.dart';

class PaymentEntryListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const PaymentEntryListScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });

  @override
  _PaymentEntryListScreenState createState() => _PaymentEntryListScreenState();
}

class _PaymentEntryListScreenState extends State<PaymentEntryListScreen> {
  List<PaymentEntry> paymentEntries = [];
  List<PaymentEntry> filteredPaymentEntries = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 1;
  final int pageSize = 20;
  TextEditingController searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  bool hasMoreData = true;
  String? searchQuery;

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
    fetchPaymentEntries();
    _scrollController.addListener(_onScroll);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMoreData) {
      fetchPaymentEntries(loadMore: true);
    }
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 300), () {
      filterPaymentEntries(searchController.text);
    });
  }

  Future<void> fetchPaymentEntries({bool loadMore = false}) async {
    if (loadMore && !hasMoreData) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
    });

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_payment_entry?page=$currentPage&limit=$pageSize";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      print('Fetching payment entries: URL=$url, Headers=$headers');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 4));

      print('Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        final List<dynamic> newEntries = List.from(
          data['payment_entries'] ?? [],
        );

        if (mounted) {
          setState(() {
            if (!loadMore) {
              paymentEntries = newEntries
                  .map((entry) => PaymentEntry.fromJson(entry))
                  .toList();
            } else {
              paymentEntries.addAll(
                newEntries
                    .map((entry) => PaymentEntry.fromJson(entry))
                    .toList(),
              );
            }
            filteredPaymentEntries = List.from(paymentEntries)
              ..sort(
                (a, b) => (b.postingDate ?? '9999-12-31').compareTo(
                  a.postingDate ?? '9999-12-31',
                ),
              );
            if (searchQuery != null && searchQuery!.isNotEmpty) {
              filterPaymentEntries(searchQuery!);
            }
            currentPage++;
            hasMoreData = data['has_more'] == true;
            isLoading = false;
            isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
          setState(() {
            isLoading = false;
            isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching payment entries: $e');
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  void filterPaymentEntries(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredPaymentEntries = List.from(paymentEntries)
          ..sort(
            (a, b) => (b.postingDate ?? '9999-12-31').compareTo(
              a.postingDate ?? '9999-12-31',
            ),
          );
      } else {
        filteredPaymentEntries =
            paymentEntries.where((entry) {
              final name = (entry.name ?? '').toLowerCase();
              final party = (entry.partyName ?? '').toLowerCase();
              return name.contains(query.toLowerCase()) ||
                  party.contains(query.toLowerCase());
            }).toList()..sort(
              (a, b) => (b.postingDate ?? '9999-12-31').compareTo(
                a.postingDate ?? '9999-12-31',
              ),
            );
      }
    });
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr ?? 'N/A';
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
          'Payment Entries',
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
            //             'Payment Entries',
            //             style: Theme.of(context).textTheme.titleLarge!.copyWith(
            //               color: Theme.of(context).colorScheme.primary,
            //               fontWeight: FontWeight.bold,
            //               fontSize: 20,
            //             ),
            //             overflow: TextOverflow.ellipsis,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchTextField(
                      controller: searchController,
                      icon: Icons.search,
                    ),
                    const SizedBox(height: 8),
                    isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : filteredPaymentEntries.isEmpty
                        ? Center(
                            child: Text(
                              'No payment entries found',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontSize: 18,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() {
                                currentPage = 1;
                                paymentEntries.clear();
                                filteredPaymentEntries.clear();
                                hasMoreData = true;
                              });
                              await fetchPaymentEntries();
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  filteredPaymentEntries.length +
                                  (hasMoreData ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filteredPaymentEntries.length &&
                                    hasMoreData) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: ElevatedButton(
                                      onPressed: isLoadingMore
                                          ? null
                                          : () => fetchPaymentEntries(
                                              loadMore: true,
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                final entry = filteredPaymentEntries[index];
                                final entryLetter =
                                    entry.name?.isNotEmpty == true
                                    ? entry.name![0].toUpperCase()
                                    : 'P';
                                final entryAvatarColor =
                                    _letterColors[entryLetter] ??
                                    Theme.of(context).colorScheme.primary;
                                return Card(
                                  color: Theme.of(context).colorScheme.surface,
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: entryAvatarColor,
                                      child: Text(
                                        entryLetter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      entry.name ?? 'No Entry ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.partyName ?? 'No Party',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Date: ${formatDate(entry.postingDate)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(color: Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.info_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PaymentEntryDetailScreen(
                                                paymentEntry: entry,
                                                serverUrl: widget.serverUrl,
                                                sid: widget.sid,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/paymentEntryCreate',
            arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
          );
          if (result == true) {
            setState(() {
              currentPage = 1;
              paymentEntries.clear();
              filteredPaymentEntries.clear();
              hasMoreData = true;
            });
            await fetchPaymentEntries();
          }
        },
        backgroundColor: Theme.of(context).colorScheme.secondary,
        tooltip: 'Create Payment Entry',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchTextField({
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
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
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    controller.clear();
                    filterPaymentEntries('');
                  },
                )
              : null,
          hintText: 'Search by Entry ID or Party...',
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
      ),
    );
  }
}
