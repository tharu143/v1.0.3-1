import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'utils.dart';

class DeliveryNoteListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String statusFilter;

  const DeliveryNoteListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.statusFilter,
  }) : super(key: key);

  @override
  _DeliveryNoteListScreenState createState() => _DeliveryNoteListScreenState();
}

class _DeliveryNoteListScreenState extends State<DeliveryNoteListScreen> {
  List<dynamic> deliveryNotes = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 0;
  final int pageSize = 20;
  bool hasMore = true;
  TextEditingController searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  String? searchQuery;

  @override
  void initState() {
    super.initState();
    fetchDeliveryNotes();
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
    Future.delayed(Duration(milliseconds: 300), () {
      filterDeliveryNotes(searchController.text);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      fetchDeliveryNotes(loadMore: true);
    }
  }

  Future<void> fetchDeliveryNotes({bool loadMore = false}) async {
    if (loadMore && !hasMore) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
    });

    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_delivery_note?page=$currentPage&page_size=$pageSize";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newNotes = List.from(
          data['message']['delivery_notes'] ?? [],
        );

        setState(() {
          if (!loadMore) {
            deliveryNotes = newNotes
                .where(
                  (note) =>
                      note['custom_custom_delivery_status'] ==
                          widget.statusFilter &&
                      widget.statusFilter != 'Completed',
                )
                .toList();
          } else {
            deliveryNotes.addAll(
              newNotes.where(
                (note) =>
                    note['custom_custom_delivery_status'] ==
                        widget.statusFilter &&
                    widget.statusFilter != 'Completed',
              ),
            );
          }

          if (searchQuery != null && searchQuery!.isNotEmpty) {
            filterDeliveryNotes(searchController.text);
          }

          deliveryNotes.sort(
            (a, b) => (b['posting_date'] ?? '9999-12-31').compareTo(
              a['posting_date'] ?? '9999-12-31',
            ),
          );

          currentPage++;
          hasMore = data['message']['has_more'] == true;
          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        throw Exception(
          'Failed to load delivery notes: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching delivery notes: $e');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching delivery notes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void filterDeliveryNotes(String query) {
    setState(() {
      searchQuery = query;
      deliveryNotes =
          deliveryNotes.where((note) {
            final name = note['name']?.toString().toLowerCase() ?? '';
            final customer = note['customer']?.toString().toLowerCase() ?? '';
            final searchLower = query.toLowerCase();
            return name.contains(searchLower) || customer.contains(searchLower);
          }).toList()..sort(
            (a, b) => (b['posting_date'] ?? '9999-12-31').compareTo(
              a['posting_date'] ?? '9999-12-31',
            ),
          );
    });
  }

  Color _getCustomDeliveryStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Not Delivered':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.statusFilter} Delivery Notes',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Note ID or Customer',
                  hintStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
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
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    currentPage = 0;
                    deliveryNotes.clear();
                    hasMore = true;
                  });
                  await fetchDeliveryNotes();
                },
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : deliveryNotes.isEmpty
                    ? Center(
                        child: Text(
                          'No delivery notes found',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: deliveryNotes.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == deliveryNotes.length && hasMore) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: isLoadingMore
                                    ? null
                                    : () => fetchDeliveryNotes(loadMore: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoadingMore
                                    ? CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        'Load More',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            );
                          }

                          final note = deliveryNotes[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    margin: EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getCustomDeliveryStatusColor(
                                        note['custom_custom_delivery_status'] ??
                                            '',
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      note['name']?[0] ?? 'N',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                note['name'] ?? 'No Note ID',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note['customer'] ?? 'No Customer',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(color: Colors.black87),
                                  ),
                                  Text(
                                    'Date: ${formatDate(note['posting_date'])}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onTap: () {
                                final status =
                                    note['custom_custom_delivery_status'] ??
                                    'Not Delivered';
                                if (status == 'Delivered') {
                                  Navigator.pushNamed(
                                    context,
                                    '/deliveredDetail',
                                    arguments: {
                                      'noteId': note['name'],
                                      'serverUrl': widget.serverUrl,
                                      'sid': widget.sid,
                                    },
                                  );
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    '/deliveryNoteDetail',
                                    arguments: {
                                      'noteId': note['name'],
                                      'serverUrl': widget.serverUrl,
                                      'sid': widget.sid,
                                    },
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
