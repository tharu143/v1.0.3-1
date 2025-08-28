import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../utils/error_handler.dart';
import 'dashboard_screen.dart'; // Reusing DashboardCard

class HRScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const HRScreen({required this.serverUrl, required this.sid, super.key});

  @override
  State<HRScreen> createState() => _HRScreenState();
}

class _HRScreenState extends State<HRScreen> {
  String? checkInTime;
  String? checkOutTime;
  String? duration;
  bool isCheckedIn = false;
  int _selectedIndex = 0;
  String employeeName = 'Loading...';
  String employeeId = 'Loading...';
  String? latitude;
  String? longitude;
  String? customLocation;
  String? customMapLink;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _fetchCheckIns();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
          final currentDateString = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.now());
          List<dynamic> rawCheckIns =
              (data['checkins']['in'] as List<dynamic>?) ?? [];
          List<dynamic> rawCheckOuts =
              (data['checkins']['out'] as List<dynamic>?) ?? [];

          final List<DateTime> todayCheckInTimes = rawCheckIns
              .where(
                (checkIn) =>
                    checkIn['time']?.toString().startsWith(currentDateString) ??
                    false,
              )
              .map((checkIn) => DateTime.parse(checkIn['time']))
              .toList();
          final List<DateTime> todayCheckOutTimes = rawCheckOuts
              .where(
                (checkOut) =>
                    checkOut['time']?.toString().startsWith(
                      currentDateString,
                    ) ??
                    false,
              )
              .map((checkOut) => DateTime.parse(checkOut['time']))
              .toList();

          todayCheckInTimes.sort((a, b) => a.compareTo(b));
          todayCheckOutTimes.sort((a, b) => a.compareTo(b));

          if (!mounted) return;
          setState(() {
            _timer?.cancel();
            DateTime? currentCheckInDateTime;
            DateTime? currentCheckOutDateTime;
            if (todayCheckInTimes.isNotEmpty) {
              currentCheckInDateTime = todayCheckInTimes.last;
            }
            if (todayCheckOutTimes.isNotEmpty) {
              currentCheckOutDateTime = todayCheckOutTimes.last;
            }

            if (currentCheckInDateTime != null) {
              checkInTime = currentCheckInDateTime.toIso8601String();
              if (currentCheckOutDateTime != null &&
                  currentCheckOutDateTime.isAfter(currentCheckInDateTime)) {
                checkOutTime = currentCheckOutDateTime.toIso8601String();
                isCheckedIn = false;
                duration = _calculateDuration(checkInTime!, checkOutTime!);
                _timer?.cancel();
              } else {
                checkOutTime = null;
                isCheckedIn = true;
                _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                  if (mounted) {
                    setState(() {
                      duration = _calculateDuration(
                        checkInTime!,
                        DateTime.now().toIso8601String(),
                      );
                    });
                  } else {
                    timer.cancel();
                  }
                });
              }
            } else {
              checkInTime = null;
              checkOutTime = null;
              duration = null;
              isCheckedIn = false;
              _timer?.cancel();
            }
          });
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

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    PermissionStatus permission = await Permission.location.status;
    if (permission.isDenied || permission.isPermanentlyDenied) {
      permission = await Permission.location.request();
      if (permission.isDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      } else if (permission.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        await openAppSettings();
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String? placeName = await _getPlaceName(
        position.latitude,
        position.longitude,
      );
      String mapLink = _generateMapLink(
        position.latitude.toString(),
        position.longitude.toString(),
      );

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
    }
  }

  Future<String?> _getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        return placemark.locality != null && placemark.country != null
            ? "${placemark.locality}, ${placemark.country}"
            : placemark.locality ?? placemark.name ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  Future<void> _handleCheckInOut(bool isCheckIn) async {
    if (latitude == null ||
        longitude == null ||
        customLocation == null ||
        customMapLink == null) {
      await _getCurrentLocation();
      if (latitude == null ||
          longitude == null ||
          customLocation == null ||
          customMapLink == null) {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          message:
              'Location unavailable. Please enable location services and try again.',
        );
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
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCheckIn
                  ? 'Checked In Successfully'
                  : 'Checked Out Successfully',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondary, // 0xFF005B99
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        await _fetchCheckIns();
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

  String _calculateDuration(String start, String end) {
    try {
      final startTime = DateTime.parse(start);
      final endTime = DateTime.parse(end);
      final diff = endTime.difference(startTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;
      return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    } catch (e) {
      print('Error parsing date/time for duration: $e');
      return '';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushNamed(
          context,
          '/leaveApplicationList',
          arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
        );
        break;
      case 1:
        Navigator.pushNamed(
          context,
          '/employeeList',
          arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
        );
        break;
      case 2:
        Navigator.pushNamed(
          context,
          '/attendanceList',
          arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'EEE, d MMM yyyy',
    ).format(DateTime.now());
    final String greeting = _getGreeting();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'HR Dashboard',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF0074c9),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting, $employeeName',
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Employee ID: $employeeId',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground
                                          .withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedDate,
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onBackground,
                                      fontSize: 16,
                                    ),
                              ),
                            ],
                          ),
                          Text(
                            isCheckedIn ? 'Checked In' : 'Not Checked In',
                            style: TextStyle(
                              color: isCheckedIn
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Today\'s Attendance',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isCheckedIn
                                ? null
                                : () => _handleCheckInOut(true),
                            icon: const Icon(Icons.login, size: 20),
                            label: const Text('Check In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: isCheckedIn ? 2 : 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isCheckedIn
                                ? () => _handleCheckInOut(false)
                                : null,
                            icon: const Icon(Icons.logout, size: 20),
                            label: const Text('Check Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: isCheckedIn ? 4 : 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3), // 0xFF0074c9
                        Theme.of(
                          context,
                        ).colorScheme.secondary.withOpacity(0.3), // 0xFF005B99
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0, // Prevents overflow
                        children: [
                          DashboardCard(
                            title: 'Leave',
                            icon: Icons.event,
                            gradientColors: [
                              Theme.of(context).colorScheme.primary.withOpacity(
                                0.7,
                              ), // 0xFF0074c9
                              Theme.of(context).colorScheme.secondary
                                  .withOpacity(0.7), // 0xFF005B99
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/leaveApplicationList',
                                arguments: {
                                  'serverUrl': widget.serverUrl,
                                  'sid': widget.sid,
                                },
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Employee',
                            icon: Icons.person,
                            gradientColors: [
                              Theme.of(context).colorScheme.secondary
                                  .withOpacity(0.7), // 0xFF005B99
                              Theme.of(context).colorScheme.primary.withOpacity(
                                0.7,
                              ), // 0xFF0074c9
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/employeeList',
                                arguments: {
                                  'serverUrl': widget.serverUrl,
                                  'sid': widget.sid,
                                },
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Attendance',
                            icon: Icons.check_circle,
                            gradientColors: [
                              Theme.of(context).colorScheme.primary.withOpacity(
                                0.7,
                              ), // 0xFF0074c9
                              Theme.of(context).colorScheme.secondary
                                  .withOpacity(0.7), // 0xFF005B99
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/attendanceList',
                                arguments: {
                                  'serverUrl': widget.serverUrl,
                                  'sid': widget.sid,
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(
            context,
          ).colorScheme.onBackground.withOpacity(0.6),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedIndex == 0
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.calendar, size: 24),
              ),
              label: 'Leave',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.user, size: 24),
              ),
              label: 'Employee',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedIndex == 2
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.clipboardCheck, size: 24),
              ),
              label: 'Attendance',
            ),
          ],
        ),
      ),
    );
  }
}
