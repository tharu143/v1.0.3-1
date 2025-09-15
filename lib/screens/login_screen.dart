import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class CustomUpgraderMessages extends UpgraderMessages {
  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.body:
        return 'A new version is available! Please update to continue using the app.';
      case UpgraderMessage.buttonTitleUpdate:
        return 'Update Now';
      case UpgraderMessage.buttonTitleIgnore:
        return 'Ignore';
      case UpgraderMessage.buttonTitleLater:
        return 'Later';
      case UpgraderMessage.prompt:
        return 'Please update to the latest version for the best experience.';
      case UpgraderMessage.title:
        return 'Update Available';
      default:
        return super.message(messageKey);
    }
  }
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedProtocol = 'https://';
  bool _isLoading = false;
  String _appVersion = 'Loading...';
  bool _isPasswordVisible = false;
  late AnimationController _lockAnimationController;
  late Animation<double> _lockAnimation;
  final String _termsAndConditionsUrl =
      'https://www.kylesolutions.com/terms-conditions';
  final String _privacyPolicyText = """
Privacy Policy
This privacy policy applies to the Kyle Solutions app (hereby referred to as "Application") for mobile devices that was created by Kyle Solutions Private Limited (hereby referred to as "Service Provider") as a Commercial service. This service is intended for use "AS IS".
1. Information Collection and Use
The Application collects information for enabling features like Sales, HR, and Accounting, integrated with ERPNext. Information includes:
a. Automatically Collected Information
- Device IP address
- Device OS and model
- Date/time of app usage
- Screens visited and time spent
b. Location Data
We use location data for:
- Tagging deliveries, attendance, or service logs
- GPS-based automation within ERPNext
- Enhancing workflows like geofencing or territory-based filtering
Location data is collected via Google Location Services API and accessed through secure Flutter packages such as `geolocator` or `location`.
Data is stored only on the client's ERPNext server and is not sent to third-party servers.
c. Camera and Media Access
Used for:
- Capturing/uploading images
- Scanning QR/barcodes
- Uploading local files
Files are saved only in ERPNext.
d. Login Information
Users must log in using credentials tied to their ERPNext system. These are securely stored and used only to authenticate to the ERP server.
2. Data Storage
All collected data is stored strictly within the client's ERPNext server. No data is processed or retained by Kyle Solutions' servers.
3. App Permissions
- Location: Via Google APIs for geotagging
- Camera: To upload required documentation
- Storage: For file attachment
- Internet: For ERP server communication
- Notification: For business alerts
4. Third-Party Services
The app uses only essential third-Party services:
- Google Play Services
- Google Location Services API
These are used solely to provide reliable location tracking and app stability.
Google Privacy Policy: https://policies.google.com/privacy
5. Children's Privacy
This app is meant for enterprise use. We do not knowingly collect data from children under 13. Any such data discovered will be deleted immediately.
6. Data Retention and Deletion
Data is retained as long as the user's ERPNext account is active. To request deletion, contact your ERP administrator or email info@kylesolutions.com.
7. Security
- Encrypted HTTPS communication
- Secure session handling
- Role-based access controls
- No unnecessary data sharing
8. Changes to This Policy
We may update our Privacy Policy periodically. Continued app use confirms acceptance of updated terms.
9. Your Consent
By using this Application, you consent to this Privacy Policy and its terms regarding data usage.
10. Contact Us
Kyle Solutions Private Limited
Email: info@kylesolutions.com
Website: https://kylesolutions.com
""";

  @override
  void initState() {
    super.initState();
    _ipController.text = 'erp.printersbay.com';
    _initPackageInfo();
    _lockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _lockAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _lockAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initPackageInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      debugPrint('Error getting package info: $e');
      setState(() {
        _appVersion = 'Version unavailable';
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _lockAnimationController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Error',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
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

  Future<void> _handleLogin() async {
    if (_ipController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields.');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final String serverUrl = '$_selectedProtocol${_ipController.text}';
      final String apiUrl =
          '$serverUrl/api/method/saletracking.saletracking.salestracking_api.role_api.custom_login2';
      print('Sending request to: $apiUrl');
      print(
        'Request body: ${jsonEncode({'usr': _usernameController.text.trim(), 'pwd': _passwordController.text.trim()})}',
      );
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'usr': _usernameController.text.trim(),
              'pwd': _passwordController.text.trim(),
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your internet connection or server URL.',
              );
            },
          );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Parsed response: $responseData');
        // Handle specific backend error when "error": true is returned,
        // specifically for invalid username/password.
        if (responseData['error'] == true) {
          String displayMessage =
              'Login failed. An unknown error occurred.'; // Default message
          String? rawMessage = responseData['message']?.toString();
          if (rawMessage != null) {
            // Check if the raw string message from the backend contains the expected pattern
            // for an authentication error (e.g., "{'message': {...}, 'error': True}")
            if (rawMessage.contains("'error': True") &&
                rawMessage.contains("'message':") &&
                rawMessage.contains("{...")) {
              displayMessage =
                  'Login failed: Incorrect username or password. Please try again.';
            } else {
              // If it's a different error message, display that directly.
              displayMessage = rawMessage;
            }
          }
          _showErrorDialog(displayMessage);
          return;
        }
        String? sid = responseData['sid'];
        String? fullName = responseData['full_name'];
        String? email = responseData['email'];
        if (sid != null) {
          print('Login successful, navigating to dashboard');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Login successful! Welcome, ${fullName ?? _usernameController.text}',
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          Navigator.pushReplacementNamed(
            context,
            '/dashboard',
            arguments: {
              'serverUrl': serverUrl,
              'sid': sid,
              'fullName': fullName ?? _usernameController.text,
              'email': email,
            },
          );
        } else {
          _showErrorDialog(
            'Login failed. Session ID not found in the response.',
          );
        }
      } else {
        _showErrorDialog(
          'Server error: ${response.statusCode}. Please try again later.',
        );
      }
    } catch (e) {
      _showErrorDialog('An unexpected error occurred: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _showPrivacyPolicyDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Privacy Policy',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Text(
            _privacyPolicyText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(fontSize: 12, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldClose =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Close App',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Yes',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (shouldClose) {
      SystemNavigator.pop();
    }
    return shouldClose;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Theme.of(context).colorScheme.background,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    final upgrader = Upgrader(
      storeController: UpgraderStoreController(
        onAndroid: () => UpgraderPlayStore(),
      ),
      messages: CustomUpgraderMessages(),
      durationUntilAlertAgain: const Duration(days: 1),
    );
    return UpgradeAlert(
      upgrader: upgrader,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 32),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildLoginCard(),
                    const SizedBox(height: 24),
                    _buildFooterLinks(),
                    const SizedBox(height: 16),
                    _buildCompanyInfo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.business,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'KEPLER TECH LLC',
          style: Theme.of(context).textTheme.displayLarge!.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Empower Your Business Journey',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            Theme.of(context).colorScheme.secondary.withOpacity(0.3),
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServerUrlField(),
              const SizedBox(height: 16),
              _buildUsernameField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 24),
              _buildLoginButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server URL',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedProtocol = _selectedProtocol == 'https://'
                          ? 'http://'
                          : 'https://';
                      if (_selectedProtocol == 'https://') {
                        _lockAnimationController.forward();
                      } else {
                        _lockAnimationController.reverse();
                      }
                    });
                  },
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _lockAnimation,
                      builder: (context, child) => Icon(
                        _selectedProtocol == 'https://'
                            ? Icons.lock
                            : Icons.lock_open,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: LoginTextField(
                controller: _ipController,
                hintText: 'erp.printersbay.com',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Username',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LoginTextField(
          controller: _usernameController,
          hintText: 'Enter your username',
          prefixIcon: Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LoginTextField(
          controller: _passwordController,
          hintText: 'Enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: _isLoading ? 2 : 4,
        minimumSize: const Size(double.infinity, 56),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'SIGN IN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
    );
  }

  Widget _buildFooterLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => _launchUrl(_termsAndConditionsUrl),
          child: Text(
            'Terms & Conditions',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(width: 16),
        TextButton(
          onPressed: () => _showPrivacyPolicyDialog(context),
          child: Text(
            'Privacy Policy',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfo() {
    return Column(
      children: [
        Text(
          'Powered by Kyle Solutions Private Limited',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v$_appVersion',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData? prefixIcon; // Made prefixIcon nullable
  final String? hintText;
  final bool obscureText;
  final Widget? suffixIcon;

  const LoginTextField({
    Key? key,
    required this.controller,
    this.prefixIcon,
    this.hintText,
    this.obscureText = false,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              )
            : null,
        suffixIcon: suffixIcon,
        hintText: hintText,
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
      keyboardType: obscureText
          ? TextInputType.visiblePassword
          : TextInputType.text,
    );
  }
}
