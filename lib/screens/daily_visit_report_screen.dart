import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class DailyVisitReportScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const DailyVisitReportScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _DailyVisitReportScreenState createState() => _DailyVisitReportScreenState();
}

class _DailyVisitReportScreenState extends State<DailyVisitReportScreen> {
  bool _isLoading = true;
  List<dynamic> _reportData = [];
  List<dynamic> _dayVisits = [];
  String? _error;

  // Filter and Search state
  DateTime? _selectedDate;
  bool _isAdmin = false;
  List<Map<String, String>> _usersList = [];
  String? _selectedUser;

  // Map State
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  double _totalDistance = 0.0;

  // Summary Stats
  int _customerVisitsToday = 0;
  int _newBusinessVisitsToday = 0;

   // Pre-defined light colors for markers
  final List<double> _markerHues = [
    BitmapDescriptor.hueAzure,
    BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueOrange,
    BitmapDescriptor.hueRose,
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueMagenta,
    BitmapDescriptor.hueYellow,
  ];


  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkUserRole();
    if (_isAdmin) {
      await _fetchUsersList();
    }
    await _fetchReport();
  }
  
  Future<void> _checkUserRole() async {
    // This logic remains the same
    try {
      final url = Uri.parse(
          '${widget.serverUrl}/api/method/frappe.auth.get_logged_user_roles');
      final response =
          await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (response.statusCode == 200) {
        final roles =
            List<String>.from(json.decode(response.body)['message']);
        if (mounted) {
          setState(() {
            _isAdmin = roles.contains('System Manager');
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  Future<void> _fetchUsersList() async {
     // This logic remains the same
    try {
      final url = Uri.parse(
          '${widget.serverUrl}/api/resource/User?fields=["email","full_name"]&limit_page_length=0');
      final response =
          await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        if (mounted) {
          setState(() {
            _usersList = data
                .map((user) => {
                      'email': user['email'].toString(),
                      'full_name': user['full_name'].toString(),
                    })
                .toList();
          });
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _fetchReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.visit_report.get_daily_visits_report');
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reportData = json.decode(response.body)['message'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load report');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAndProcessVisits() {
    if (_selectedDate == null) return;

    List<dynamic> data = List.from(_reportData);

    // Filter by selected date
    data = data.where((item) {
      final itemDate = DateTime.parse(item['date']);
      return itemDate.year == _selectedDate!.year &&
             itemDate.month == _selectedDate!.month &&
             itemDate.day == _selectedDate!.day;
    }).toList();

    // Filter by user if admin
    if (_isAdmin && _selectedUser != null && _selectedUser!.isNotEmpty) {
      data = data.where((item) {
        return item['user'].toLowerCase() == _selectedUser!.toLowerCase();
      }).toList();
    }

    // Sort by start time
    data.sort((a, b) => a['start_time'].compareTo(b['start_time']));
    
    setState(() {
      _dayVisits = data;
      _calculateSummaryStats();
    });

    _createMapMarkersAndPolylines();
  }

  void _calculateSummaryStats() {
    _customerVisitsToday = _dayVisits.where((v) => v['customer'] != null && v['customer'].isNotEmpty).length;
    _newBusinessVisitsToday = _dayVisits.where((v) => (v['customer'] == null || v['customer'].isEmpty) && (v['business_name'] != null && v['business_name'].isNotEmpty)).length;
  }
  
  void _createMapMarkersAndPolylines() {
    _markers.clear();
    _polylines.clear();
    _totalDistance = 0;
    
    List<LatLng> routePoints = [];
    double calculatedTotalDistance = 0.0;

    for (int i = 0; i < _dayVisits.length; i++) {
      final visit = _dayVisits[i];
      final latLng = _parseLatLng(visit['map_link']);
      if (latLng != null) {
        routePoints.add(latLng);

        final duration = _calculateDuration(visit['start_time'], visit['end_time']);
        final customerInfo = visit['customer'] ?? visit['business_name'] ?? 'Visit';

        BitmapDescriptor markerColor;
        if (i == 0) markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        else if (i == _dayVisits.length - 1) markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        else markerColor = BitmapDescriptor.defaultMarkerWithHue(_markerHues[i % _markerHues.length]);

        _markers.add(Marker(
          markerId: MarkerId(visit['name']),
          position: latLng,
          infoWindow: InfoWindow(title: '${i + 1}. $customerInfo', snippet: 'Duration: $duration'),
          icon: markerColor,
        ));
      }
    }

    for (int i = 0; i < routePoints.length - 1; i++) {
      LatLng start = routePoints[i];
      LatLng end = routePoints[i + 1];
      _polylines.add(Polyline(
        polylineId: PolylineId('route_segment_$i'),
        points: [start, end],
        color: _markerHues[(i + 1) % _markerHues.length].toColor(),
        width: 5,
      ));
      calculatedTotalDistance += _calculateDistance(start, end);
    }
    
    setState(() {
      _totalDistance = calculatedTotalDistance;
    });

    if (_mapController != null && routePoints.isNotEmpty) {
      LatLngBounds bounds = _getBounds(_markers);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      _filterAndProcessVisits();
    }
  }

  void _onUserChanged(String? value) {
    setState(() {
      _selectedUser = value;
    });
    _filterAndProcessVisits();
  }

  void _navigateToDetailView(Map<String, dynamic> visitData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyVisitDetailScreen(
          serverUrl: widget.serverUrl,
          sid: widget.sid,
          visitData: visitData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: const Text('Daily Visit Route')),
      body: Column(
        children: [
          _buildControlsCard(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Visit Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_selectedDate == null
                      ? 'Select a Date'
                      : DateFormat('dd-MM-yyyy').format(_selectedDate!)),
                ),
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUser,
                  hint: const Text('All Users'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All Users')),
                    ..._usersList.map((user) => DropdownMenuItem(
                        value: user['email'], child: Text(user['full_name']!)))
                  ],
                  onChanged: _onUserChanged,
                  decoration: InputDecoration(
                    labelText: 'User',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedDate == null) {
      return const Center(child: Text("Please select a date to view the route."));
    }
     if (_dayVisits.isEmpty) {
      return const Center(child: Text("No visits found for the selected date/user."));
    }
    return Column(
      children: [
        _buildMapSummaryCard(),
        SizedBox(
          height: 300,
          child: _buildMap(),
        ),
        Expanded(
          child: _buildTimelineList(),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final initialPos = _markers.isNotEmpty ? _markers.first.position : const LatLng(25.2048, 55.2708); // Default to Dubai
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(target: initialPos, zoom: 12.0),
      markers: _markers,
      polylines: _polylines,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
    );
  }

  Widget _buildMapSummaryCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: [
            _buildSummaryItem(context, "Total Stops", _dayVisits.length.toString(), Icons.location_on),
            _buildSummaryItem(context, "Customers", _customerVisitsToday.toString(), Icons.person_search),
            _buildSummaryItem(context, "New Business", _newBusinessVisitsToday.toString(), Icons.add_business),
            _buildSummaryItem(context, "Distance", "${_totalDistance.toStringAsFixed(1)} km", Icons.route),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem(BuildContext context, String title, String value, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center,),
        ),
      ],
    );
  }

  Widget _buildTimelineList() {
     return ListView.builder(
      itemCount: _dayVisits.length,
      itemBuilder: (context, index) {
        final visit = _dayVisits[index];
        final customerInfo = visit['customer'] ?? visit['business_name'] ?? 'N/A';
        final visitDuration = _calculateDuration(visit['start_time'], visit['end_time']);
        final latLng = _parseLatLng(visit['map_link']);

        String travelInfo = "";
        if (index > 0) {
          final prevVisit = _dayVisits[index - 1];
          final prevLatLng = _parseLatLng(prevVisit['map_link']);
          final travelTime = _calculateTravelTime(prevVisit['end_time'], visit['start_time']);
          if (prevLatLng != null && latLng != null) {
            final distance = _calculateDistance(prevLatLng, latLng);
            travelInfo = "Travel: $travelTime (${distance.toStringAsFixed(2)} km)";
          } else {
            travelInfo = "Travel: $travelTime";
          }
        }

        Color itemColor;
        if (index == 0) itemColor = Colors.green;
        else if (index == _dayVisits.length - 1) itemColor = Colors.red;
        else itemColor = _markerHues[index % _markerHues.length].toColor();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: GestureDetector(
              onTap: latLng == null ? null : () => _goToMarker(latLng, visit['name']),
              child: CircleAvatar(
                backgroundColor: itemColor,
                child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text(customerInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visit: ${visit['start_time']} - ${visit['end_time']} (Duration: $visitDuration)'),
                if (travelInfo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(travelInfo, style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontStyle: FontStyle.italic)),
                  )
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _navigateToDetailView(visit)
          ),
        );
      },
    );
  }

  // Helper methods from previous versions (_parseLatLng, durations, distance, etc.)
  LatLng? _parseLatLng(String? mapLink) {
    if (mapLink == null || !mapLink.contains('query=')) return null;
    try {
      final uri = Uri.parse(mapLink);
      final query = uri.queryParameters['query'];
      if (query != null) {
        final parts = query.split(',');
        if (parts.length == 2) {
          return LatLng(double.parse(parts[0]), double.parse(parts[1]));
        }
      }
    } catch (e) { print("Error parsing LatLng: $e"); }
    return null;
  }

  String _calculateDuration(String startTimeStr, String endTimeStr) {
    try {
      final timeFormat = DateFormat("HH:mm:ss");
      final startTime = timeFormat.parse(startTimeStr);
      final endTime = timeFormat.parse(endTimeStr);
      final duration = endTime.difference(startTime);
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      final hours = twoDigits(duration.inHours);
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$hours:$minutes:$seconds";
    } catch (e) { return "N/A"; }
  }

  String _calculateTravelTime(String prevEndTimeStr, String currentStartTimeStr) {
     try {
      final timeFormat = DateFormat("HH:mm:ss");
      final prevEndTime = timeFormat.parse(prevEndTimeStr);
      final currentStartTime = timeFormat.parse(currentStartTimeStr);
      final duration = currentStartTime.difference(prevEndTime);
      if (duration.isNegative) return "N/A";
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      final hours = twoDigits(duration.inHours);
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$hours:$minutes:$seconds";
    } catch (e) { return "N/A"; }
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((pos2.latitude - pos1.latitude) * p) / 2 + cos(pos1.latitude * p) * cos(pos2.latitude * p) * (1 - cos((pos2.longitude - pos1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
   LatLngBounds _getBounds(Set<Marker> markers) {
    var lats = markers.map((m) => m.position.latitude);
    var lngs = markers.map((m) => m.position.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
  }

  void _goToMarker(LatLng position, String markerId) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16.0));
    _mapController?.showMarkerInfoWindow(MarkerId(markerId));
  }
}

// --- DETAIL SCREEN WIDGET (Remains the same) ---

class DailyVisitDetailScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final Map<String, dynamic> visitData;

  const DailyVisitDetailScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.visitData,
  }) : super(key: key);

  Future<void> _launchUrl(String? url, BuildContext context) async {
    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch map')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(visitData['name'] ?? 'Visit Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailCard(
              context,
              'Visit Information',
              [
                _buildDetailRow(
                    context, Icons.person_outline, 'User', visitData['user']),
                _buildDetailRow(
                    context, Icons.date_range, 'Date', visitData['date']),
                _buildDetailRow(context, Icons.timer_outlined, 'Start Time',
                    visitData['start_time']),
                _buildDetailRow(
                    context, Icons.timer, 'End Time', visitData['end_time']),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Customer Details',
              [
                _buildDetailRow(
                    context, Icons.business, 'Customer', visitData['customer']),
                _buildDetailRow(context, Icons.store, 'Business Name',
                    visitData['business_name']),
                _buildDetailRow(context, Icons.badge_outlined, 'Contact Person',
                    visitData['contacted_person_name']),
                _buildDetailRow(context, Icons.phone, 'Phone Number',
                    visitData['phone_no']),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Location Details',
              [
                _buildDetailRow(context, Icons.location_on_outlined,
                    'Location', visitData['map_location']),
                const SizedBox(height: 16),
                if (visitData['map_link'] != null)
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View on Map'),
                      onPressed: () =>
                          _launchUrl(visitData['map_link'], context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
      BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, dynamic value) {
    final stringValue = value?.toString();
    if (stringValue == null || stringValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  stringValue,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// Helper extension to convert hue to a color for the list item
extension HueToColor on double {
  Color toColor() {
    return HSLColor.fromAHSL(1.0, this, 1.0, 0.5).toColor();
  }
}

