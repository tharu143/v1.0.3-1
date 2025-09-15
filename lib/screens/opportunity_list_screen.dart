import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OpportunityListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const OpportunityListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _OpportunityListScreenState createState() => _OpportunityListScreenState();
}

class _OpportunityListScreenState extends State<OpportunityListScreen> {
  List<dynamic> opportunities = [];
  List<dynamic> filteredOpportunities = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchOpportunities();
    searchController.addListener(filterOpportunities);
  }

  @override
  void dispose() {
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

  String _stripHtmlIfNeeded(String text) {
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

  Future<void> fetchOpportunities() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final url =
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_opportunities';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
      };
      final body = json.encode({'email': widget.email});

      print('Fetching opportunities: URL=$url, Headers=$headers, Body=$body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          final data = json.decode(response.body);
          setState(() {
            opportunities = data['message']['data'] ?? [];
            filteredOpportunities = List.from(opportunities);
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      print('Error fetching opportunities: $e');
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
        setState(() => isLoading = false);
      }
    }
  }

  void filterOpportunities() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredOpportunities = opportunities.where((opp) {
        final oppId = opp['name']?.toString().toLowerCase() ?? '';
        final partyName = opp['party_name']?.toString().toLowerCase() ?? '';
        final title = opp['title']?.toString().toLowerCase() ?? '';
        return oppId.contains(query) ||
            partyName.contains(query) ||
            title.contains(query);
      }).toList();
    });
  }

  void _navigateToDetailView(Map<String, dynamic> opportunity) {
    Navigator.pushNamed(
      context,
      '/opportunityDetail',
      arguments: {
        'serverUrl': widget.serverUrl,
        'sid': widget.sid,
        'opportunity': opportunity,
        'email': widget.email,
      },
    );
  }

  void _navigateToCreateOpportunity() {
    Navigator.pushNamed(
      context,
      '/newOpptunityCreate',
      arguments: {
        'serverUrl': widget.serverUrl,
        'sid': widget.sid,
        'email': widget.email,
      },
    ).then((result) {
      if (result == true) {
        fetchOpportunities();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatarLetter = widget.email.isNotEmpty
        ? widget.email[0].toUpperCase()
        : 'O';
    final avatarColor =
        _letterColors[avatarLetter] ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Opportunities',
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
            //             'Opportunities',
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
                    const SizedBox(height: 16),
                    isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : filteredOpportunities.isEmpty
                        ? Center(
                            child: Text(
                              'No opportunities found',
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
                            onRefresh: fetchOpportunities,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredOpportunities.length,
                              itemBuilder: (context, index) {
                                final opp = filteredOpportunities[index];
                                final oppLetter =
                                    opp['title']?.isNotEmpty == true
                                    ? opp['title'][0].toUpperCase()
                                    : 'O';
                                final oppAvatarColor =
                                    _letterColors[oppLetter] ??
                                    Theme.of(context).colorScheme.primary;
                                return Card(
                                  color: Theme.of(context).colorScheme.surface,
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: oppAvatarColor,
                                      child: Text(
                                        oppLetter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      opp['name'] ?? 'No ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      opp['title'] ?? 'No Title',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    onTap: () => _navigateToDetailView(opp),
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
        onPressed: _navigateToCreateOpportunity,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        tooltip: 'Create Opportunity',
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
                    filterOpportunities();
                  },
                )
              : null,
          hintText: 'Search by ID, Party, or Title...',
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
}
