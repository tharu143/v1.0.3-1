import 'dart:convert';
import 'dart:io'; // Import for SocketException
import 'dart:async'; // Import for TimeoutException

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// Removed: import 'package:dropdown_search/dropdown_search.dart';

// Assuming this file exists and is correctly implemented
import 'create_opportunity_screen.dart';

/// Service class for handling local notifications.
class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notification service.
  /// Configures local timezone and requests necessary permissions for Android and iOS.
  Future<void> init() async {
    await _configureLocalTimeZone();

    // Request notification permissions based on platform
    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    // Combine platform-specific settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// Configures the local timezone for accurate scheduling of notifications.
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones(); // Initialize timezone data
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName)); // Set local timezone
      debugPrint('Local timezone set: $timeZoneName');
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
    }
  }

  /// Schedules a follow-up notification.
  ///
  /// [id]: Unique identifier for the notification.
  /// [title]: Title of the notification.
  /// [body]: Body text of the notification.
  /// [scheduledDateTime]: The exact date and time when the notification should appear.
  Future<void> scheduleFollowUpNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
  }) async {
    try {
      final now = DateTime.now();
      // Ensure notification is scheduled for the future.
      // Add a small buffer (e.g., 5 seconds) to avoid scheduling in the immediate past or present.
      if (scheduledDateTime.isBefore(now.add(const Duration(seconds: 5)))) {
        debugPrint(
          'Scheduled time $scheduledDateTime is in the past or too close. Not scheduling.',
        );
        return;
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDateTime, tz.local), // Use local timezone
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'follow_up_channel_id', // Channel ID
            'Follow-Up Notifications', // Channel name
            channelDescription: 'Channel for visit follow-up reminders',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher', // Notification icon
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default.wav', // Default sound
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Removed uiLocalNotificationDateInterpretation as it's causing issues
        // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        'Notification scheduled: ID=$id, Title=$title, Body=$body, ScheduledTime=$scheduledDateTime',
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }
}

/// Enum to define different types of visits.
enum VisitType { customer, isNewVisit, followUp, newOpportunity }

/// A StatefulWidget for the Daily Visit Screen, allowing users to log daily visits.
class DailyVisitScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  /// Constructor for DailyVisitScreen.
  const DailyVisitScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _DailyVisitScreenState createState() => _DailyVisitScreenState();
}

