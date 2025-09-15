import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/error_handler.dart';

class DashboardScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final String fullName;
  final String email;

  const DashboardScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.fullName,
    required this.email,
  }) : super(key: key);

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        final logoutUrl = '$serverUrl/api/method/logout';
        final response = await http.get(
          Uri.parse(logoutUrl),
          headers: {
            'Cookie': 'sid=$sid',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Logged out successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        } else if (context.mounted) {
          showApiErrorDialog(
            context,
            statusCode: response.statusCode,
            message: response.body,
          );
        }
      } catch (e) {
        if (context.mounted) {
          showApiErrorDialog(context, message: e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleLogout(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Dashboard',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => _handleLogout(context),
                tooltip: 'Logout',
              ),
            ),
          ],
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
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
                      Text(
                        'Welcome,',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                              fontSize: 20,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullName,
                        style: Theme.of(context).textTheme.displaySmall!
                            .copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                        textAlign: TextAlign.center,
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
                          Theme.of(context).colorScheme.secondary.withOpacity(
                                0.3,
                              ), // 0xFF005B99
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
                              title: 'Sales',
                              icon: Icons.store,
                              gradientColors: [
                                Theme.of(context).colorScheme.primary
                                    .withOpacity(0.7), // 0xFF0074c9
                                Theme.of(context).colorScheme.secondary
                                    .withOpacity(0.7), // 0xFF005B99
                              ],
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/sales',
                                  arguments: {
                                    'serverUrl': serverUrl,
                                    'sid': sid,
                                    'email': email,
                                  },
                                );
                              },
                            ),
                            DashboardCard(
                              title: 'CRM',
                              icon: Icons.connect_without_contact,
                              gradientColors: [
                                Theme.of(context).colorScheme.secondary
                                    .withOpacity(0.7), // 0xFF005B99
                                Theme.of(context).colorScheme.primary
                                    .withOpacity(0.7), // 0xFF0074c9
                              ],
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/crm',
                                  arguments: {
                                    'serverUrl': serverUrl,
                                    'sid': sid,
                                    'email': email,
                                  },
                                );
                              },
                            ),
                            DashboardCard(
                              title: 'Accounting',
                              icon: Icons.account_balance,
                              gradientColors: [
                                Theme.of(context).colorScheme.primary
                                    .withOpacity(0.7), // 0xFF0074c9
                                Theme.of(context).colorScheme.tertiary
                                    .withOpacity(0.7), // 0xFF14B8A6
                              ],
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/accounting',
                                  arguments: {
                                    'serverUrl': serverUrl,
                                    'sid': sid,
                                  },
                                );
                              },
                            ),
                            DashboardCard(
                              title: 'HR',
                              icon: Icons.person,
                              gradientColors: [
                                Theme.of(context).colorScheme.tertiary
                                    .withOpacity(0.7), // 0xFF14B8A6
                                Theme.of(context).colorScheme.secondary
                                    .withOpacity(0.7), // 0xFF005B99
                              ],
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/hr',
                                  arguments: {
                                    'serverUrl': serverUrl,
                                    'sid': sid,
                                    'email': email,
                                  },
                                );
                              },
                            ),
                            // --- New Card for Reports ---
                            DashboardCard(
                              title: 'Reports',
                              icon: Icons.analytics,
                              gradientColors: [
                                Colors.orange.withOpacity(0.7),
                                Colors.deepOrange.withOpacity(0.7),
                              ],
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reports',
                                  arguments: {
                                    'serverUrl': serverUrl,
                                    'sid': sid,
                                    'email': email,
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
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const DashboardCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Icon(
                      icon,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
