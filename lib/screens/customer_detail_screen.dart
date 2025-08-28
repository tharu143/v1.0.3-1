import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String serverUrl;
  final String sid;

  const CustomerDetailScreen({
    Key? key,
    required this.customer,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic> customerDetails = {};
  String customerName = '';
  bool isLoading = false;
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
    setState(() {
      customerDetails = widget.customer;
      customerName = widget.customer['customer_name'] ?? 'Unknown Customer';
    });
  }

  Future<String?> _getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        return placemark.street != null && placemark.locality != null
            ? "${placemark.street}, ${placemark.locality}, ${placemark.country}"
            : placemark.locality ?? placemark.name ?? "Unknown";
      }
      return null;
    } catch (e) {
      print('Error fetching place name: $e');
      return null;
    }
  }

  Future<void> updateCustomerLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enable location services'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    PermissionStatus permission = await Permission.location.status;
    if (permission.isDenied || permission.isPermanentlyDenied) {
      permission = await Permission.location.request();
      if (permission.isDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission denied'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      } else if (permission.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please enable location permission in settings',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        await openAppSettings();
        return;
      }
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String latitude = position.latitude.toString();
      String longitude = position.longitude.toString();
      String? locationName = await _getPlaceName(
        position.latitude,
        position.longitude,
      );

      final url =
          "${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.update_customer_location1";
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode({
        'customer_name': customerName,
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName ?? 'Unknown',
      });

      final response = await http
          .put(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message']?['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            customerDetails['custom_latitude'] = data['message']['latitude'];
            customerDetails['custom_longtitude'] = data['message']['longitude'];
            customerDetails['custom_map_link'] =
                data['message']['custom_map_link'];
            customerDetails['custom_location'] = data['message']['location'];
            errorMessage = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message']['message'] ?? 'Location updated successfully',
              ),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.secondary, // 0xFF005B99
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          throw Exception(
            data['message']?['message'] ?? 'Failed to update location',
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to update location: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update location: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // Generate avatar text from the first letter of each word (up to two letters)
  String _getAvatarText(String name) {
    if (name.isEmpty) return 'N';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
    }
    return name[0].toUpperCase();
  }

  // Get avatar color based on the first letter of the name
  Color _getAvatarColor(String name) {
    if (name.isEmpty)
      return _letterColors['N'] ?? Theme.of(context).colorScheme.primary;
    return _letterColors[name[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  Widget _buildInfoRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = _getAvatarText(customerName);
    final avatarColor = _getAvatarColor(customerName);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          customerDetails['customer_name'] ?? 'Customer Details',
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.red,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: updateCustomerLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Customer Info Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                                      'Customer Info',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Customer Name',
                                customerDetails['customer_name'],
                              ),
                              _buildInfoRow(
                                'Owner',
                                customerDetails['custom_customer_owner'],
                              ),
                              _buildInfoRow(
                                'Account Manager',
                                customerDetails['custom_account_manager'],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Location Info Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                              Text(
                                'Location Info',
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Location',
                                customerDetails['custom_location'],
                              ),
                              _buildInfoRow(
                                'Latitude',
                                customerDetails['custom_latitude'],
                              ),
                              _buildInfoRow(
                                'Longitude',
                                customerDetails['custom_longtitude'],
                              ),
                              _buildInfoRow(
                                'Map Link',
                                customerDetails['custom_map_link'],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Action Button
                      ElevatedButton(
                        onPressed: updateCustomerLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Update Location'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
