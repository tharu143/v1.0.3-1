import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/error_handler.dart';

class CreateLeadScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const CreateLeadScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _CreateLeadScreenState createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  // Form controllers for the create view
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _dateController = TextEditingController();
  String? _status;
  String? _territory;
  String? _industry;
  List<Map<String, dynamic>> _sitePhotos = [];
  bool _isSaving = false;
  List<String> _territories = [];

  final List<String> _statusOptions = [
    'Lead',
    'Open',
    'Replied',
    'Opportunity',
    'Quotation',
    'Lost Quotation',
    'Interested',
    'Converted',
    'Do Not Contact',
  ];
  final List<String> _industries = [
    'Accounting',
    'Advertising',
    'Aerospace',
    'Agriculture',
    'Airline',
    'Apparel & Accessories',
    'Automotive',
    'Banking',
    'Biotechnology',
    'Broadcasting',
    'Brokerage',
    'Chemical',
    'Computer',
    'Construction',
    'Consulting',
    'Consumer Products',
    'Cosmetics',
    'Defense',
    'Department Stores',
    'Education',
    'Electronics',
    'Energy',
    'Entertainment & Leisure',
    'Executive Search',
    'Service',
    'Soap & Detergent',
    'Software',
    'Sports',
    'Studio & Store',
    'Technology',
    'Telecommunications',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCreateFormData();
  }

  void _initializeCreateFormData() {
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
    _status = 'Lead';
    _industry = _industries.isNotEmpty ? _industries.first : null;
    _fetchTerritories();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _companyNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Lead',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'First Name',
                    _firstNameController,
                    Icons.person,
                    validator: (value) =>
                        value!.isEmpty ? 'First name is required' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'Email',
                    _emailController,
                    Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'Phone Number',
                    _phoneController,
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Phone number is required' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'WhatsApp Number',
                    _whatsappController,
                    Icons.message,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'WhatsApp number is required' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'Organization Name',
                    _companyNameController,
                    Icons.business,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDropdownField(
                    'Industry',
                    _industry,
                    _industries,
                    (value) => setState(() => _industry = value),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDropdownField(
                    'Territory',
                    _territory,
                    _territories,
                    (value) => setState(() => _territory = value),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'Address',
                    _addressController,
                    Icons.location_on,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'City',
                    _cityController,
                    Icons.location_city,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField('State', _stateController, Icons.map),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'Country',
                    _countryController,
                    Icons.flag,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCreateTextField(
                    'Date',
                    _dateController,
                    Icons.calendar_today,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (value) =>
                        value!.isEmpty ? 'Date is required' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDropdownField(
                    'Status',
                    _status,
                    _statusOptions,
                    (value) => setState(() => _status = value),
                    validator: (value) =>
                        value == null ? 'Please select a status' : null,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: const Text(
                      'Add Site Photos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: _buttonStyle(context),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildPhotoGrid(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _handleSave(createOpportunity: false),
                          style: _buttonStyle(context, isPrimary: false),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _handleSave(createOpportunity: true),
                          style: _buttonStyle(context, isPrimary: true),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Save & Create Opp.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(BuildContext context, {bool isPrimary = true}) {
    return ElevatedButton.styleFrom(
      minimumSize: Size(
        double.infinity,
        MediaQuery.of(context).size.height * 0.07,
      ),
      backgroundColor: isPrimary
          ? Theme.of(context).colorScheme.secondary
          : Colors.white,
      foregroundColor: isPrimary
          ? Colors.white
          : Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
    );
  }

  Widget _buildPhotoGrid() {
    if (_sitePhotos.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sitePhotos.map((photo) {
        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      photo['file'] as File,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (photo['latitude'] != null && photo['longitude'] != null)
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        'Lat: ${photo['latitude']?.toStringAsFixed(4)}, Lon: ${photo['longitude']?.toStringAsFixed(4)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall!.copyWith(fontSize: 10),
                      ),
                    ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => setState(() => _sitePhotos.remove(photo)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreateTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              hintText: 'Enter $label',
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            style: const TextStyle(fontSize: 16),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 16)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(
                label == 'Territory'
                    ? Icons.map
                    : label == 'Industry'
                    ? Icons.category
                    : Icons.info,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            validator: validator,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchTerritories() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.serverUrl}/api/resource/Territory?fields=["name"]&limit_page_length=0',
        ),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _territories = data
                .map((territory) => territory['name'] as String)
                .toList();
            if (_territories.isNotEmpty) {
              _territory = _territories.first;
            }
          });
        }
      } else {
        if (mounted)
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      Position? position = await _getCurrentLocation();
      setState(() {
        _sitePhotos.addAll(
          pickedFiles.map(
            (file) => {
              'file': File(file.path),
              'latitude': position?.latitude,
              'longitude': position?.longitude,
            },
          ),
        );
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted)
          showApiErrorDialog(
            context,
            message: 'Please enable location services',
          );
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          if (mounted)
            showApiErrorDialog(context, message: 'Location permissions denied');
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
      return null;
    }
  }

  Future<List<String>> _uploadPhotos(String leadName) async {
    List<String> attachmentUrls = [];
    for (var photo in _sitePhotos) {
      final file = photo['file'] as File;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${widget.serverUrl}/api/method/upload_file'),
      );
      request.headers['Cookie'] = 'sid=${widget.sid}';
      request.fields['doctype'] = 'Lead';
      request.fields['docname'] = leadName;
      request.fields['is_private'] = '0';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        if (jsonResponse['message'] != null) {
          attachmentUrls.add(jsonResponse['message']['file_url']);
        }
      } else {
        throw Exception('Failed to upload photo: ${response.reasonPhrase}');
      }
    }
    return attachmentUrls;
  }

  Future<Map<String, dynamic>?> _saveLead() async {
    if (!_formKey.currentState!.validate()) return null;

    setState(() => _isSaving = true);

    final leadData = {
      'naming_series': 'LEAD-.YYYY.-',
      'lead_name': _firstNameController.text,
      'email_id': _emailController.text.isEmpty ? null : _emailController.text,
      'mobile_no': _phoneController.text,
      'phone': _phoneController.text,
      'custom_whatsapp_number': _whatsappController.text,
      'company_name': _companyNameController.text.isEmpty
          ? null
          : _companyNameController.text,
      'industry': _industry,
      'territory': _territory,
      'address_line1': _addressController.text.isEmpty
          ? null
          : _addressController.text,
      'city': _cityController.text.isEmpty ? null : _cityController.text,
      'state': _stateController.text.isEmpty ? null : _stateController.text,
      'country': _countryController.text.isEmpty
          ? null
          : _countryController.text,
      'custom_date': _dateController.text,
      'status': _status,
      'custom_latitude': _sitePhotos.isNotEmpty
          ? _sitePhotos.first['latitude']?.toString()
          : null,
      'custom_longitude': _sitePhotos.isNotEmpty
          ? _sitePhotos.first['longitude']?.toString()
          : null,
    };

    try {
      // First, create the lead document
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/resource/Lead'),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"data": leadData}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body)['data'];
        final leadName = responseData['name'];

        // If there are photos, upload them
        if (_sitePhotos.isNotEmpty) {
          await _uploadPhotos(leadName);
        }

        return responseData; // Return the created lead data
      } else {
        if (mounted)
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
        return null;
      }
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
      return null;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleSave({required bool createOpportunity}) async {
    final createdLead = await _saveLead();

    if (createdLead != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Lead saved successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );

        if (createOpportunity) {
          // Navigate to create opportunity screen
          Navigator.pushNamed(
            context,
            '/createOpportunityFromLead',
            arguments: {
              'serverUrl': widget.serverUrl,
              'sid': widget.sid,
              'email': widget.email,
              'leadId': createdLead['name'],
              'partyName': createdLead['lead_name'],
              'opportunityOwner': widget.email,
            },
          );
        } else {
          // Just pop back to the list, indicating success
          Navigator.pop(context, true);
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(
        () => _dateController.text = picked.toIso8601String().split('T')[0],
      );
    }
  }
}
