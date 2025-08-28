import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DeliveryNoteScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<String>? filterIds;

  const DeliveryNoteScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    this.filterIds,
  }) : super(key: key);

  @override
  _DeliveryNoteScreenState createState() => _DeliveryNoteScreenState();
}

class _DeliveryNoteScreenState extends State<DeliveryNoteScreen> {
  List<dynamic> deliveryNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDeliveryNotes();
  }

  Future<void> fetchDeliveryNotes() async {
    setState(() => isLoading = true);
    final url =
        "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_delivery_note";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          deliveryNotes = List.from(data['message']['delivery_notes'] ?? []);
          if (widget.filterIds != null && widget.filterIds!.isNotEmpty) {
            deliveryNotes = deliveryNotes
                .where((note) => widget.filterIds!.contains(note['name']))
                .toList();
          }
          isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to load: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  int getDeliveredCount() {
    return deliveryNotes
        .where((note) => note['custom_custom_delivery_status'] == 'Delivered')
        .length;
  }

  int getNotDeliveredCount() {
    return deliveryNotes
        .where(
          (note) => note['custom_custom_delivery_status'] == 'Not Delivered',
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Delivery Notes',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => fetchDeliveryNotes(),
        child: Container(
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
          child: SafeArea(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        shrinkWrap: true,
                        physics: AlwaysScrollableScrollPhysics(),
                        childAspectRatio: 1.0,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/delivery_note_list',
                              arguments: {
                                'serverUrl': widget.serverUrl,
                                'sid': widget.sid,
                                'statusFilter': 'Delivered',
                              },
                            ),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              color: Colors.white.withOpacity(0.9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.motorcycle,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    'Delivered',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2ECC71),
                                    ),
                                  ),
                                  SizedBox(height: 4.0),
                                  Text(
                                    '${getDeliveredCount()}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/delivery_note_list',
                              arguments: {
                                'serverUrl': widget.serverUrl,
                                'sid': widget.sid,
                                'statusFilter': 'Not Delivered',
                              },
                            ),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              color: Colors.white.withOpacity(0.9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    'Not Delivered',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE74C3C),
                                    ),
                                  ),
                                  SizedBox(height: 4.0),
                                  Text(
                                    '${getNotDeliveredCount()}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
