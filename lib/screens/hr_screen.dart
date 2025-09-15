import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// A dialog to show API errors
void showApiErrorDialog(BuildContext context,
    {int? statusCode, required String message}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(statusCode != null ? 'Error: $statusCode' : 'Error'),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

class HRScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const HRScreen({required this.serverUrl, required this.sid, required this.email, super.key});

  @override
  State<HRScreen> createState() => _HRScreenState();
}

class _HRScreenState extends State<HRScreen> with TickerProviderStateMixin {
  // State variables
  String? checkInTime;
  String? checkOutTime;
  bool isCheckedIn = false;
  bool _isLoading = true;
  bool _isLocationLoading = false;

  String employeeName = 'Loading...';
  String employeeId = 'Loading...';
  String? latitude;
  String? longitude;
  String? customLocation;
  String? customMapLink;

  // Animation controller for the punch button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // Initial data fetching
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchUserInfo();
    await _fetchCheckIns();
    await _getCurrentLocation();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic ---

  Future<void> _fetchUserInfo() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_logged_in_user_info';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['message'];
        if (data['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            employeeName = data['user']['full_name'] ?? 'Unknown User';
            employeeId = data['user']['employee_id'] ?? 'N/A';
          });
        } else {
          if (!mounted) return;
          showApiErrorDialog(context, message: 'User not found in the system.');
        }
      } else {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> _fetchCheckIns() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_employee_checkins';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['message'];
        if (data['status'] == 'success') {
          final currentDateString =
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          List<dynamic> rawCheckIns = (data['checkins']['in'] as List?) ?? [];
          List<dynamic> rawCheckOuts =
              (data['checkins']['out'] as List?) ?? [];

          final todayCheckInTimes = rawCheckIns
              .where((c) =>
                  c['time']?.toString().startsWith(currentDateString) ?? false)
              .map((c) => DateTime.parse(c['time']))
              .toList();
          final todayCheckOutTimes = rawCheckOuts
              .where((c) =>
                  c['time']?.toString().startsWith(currentDateString) ?? false)
              .map((c) => DateTime.parse(c['time']))
              .toList();

          todayCheckInTimes.sort((a, b) => a.compareTo(b));
          todayCheckOutTimes.sort((a, b) => a.compareTo(b));

          if (!mounted) return;
          setState(() {
            DateTime? lastCheckIn =
                todayCheckInTimes.isNotEmpty ? todayCheckInTimes.last : null;
            DateTime? lastCheckOut =
                todayCheckOutTimes.isNotEmpty ? todayCheckOutTimes.last : null;

            if (lastCheckIn != null) {
              checkInTime = lastCheckIn.toIso8601String();
              if (lastCheckOut != null && lastCheckOut.isAfter(lastCheckIn)) {
                checkOutTime = lastCheckOut.toIso8601String();
                isCheckedIn = false;
              } else {
                checkOutTime = null;
                isCheckedIn = true;
              }
            } else {
              checkInTime = null;
              checkOutTime = null;
              isCheckedIn = false;
            }
          });
        }
      } else {
        if (!mounted) return;
        showApiErrorDialog(context,
            statusCode: response.statusCode, message: response.body);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    }
  }

  // --- Location & Check-in/out Logic ---

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    // Check service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('To check in/out, please enable location services.')));
      }
      setState(() => _isLocationLoading = false);
      return;
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')));
        }
        setState(() => _isLocationLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Location permissions are permanently denied.')));
        await openAppSettings();
      }
      setState(() => _isLocationLoading = false);
      return;
    }

    // Get current location
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String? placeName =
          await _getPlaceName(position.latitude, position.longitude);
      String mapLink = _generateMapLink(
          position.latitude.toString(), position.longitude.toString());

      if (!mounted) return;
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
        customLocation = placeName;
        customMapLink = mapLink;
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: 'Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  Future<String?> _getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        return "${p.locality}, ${p.country}";
      }
      return 'Unknown Location';
    } catch (e) {
      return 'Could not get location name';
    }
  }

  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  Future<void> _handleCheckInOut(bool isCheckIn) async {
    _animationController.forward().then((_) => _animationController.reverse());
    // Ensure location is available
    if (latitude == null || longitude == null) {
      await _getCurrentLocation();
      if (latitude == null || longitude == null) {
        if (!mounted) return;
        showApiErrorDialog(context,
            message:
                'Location unavailable. Please check permissions and try again.');
        return;
      }
    }

    final url = '${widget.serverUrl}/api/resource/Employee Checkin';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'employee': employeeId,
      'employee_name': employeeName,
      'log_type': isCheckIn ? 'IN' : 'OUT',
      'time': DateTime.now().toIso8601String(),
      'device_id': customLocation?.toLowerCase() ?? 'unknown',
      'latitude': latitude,
      'longitude': longitude,
      'custom_map_link': customMapLink,
      'custom_location': customLocation,
      'skip_auto_attendance': 0,
      'is_mobile': 1,
    });

    try {
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isCheckIn ? 'Checked In Successfully' : 'Checked Out Successfully'),
            backgroundColor: isCheckIn ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchCheckIns(); // Refresh state
      } else {
        if (!mounted) return;
        showApiErrorDialog(context,
            statusCode: response.statusCode, message: response.body);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    }
  }

  // --- Helpers & UI Builders ---

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _navigateTo(String routeName) {
    Navigator.pushNamed(
      context,
      routeName,
      arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        titleTextStyle: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.titleLarge?.color),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUserInfoCard(),
                    const SizedBox(height: 30),
                    _buildAttendanceAction(),
                    const SizedBox(height: 30),
                    _buildNavigationGrid(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserInfoCard() {
    final greeting = _getGreeting();
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.person,
                    size: 32, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                    Text(
                      employeeName,
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (checkInTime != null && isCheckedIn) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.login, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Check-in',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white.withOpacity(0.8)),
                    ),
                    Text(
                      DateFormat('h:mm a').format(DateTime.parse(checkInTime!)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildAttendanceAction() {
    final theme = Theme.of(context);
    return Column(
      children: [
         Text(
          "Ready to start your day?",
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: () {
              if (isCheckedIn) {
                _handleCheckInOut(false); // Check out
              } else {
                _handleCheckInOut(true); // Check in
              }
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isCheckedIn
                          ? [Colors.orange.shade600, Colors.red.shade400]
                          : [theme.colorScheme.primary, theme.colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCheckedIn ? Icons.logout : Icons.login,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCheckedIn ? 'PUNCH OUT' : 'PUNCH IN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        _isLocationLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text("Fetching location...",
                      style: theme.textTheme.bodySmall),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on,
                      color: theme.textTheme.bodySmall?.color, size: 16),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      customLocation ?? 'Location not available',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildNavigationGrid() {
     final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: [
            ActionCard(
              title: 'Leave',
              icon: FontAwesomeIcons.calendarDay,
              onTap: () => _navigateTo('/leaveApplicationList'),
            ),
            ActionCard(
              title: 'Employees',
              icon: FontAwesomeIcons.users,
              onTap: () => _navigateTo('/employeeList'),
            ),
            ActionCard(
              title: 'Attendance',
              icon: FontAwesomeIcons.clipboardCheck,
              onTap: () => _navigateTo('/attendanceList'),
            ),
            ActionCard(
              title: 'Leave Dashboard',
              icon: Icons.dashboard_customize,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/leaveDashboard',
                  arguments: {
                    'serverUrl': widget.serverUrl,
                    'sid': widget.sid,
                    'email': widget.email,
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// Card for quick actions
class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color,
                child: FaIcon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