/// The State class for DailyVisitScreen.
class _DailyVisitScreenState extends State<DailyVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final NotificationService _notificationService = NotificationService();

  // State Variables
  List<dynamic> customers = [];
  List<dynamic> filteredCustomers = []; // For custom search dialog
  List<dynamic> businesses = []; // List to store fetched businesses
  List<dynamic> filteredBusinesses = []; // For custom search dialog

  // Visit Type Selection
  VisitType? _selectedPrimaryVisitType;
  final Set<VisitType> _selectedSecondaryVisitTypes = {};

  // Form fields data
  String?
  selectedCustomerDocName; // Stores the 'name' (docname) of the selected customer
  String? customerDisplayName; // Stores the 'customer_name' for display
  String?
  selectedBusinessDocName; // Stores the 'name' (docname) of the selected business
  String?
  businessDisplayName; // Stores the 'name' for display, can be manual entry too

  String? latitude, longitude, mapLink, mapLocation;
  final String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final String startTime = DateFormat('HH:mm:ss').format(DateTime.now());
  String? endTime;
  bool _isReminderSet = false;

  String? addressLine1, addressLine2, selectedEmirate, citytown;
  final String country = 'United Arab Emirates'; // Fixed value
  final String businessType = 'Company'; // Fixed value
  final String addressType = 'Billing'; // Fixed value

  String? contactedPersonName;
  String? customerEmail;
  String? businessEmail;
  String? phoneNo;
  DateTime? rescheduledDateTime;
  final String namingSeries = 'DV-.YY.-.';
  String? visitDiscussion;
  DateTime? opportunityExpectedClosing;
  String? opportunityDiscussion;

  List<String> accountManagerEmails = [];
  List<String> businessOwnerEmails = [];
  String? selectedAccountManager;
  String? selectedBusinessOwner;

  // Loading and Permission States
  bool _isInitialLoading = true; // Overall loading state
  bool _locationPermissionGranted = false;
  bool isLoading = false; // Added isLoading state for form submission

  // Text Editing Controllers
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _contactedPersonNameController =
      TextEditingController();
  final TextEditingController _customerEmailController =
      TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessEmailController =
      TextEditingController();
  final TextEditingController _rescheduledDateTimeController =
      TextEditingController();
  final TextEditingController _opportunityExpectedClosingController =
      TextEditingController();
  final TextEditingController _visitDiscussionController =
      TextEditingController();
  final TextEditingController _opportunityDiscussionController =
      TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _citytownController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(
    text: 'United Arab Emirates',
  );
  final TextEditingController _businessTypeController = TextEditingController(
    text: 'Company',
  );
  final TextEditingController _addressTypeController = TextEditingController(
    text: 'Billing',
  );

  final List<String> uaeEmirates = [
    'Abu Dhabi',
    'Dubai',
    'Sharjah',
    'Ajman',
    'Umm Al Quwain',
    'Ras Al Khaimah',
    'Fujairah',
  ];

  @override
  void initState() {
    super.initState();
    _userController.text = widget.email;
    selectedAccountManager = widget.email;
    selectedBusinessOwner = widget.email;
    _initializeScreen();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _contactedPersonNameController.dispose();
    _customerEmailController.dispose();
    _phoneNoController.dispose();
    _userController.dispose();
    _businessNameController.dispose();
    _businessEmailController.dispose();
    _rescheduledDateTimeController.dispose();
    _opportunityExpectedClosingController.dispose();
    _visitDiscussionController.dispose();
    _opportunityDiscussionController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _citytownController.dispose();
    _countryController.dispose();
    _businessTypeController.dispose();
    _addressTypeController.dispose();
    super.dispose();
  }

  // --- INITIALIZATION ---
  Future<void> _initializeScreen() async {
    setState(() => _isInitialLoading = true);
    await _notificationService.init();
    await _checkLocationPermissionAndFetch();
    // Fetch data in parallel
    await Future.wait([_fetchCustomers(), _fetchUsers(), _fetchBusinessList()]);
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  // --- DATA FETCHING ---
  /// Fetches user emails from the server to populate dropdowns for Account Manager and Business Owner.
  Future<void> _fetchUsers() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\",\"=\",1]]";
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Cookie': 'sid=${widget.sid}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        if (mounted) {
          setState(() {
            // Use a Set to ensure uniqueness of emails, then convert back to a list.
            final uniqueEmails = (data as List<dynamic>)
                .map((user) => user['email'].toString())
                .toSet() // Removes duplicates
                .toList();

            accountManagerEmails = uniqueEmails;
            businessOwnerEmails = uniqueEmails; // Assign the same unique list

            // Pre-select current user's email if available in the lists
            if (accountManagerEmails.contains(widget.email)) {
              selectedAccountManager = widget.email;
            }
            if (businessOwnerEmails.contains(widget.email)) {
              selectedBusinessOwner = widget.email;
            }
          });
        }
      } else {
        _showSnackBar(
          'Failed to load user data: ${response.reasonPhrase}',
          isSuccess: false,
        );
      }
    } catch (e) {
      _showSnackBar(
        _getFriendlyErrorMessage(e, context: 'fetching users'),
        isSuccess: false,
      );
      debugPrint('Error fetching users: $e');
    }
  }

  /// Fetches business list from the server to populate dropdown for New Visit.
  Future<void> _fetchBusinessList() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_business_list';
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': 'sid=${widget.sid}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] != null && data['message']['data'] != null) {
          setState(() {
            businesses =
                (data['message']['data'] as List<dynamic>?)?.toList() ?? [];
            filteredBusinesses = businesses; // Initialize filtered list
          });
        } else {
          _showSnackBar(
            'Failed to get business data: The server sent an invalid response.',
            isSuccess: false,
          );
        }
      } else {
        final errorMessage = _getFriendlyErrorMessage(
          response,
          context: 'fetching business list',
        );
        _showSnackBar(errorMessage, isSuccess: false);
      }
    } catch (e) {
      final errorMessage = _getFriendlyErrorMessage(
        e,
        context: 'fetching business list',
      );
      _showSnackBar(errorMessage, isSuccess: false);
      debugPrint('Exception during _fetchBusinessList: $e');
    }
  }

  /// Fetches customer data from the server.
  Future<void> _fetchCustomers() async {
    final url =
        '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.role_api.get_customers';
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': 'sid=${widget.sid}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] != null && data['message']['customers'] != null) {
          setState(() {
            customers = (data['message']['customers'] as List<dynamic>? ?? [])
                .map(
                  (c) => {
                    'name': c['name']?.toString() ?? '',
                    'customer_name':
                        c['customer_name']?.toString() ??
                        c['name']?.toString() ??
                        '',
                    'custom_latitude': c['custom_latitude']?.toString(),
                    'custom_longtitude': c['custom_longtitude']?.toString(),
                    'custom_customer_owner': c['custom_customer_owner']
                        ?.toString(),
                    'accounts_manager': c['accounts_manager']?.toString(),
                    'map_link': c['map_link']?.toString(),
                    'email_id': c['email_id']?.toString() ?? '',
                    'phone_no': c['phone_no']?.toString() ?? '',
                  },
                )
                .toList();
            filteredCustomers = customers; // Initialize filtered list
          });
        } else {
          _showSnackBar(
            'Failed to get customer data: The server sent an invalid response.',
            isSuccess: false,
          );
        }
      } else {
        final errorMessage = _getFriendlyErrorMessage(
          response,
          context: 'fetching customers',
        );
        _showSnackBar(errorMessage, isSuccess: false);
      }
    } catch (e) {
      final errorMessage = _getFriendlyErrorMessage(
        e,
        context: 'fetching customers',
      );
      _showSnackBar(errorMessage, isSuccess: false);
      debugPrint('Exception during _fetchCustomers: $e');
    }
  }

  // --- LOCATION HANDLING ---
  /// Checks location permissions and fetches current coordinates if granted.
  Future<void> _checkLocationPermissionAndFetch() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationPermissionGranted = false);
        }
        _showLocationPermissionDialog(
          'Location permission denied. Please enable location services in App settings.',
        );
        return;
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() => _locationPermissionGranted = false);
          }
          _showLocationPermissionDialog(
            'Location services are disabled. Please enable them in your device settings.',
          );
          return;
        }
        await _getCurrentCoordinates();
        if (mounted) {
          setState(() {
            _locationPermissionGranted = latitude != null && longitude != null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationPermissionGranted = false);
      }
      _showSnackBar(
        'Could not get your location. Please ensure GPS is on and permissions are granted.',
        isSuccess: false,
      );
      debugPrint('Error checking location permission: $e');
    }
  }

  /// Gets the current geographical coordinates (latitude and longitude).
  Future<void> _getCurrentCoordinates() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String mapUrl = _generateMapLink(
        position.latitude.toString(),
        position.longitude.toString(),
      );
      if (mounted) {
        setState(() {
          latitude = position.latitude.toString();
          longitude = position.longitude.toString();
          mapLink = mapUrl;
          _locationPermissionGranted = true;
        });
      }
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() {
          latitude = null;
          longitude = null;
          mapLink = null;
          _locationPermissionGranted = false;
        });
      }
      _showSnackBar(
        'Could not get location. Please check GPS and permissions.',
        isSuccess: false,
      );
    }
  }

  /// Converts geographical coordinates to a human-readable address.
  Future<void> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        final address = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        if (mounted) {
          setState(() {
            mapLocation = address;
          });
        }
      }
    } catch (e) {
      debugPrint("Error getting address from coordinates: $e");
      _showSnackBar(
        'Could not get the address for this location.',
        isSuccess: false,
      );
    }
  }

  /// Generates a Google Maps link from latitude and longitude.
  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  // --- FORM SUBMISSION ---
  /// Saves the visit data to the backend. If "New Opportunity" is selected,
  /// it then navigates to CreateOpportunityScreen with the saved visit ID.
  Future<void> _saveVisit() async {
    // *** MODIFICATION START: Validate form before proceeding ***
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields.', isSuccess: false);
      return;
    }
    // *** MODIFICATION END ***

    if (_selectedPrimaryVisitType == null) {
      _showSnackBar(
        'Please select either Customer Visit or Is New Visit.',
        isSuccess: false,
      );
      return;
    }

    if (!_locationPermissionGranted || latitude == null || longitude == null) {
      _showSnackBar(
        'Location coordinates are mandatory. Please enable location and try again.',
        isSuccess: false,
      );
      await _checkLocationPermissionAndFetch(); // Re-request location if not granted
      return;
    }

    setState(() {
      isLoading = true; // Set isLoading to true
      endTime = DateFormat('HH:mm:ss').format(DateTime.now());
    });

    Map<String, dynamic> data = {
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'user': _userController.text,
      'latitude': latitude,
      'longitude': longitude,
      'map_link': mapLink,
      'map_location': mapLocation, // Sent to backend
      'naming_series': namingSeries,
      'customer_visit': _selectedPrimaryVisitType == VisitType.customer ? 1 : 0,
      'is_new_visit': _selectedPrimaryVisitType == VisitType.isNewVisit ? 1 : 0,
      'follow_up': _selectedSecondaryVisitTypes.contains(VisitType.followUp)
          ? 1
          : 0,
      'new_opportunity':
          _selectedSecondaryVisitTypes.contains(VisitType.newOpportunity)
          ? 1
          : 0,
      'visit_discussion': _visitDiscussionController.text,
    };

    String? opportunityPartyName;
    String? opportunityFromType;

    if (_selectedPrimaryVisitType == VisitType.customer) {
      data.addAll({
        'customer': selectedCustomerDocName, // ERPNext Customer DocName
        'customer_name': customerDisplayName, // Display Name
        'contacted_person_name': _contactedPersonNameController.text,
        'email_id': _customerEmailController.text,
        'phone_no': _phoneNoController.text,
      });
      opportunityPartyName = customerDisplayName;
      opportunityFromType = 'Customer';
    } else if (_selectedPrimaryVisitType == VisitType.isNewVisit) {
      data.addAll({
        'business_name':
            businessDisplayName, // This can be selected or manually entered
        'address_line1': _addressLine1Controller.text,
        'address_line2': _addressLine2Controller.text,
        'emirates': selectedEmirate, // Sent to backend
        'citytown': _citytownController.text, // Sent to backend
        'country': _countryController.text,
        'contacted_person_name': _contactedPersonNameController.text,
        'business_email': _businessEmailController.text,
        'phone_no': _phoneNoController.text,
        'bussiness_type': _businessTypeController.text,
        'address_type': _addressTypeController.text,
        'accounts_manager': selectedAccountManager,
        'business_owner': selectedBusinessOwner,
      });
      opportunityPartyName = businessDisplayName;
      opportunityFromType = 'Business Name';
    }

    if (_selectedSecondaryVisitTypes.contains(VisitType.followUp) &&
        rescheduledDateTime != null) {
      data.addAll({
        'rescheduled_date_and_time': DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(rescheduledDateTime!),
      });
      if (_isReminderSet) {
        _notificationService.scheduleFollowUpNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: 'Follow-Up Reminder',
          body:
              'Time to follow up with ${customerDisplayName ?? businessDisplayName ?? 'your contact'}.',
          scheduledDateTime: rescheduledDateTime!,
        );
      }
    }

    // Add Opportunity details to the payload if the 'New Opportunity' checkbox is ticked.
    if (_selectedSecondaryVisitTypes.contains(VisitType.newOpportunity)) {
      data.addAll({
        'opportunity_expected_closing':
            _opportunityExpectedClosingController.text,
        'opportunity_discussion': _opportunityDiscussionController.text,
      });
    }

    // Remove null or empty string values from the map to avoid sending unnecessary data
    data.removeWhere(
      (key, value) => value == null || (value is String && value.isEmpty),
    );

    debugPrint('Sending Daily Visit payload: ${jsonEncode({'data': data})}');

    try {
      final response = await http
          .post(
            Uri.parse('${widget.serverUrl}/api/resource/Daily Visits'),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': 'sid=${widget.sid}',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedVisitData = json.decode(response.body)['data'];
        final String? visitId =
            savedVisitData['name']; // Get the saved visit ID

        _showSnackBar('Visit saved successfully!', isSuccess: true);

        // If New Opportunity is selected, navigate to CreateOpportunityScreen
        if (_selectedSecondaryVisitTypes.contains(VisitType.newOpportunity)) {
          // Navigate to CreateOpportunityScreen with the visitId
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateOpportunityScreen(
                serverUrl: widget.serverUrl,
                sid: widget.sid,
                email: widget.email,
                partyName: opportunityPartyName, // Pass the correct party name
                initialOpportunityDiscussion:
                    _opportunityDiscussionController.text,
                customVisitId: visitId, // Pass the saved visit ID
                opportunityOwner:
                    selectedAccountManager, // Pass Account Manager as Opportunity Owner
                opportunityFromType:
                    opportunityFromType, // Pass the determined opportunity from type
              ),
            ),
          ).then((result) {
            // Handle result from CreateOpportunityScreen if needed
            if (mounted) {
              setState(() {
                isLoading = false; // Reset loading state after returning
              });
            }
            if (result == true && mounted) {
              // If opportunity was successfully created, pop this screen too
              Navigator.pop(context);
            }
          });
        } else {
          // If no new opportunity, just pop the current screen
          if (mounted) Navigator.pop(context);
        }
      } else {
        final errorMessage = _getFriendlyErrorMessage(
          response,
          context: 'saving visit',
        );
        _showSnackBar(errorMessage, isSuccess: false);
        debugPrint(
          'Save visit failed: Status Code: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      final errorMessage = _getFriendlyErrorMessage(e, context: 'saving visit');
      _showSnackBar(errorMessage, isSuccess: false);
      debugPrint('Exception during saveVisit: $e');
    } finally {
      if (mounted) setState(() => isLoading = false); // Set isLoading to false
    }
  }

  // --- UI HELPERS & DIALOGS ---

  /// **[NEW/UPDATED]**
  /// Provides a user-friendly error message based on the type of error.
  /// Includes detailed explanations for common HTTP status codes.
  String _getFriendlyErrorMessage(
    dynamic error, {
    String context = 'an operation',
  }) {
    // 1. Handle network-related exceptions
    if (error is SocketException) {
      return 'No Internet Connection. Please check your network and try again.';
    }
    if (error is TimeoutException) {
      return 'The connection timed out while $context. Please try again.';
    }

    // 2. Handle HTTP response errors
    if (error is http.Response) {
      String serverMessage = '';
      // Try to parse a more specific message from the Frappe/ERPNext server response
      try {
        final errorBody = json.decode(error.body);
        if (errorBody['_server_messages'] != null) {
          final serverMessages = json.decode(errorBody['_server_messages']);
          if (serverMessages is List && serverMessages.isNotEmpty) {
            final messageData = json.decode(serverMessages[0]);
            serverMessage = messageData['message'] ?? '';
          }
        } else if (errorBody['exception'] != null) {
          serverMessage = errorBody['exception'];
        } else if (errorBody['message'] != null) {
          serverMessage = errorBody['message'];
        }
      } catch (e) {
        // If parsing fails, use the raw body if it's not too long or complex.
        if (error.body.isNotEmpty && error.body.length < 200) {
          serverMessage = error.body;
        }
        debugPrint("Could not parse server error message: $e");
      }

      String baseMessage;
      switch (error.statusCode) {
        case 400:
          baseMessage =
              "Bad Request: The server could not understand the request due to invalid syntax.";
          break;
        case 401:
          baseMessage =
              "Unauthorized: Your session may have expired. Please log in again.";
          break;
        case 403:
          baseMessage =
              "Forbidden: You do not have the necessary permissions to access this resource.";
          break;
        case 404:
          baseMessage =
              "Not Found: The requested resource could not be found on the server.";
          break;
        case 405:
          baseMessage =
              "Method Not Allowed: The request method is not supported for the requested resource.";
          break;
        case 409:
          baseMessage =
              "Conflict: The request could not be completed due to a conflict with the current state of the resource (e.g., duplicate data).";
          break;
        case 413:
          baseMessage =
              "Payload Too Large: The data you are trying to send is too large for the server to process.";
          break;
        case 415:
          baseMessage =
              "Unsupported Media Type: The format of the requested data is not supported by the server.";
          break;
        case 417:
          baseMessage =
              "Expectation Failed: The server cannot meet the requirements of the Expect request-header field.";
          break;
        case 422:
          baseMessage =
              "Unprocessable Entity: The request was well-formed but was unable to be followed due to semantic errors.";
          break;
        case 429:
          baseMessage =
              "Too Many Requests: You have sent too many requests in a given amount of time. Please wait a moment.";
          break;
        case 500:
          baseMessage =
              "Internal Server Error: A problem occurred on the server. Please contact support or try again later.";
          break;
        case 502:
          baseMessage =
              "Bad Gateway: The server, while acting as a gateway, received an invalid response from an upstream server.";
          break;
        case 503:
          baseMessage =
              "Service Unavailable: The server is currently unavailable (e.g., for maintenance or is overloaded). Please try again later.";
          break;
        case 504:
          baseMessage =
              "Gateway Timeout: The server, while acting as a gateway, did not get a response in time.";
          break;
        default:
          baseMessage =
              "An error occurred while communicating with the server (Code: ${error.statusCode}).";
      }

      // Combine the base message with the specific server message if available
      return serverMessage.isNotEmpty
          ? '$baseMessage\n\nServer Details: $serverMessage'
          : baseMessage;
    }

    // 3. Handle data format errors
    if (error is FormatException) {
      return 'Data Format Error: There was a problem processing the data received from the server.';
    }

    // 4. Fallback for any other unhandled errors
    return 'An unexpected error occurred while $context. Please try again.';
  }

  /// Shows a SnackBar message at the bottom of the screen.
  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return; // Ensure the widget is still mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(
          seconds: 5,
        ), // Increased duration for error messages
      ),
    );
  }

  /// Displays an AlertDialog to inform the user about location permission issues.
  void _showLocationPermissionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button to close
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_off,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Text('Location Required'),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open App Settings'),
              onPressed: () {
                // Corrected call to openAppSettings
                openAppSettings(); // Directly call the function from permission_handler
              },
            ),
          ],
        );
      },
    );
  }

  /// Resets form fields based on the selected primary visit type.
  void _resetFormFields({required VisitType newPrimaryType}) {
    setState(() {
      // Clear all common fields that might be populated by either type
      contactedPersonName = null;
      _contactedPersonNameController.clear();
      phoneNo = null;
      _phoneNoController.clear();
      visitDiscussion = null;
      _visitDiscussionController.clear();

      // Clear secondary visit type selections and their associated fields
      _selectedSecondaryVisitTypes.clear();
      rescheduledDateTime = null;
      _rescheduledDateTimeController.clear();
      _isReminderSet = false;
      opportunityExpectedClosing = null;
      _opportunityExpectedClosingController.clear();
      opportunityDiscussion = null;
      _opportunityDiscussionController.clear();

      if (newPrimaryType == VisitType.customer) {
        // Clear new visit specific fields
        selectedBusinessDocName = null;
        businessDisplayName = null;
        _businessNameController.clear();
        businessEmail = null;
        _businessEmailController.clear();
        addressLine1 = null;
        _addressLine1Controller.clear();
        addressLine2 = null;
        _addressLine2Controller.clear();
        citytown = null;
        _citytownController.clear();
        selectedEmirate = null;
        selectedAccountManager = widget.email; // Reset to current user
        selectedBusinessOwner = widget.email; // Reset to current user
      } else if (newPrimaryType == VisitType.isNewVisit) {
        // Clear customer specific fields
        selectedCustomerDocName = null;
        customerDisplayName = null;
        _customerController.clear();
        customerEmail = null;
        _customerEmailController.clear();
      }
    });
  }

  // --- WIDGET BUILDERS ---
  /// Builds a reusable card widget for different sections of the form.
  Widget _buildModuleCard({required String title, required Widget child}) {
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

  /// Builds a reusable text field widget with common styling and properties.
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    bool isRequired = false, // *** MODIFICATION: Added isRequired flag
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: suffixIcon,
      ),
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      // *** MODIFICATION: Added validator logic ***
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$labelText is required';
        }
        return null;
      },
      onTap: onTap,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  /// Builds a reusable dropdown field widget with common styling and properties.
  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    bool isRequired = false, // *** MODIFICATION: Added isRequired flag
  }) {
    // Defensive check: Ensure the value exists in the items list.
    // If not, set it to null to prevent the assertion error.
    final String? validValue = (value != null && items.contains(value))
        ? value
        : null;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: validValue, // Use the validated value
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      // *** MODIFICATION: Added validator logic ***
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$labelText is required';
        }
        return null;
      },
      isExpanded: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  // --- CUSTOM SEARCH DIALOGS ---
  /// Shows a dialog for searching and selecting a customer from the fetched list.
  Future<void> _showCustomerSearchDialog() async {
    // Reset filter when opening dialog
    setState(() {
      _customerController.clear();
      filteredCustomers = customers;
    });

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Select Customer'),
              contentPadding: const EdgeInsets.all(20.0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // Make it wider
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _customerController,
                      decoration: InputDecoration(
                        labelText: 'Search Customer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          filteredCustomers = customers
                              .where(
                                (c) => (c['name']?.toString() ?? '')
                                    .toLowerCase()
                                    .contains(value.toLowerCase()),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 300,
                      ), // Increased height for more visibility
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Text(
                                customer['name']?[0].toUpperCase() ??
                                    'C', // Display first letter of customer_name
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(customer['name']),
                            onTap: () {
                              Navigator.pop(
                                context,
                                customer,
                              ); // Pass selected customer back
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      _selectCustomer(selected);
    }
  }

  /// Handles the selection of a customer from the search dialog.
  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      selectedCustomerDocName = customer['name'];
      customerDisplayName = customer['customer_name'];
      _customerController.text = customer['customer_name'];
      contactedPersonName = customer['contacted_person_name'];
      _contactedPersonNameController.text = contactedPersonName ?? '';
      customerEmail = customer['email_id'];
      _customerEmailController.text = customerEmail ?? '';
      phoneNo = customer['phone_no'];
      _phoneNoController.text = phoneNo ?? '';

      latitude = customer['custom_latitude']?.toString();
      longitude = customer['custom_longtitude']?.toString();
      if (latitude != null && longitude != null) {
        mapLink = _generateMapLink(latitude!, longitude!);
        _getAddressFromCoordinates(
          double.parse(latitude!),
          double.parse(longitude!),
        );
      } else {
        mapLink = null;
        mapLocation = null;
      }
      // Trigger validation for the customer field after selection
      _formKey.currentState?.validate();
    });
  }

  /// Shows a dialog for searching and selecting a business from the fetched list, or allows manual entry.
  Future<void> _showBusinessSearchDialog() async {
    setState(() {
      _businessNameController.clear();
      filteredBusinesses = businesses;
    });

    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Select or Enter Business'),
              contentPadding: const EdgeInsets.all(20.0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // Make it wider
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText: 'Search or Enter New Business',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          filteredBusinesses = businesses
                              .where(
                                (b) => (b['name']?.toString() ?? '')
                                    .toLowerCase()
                                    .contains(value.toLowerCase()),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 300,
                      ), // Increased height for more visibility
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredBusinesses.length,
                        itemBuilder: (context, index) {
                          final business = filteredBusinesses[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Text(
                                business['name']?[0].toUpperCase() ?? 'B',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(business['name']),
                            subtitle: Text(business['business_owner'] ?? ''),
                            onTap: () {
                              Navigator.pop(
                                context,
                                business,
                              ); // Pass selected business back
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  child: const Text('Use This Name'),
                  onPressed: () {
                    // Use the manually typed name
                    Navigator.pop(context, {
                      'name': _businessNameController.text,
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      if (selected.containsKey('name') &&
          selected['name'] == _businessNameController.text) {
        // User manually entered a new business name
        setState(() {
          businessDisplayName = _businessNameController.text;
          selectedBusinessDocName = null; // No doc name for new entry
          // Clear other business-related fields as it's a new entry
          businessEmail = null;
          _businessEmailController.clear();
          phoneNo = null;
          _phoneNoController.clear();
          addressLine1 = null;
          _addressLine1Controller.clear();
          addressLine2 = null;
          _addressLine2Controller.clear();
          citytown = null;
          _citytownController.clear();
          selectedEmirate = null;
          selectedAccountManager = widget.email; // Default to current user
          selectedBusinessOwner = widget.email; // Default to current user
        });
      } else {
        // User selected an existing business
        _selectBusiness(selected);
      }
      // Trigger validation for the business field after selection
      _formKey.currentState?.validate();
    }
  }

  /// Handles the selection of a business from the search dialog.
  void _selectBusiness(Map<String, dynamic> business) {
    setState(() {
      selectedBusinessDocName = business['name'];
      businessDisplayName = business['name'];
      _businessNameController.text = business['name'] ?? '';

      businessEmail = business['email'] ?? '';
      _businessEmailController.text = businessEmail ?? '';
      phoneNo = business['phone_number'] ?? '';
      _phoneNoController.text = phoneNo ?? '';
      addressLine1 = business['address_line_1'] ?? '';
      _addressLine1Controller.text = addressLine1 ?? '';
      addressLine2 = business['address_line_2'] ?? '';
      _addressLine2Controller.text = addressLine2 ?? '';
      citytown = business['citytown'] ?? '';
      _citytownController.text = citytown ?? '';
      selectedEmirate = business['emirates'] ?? '';
      selectedAccountManager = business['accounts_manager'] ?? widget.email;
      selectedBusinessOwner = business['business_owner'] ?? widget.email;

      latitude = business['latitude']?.toString();
      longitude = business['longitude']?.toString();
      if (latitude != null && longitude != null) {
        mapLink = _generateMapLink(latitude!, longitude!);
        mapLocation = business['map_location'];
      } else {
        mapLink = null;
        mapLocation = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine if fields for 'New Visit' should be mandatory
    final bool isNewVisitMandatory =
        _selectedPrimaryVisitType == VisitType.isNewVisit;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Visit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
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
        child: _isInitialLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Getting Things Ready...',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModuleCard(
                        title: 'Select Primary Visit Type',
                        child: Column(
                          children: [
                            RadioListTile<VisitType>(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Customer Visit'),
                                ],
                              ),
                              value: VisitType.customer,
                              groupValue: _selectedPrimaryVisitType,
                              onChanged: (VisitType? value) {
                                setState(() {
                                  _selectedPrimaryVisitType = value;
                                  _resetFormFields(
                                    newPrimaryType: VisitType.customer,
                                  );
                                });
                              },
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            RadioListTile<VisitType>(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.add_business,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Is New Visit'),
                                ],
                              ),
                              value: VisitType.isNewVisit,
                              groupValue: _selectedPrimaryVisitType,
                              onChanged: (VisitType? value) {
                                setState(() {
                                  _selectedPrimaryVisitType = value;
                                  _resetFormFields(
                                    newPrimaryType: VisitType.isNewVisit,
                                  );
                                });
                              },
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModuleCard(
                        title: 'Basic Details',
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: TextEditingController(text: date),
                              labelText: 'Date',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: TextEditingController(
                                text: startTime,
                              ),
                              labelText: 'Start Time',
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _userController,
                              labelText: 'User',
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedPrimaryVisitType == VisitType.customer)
                        _buildModuleCard(
                          title: 'Customer Details',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _customerController,
                                labelText: 'Customer',
                                readOnly: true,
                                onTap: _showCustomerSearchDialog,
                                suffixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                isRequired: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _contactedPersonNameController,
                                labelText: 'Contacted Person Name',
                                onChanged: (value) =>
                                    contactedPersonName = value,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _customerEmailController,
                                labelText: 'Customer Email',
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (value) => customerEmail = value,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _phoneNoController,
                                labelText: 'Phone No',
                                keyboardType: TextInputType.phone,
                                onChanged: (value) => phoneNo = value,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _visitDiscussionController,
                                labelText: 'Visit Discussion',
                                maxLines: 8, // Increased maxLines
                                keyboardType: TextInputType.multiline,
                                onChanged: (value) => visitDiscussion = value,
                                isRequired: true,
                              ),
                            ],
                          ),
                        ),
                      if (_selectedPrimaryVisitType == VisitType.isNewVisit)
                        _buildModuleCard(
                          title: 'New Visit Details',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _businessNameController,
                                labelText: 'Business Name',
                                readOnly: true,
                                onTap: _showBusinessSearchDialog,
                                suffixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _businessTypeController,
                                labelText: 'Business Type',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                labelText: 'Address Type',
                                controller: _addressTypeController,
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _addressLine1Controller,
                                labelText: 'Address Line 1',
                                onChanged: (value) => addressLine1 = value,
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _addressLine2Controller,
                                labelText: 'Address Line 2 (Optional)',
                                onChanged: (value) => addressLine2 = value,
                                isRequired: false, // Not mandatory
                              ),
                              const SizedBox(height: 16),
                              _buildDropdownField(
                                labelText: 'Emirate',
                                value: selectedEmirate,
                                items: uaeEmirates,
                                onChanged: (value) {
                                  setState(() {
                                    selectedEmirate = value;
                                  });
                                },
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _citytownController,
                                labelText: 'City/Town',
                                onChanged: (value) => citytown = value,
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _countryController,
                                labelText: 'Country',
                                readOnly: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _businessEmailController,
                                labelText: 'Business Email',
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (value) => businessEmail = value,
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _contactedPersonNameController,
                                labelText: 'Contacted Person Name',
                                onChanged: (value) =>
                                    contactedPersonName = value,
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _phoneNoController,
                                labelText: 'Phone No',
                                keyboardType: TextInputType.phone,
                                onChanged: (value) => phoneNo = value,
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildDropdownField(
                                labelText: 'Account Manager',
                                value: selectedAccountManager,
                                items: accountManagerEmails,
                                onChanged: (value) {
                                  setState(() {
                                    selectedAccountManager = value;
                                  });
                                },
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildDropdownField(
                                labelText: 'Business Owner',
                                value: selectedBusinessOwner,
                                items: businessOwnerEmails,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBusinessOwner = value;
                                  });
                                },
                                isRequired: isNewVisitMandatory,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _visitDiscussionController,
                                labelText: 'Visit Discussion',
                                maxLines: 8, // Increased maxLines
                                keyboardType: TextInputType.multiline,
                                onChanged: (value) => visitDiscussion = value,
                                isRequired: isNewVisitMandatory,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildModuleCard(
                        title: 'Select Secondary Visit Type(s)',
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.next_plan,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Follow Up'),
                                ],
                              ),
                              value: _selectedSecondaryVisitTypes.contains(
                                VisitType.followUp,
                              ),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedSecondaryVisitTypes.add(
                                      VisitType.followUp,
                                    );
                                  } else {
                                    _selectedSecondaryVisitTypes.remove(
                                      VisitType.followUp,
                                    );
                                    _rescheduledDateTimeController.clear();
                                    rescheduledDateTime = null;
                                    _isReminderSet = false;
                                  }
                                });
                              },
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            CheckboxListTile(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('New Opportunity'),
                                ],
                              ),
                              value: _selectedSecondaryVisitTypes.contains(
                                VisitType.newOpportunity,
                              ),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedSecondaryVisitTypes.add(
                                      VisitType.newOpportunity,
                                    );
                                  } else {
                                    _selectedSecondaryVisitTypes.remove(
                                      VisitType.newOpportunity,
                                    );
                                    _opportunityExpectedClosingController
                                        .clear();
                                    opportunityExpectedClosing = null;
                                    _opportunityDiscussionController.clear();
                                    opportunityDiscussion = null;
                                  }
                                });
                              },
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedSecondaryVisitTypes.contains(
                        VisitType.followUp,
                      ))
                        _buildModuleCard(
                          title: 'Follow Up Details',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _rescheduledDateTimeController,
                                labelText: 'Rescheduled Date And Time',
                                readOnly: true,
                                onTap: () async {
                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        rescheduledDateTime ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2030),
                                  );
                                  if (pickedDate != null && mounted) {
                                    TimeOfDay? pickedTime =
                                        await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                    if (pickedTime != null) {
                                      setState(() {
                                        rescheduledDateTime = DateTime(
                                          pickedDate.year,
                                          pickedDate.month,
                                          pickedDate.day,
                                          pickedTime.hour,
                                          pickedTime.minute,
                                        );
                                        _rescheduledDateTimeController.text =
                                            DateFormat(
                                              'yyyy-MM-dd HH:mm:ss',
                                            ).format(rescheduledDateTime!);
                                      });
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Set Reminder'),
                                value: _isReminderSet,
                                onChanged: (bool value) {
                                  setState(() {
                                    _isReminderSet = value;
                                  });
                                },
                                secondary: Icon(
                                  _isReminderSet
                                      ? Icons.notifications_active
                                      : Icons.notifications_off,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      if (_selectedSecondaryVisitTypes.contains(
                        VisitType.newOpportunity,
                      ))
                        _buildModuleCard(
                          title:
                              'New Opportunity Details (Will be created on next screen)',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller:
                                    _opportunityExpectedClosingController,
                                labelText: 'Expected Opportunity Closing Date',
                                readOnly: true,
                                onTap: () async {
                                  DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        opportunityExpectedClosing ??
                                        DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      opportunityExpectedClosing = picked;
                                      _opportunityExpectedClosingController
                                          .text = DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(opportunityExpectedClosing!);
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _opportunityDiscussionController,
                                labelText: 'Opportunity Discussion',
                                maxLines: 8, // Increased maxLines
                                keyboardType: TextInputType.multiline,
                                onChanged: (value) =>
                                    opportunityDiscussion = value,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed:
                            isLoading || // Use the new isLoading state
                                !_locationPermissionGranted ||
                                _selectedPrimaryVisitType == null
                            ? null
                            : _saveVisit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 6,
                        ),
                        child:
                            isLoading // Use the new isLoading state
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _selectedSecondaryVisitTypes.contains(
                                      VisitType.newOpportunity,
                                    )
                                    ? 'Save Visit & Create Opportunity'
                                    : 'Save Visit',
                                style: const TextStyle(
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
    );
  }
}
