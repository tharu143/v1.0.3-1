import 'package:flutter/material.dart';
import 'package:kepler_tech_app/screens/dashboard_screen.dart'; // Reusing the DashboardCard

class ReportsScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const ReportsScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Reports',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              DashboardCard(
                title: 'Daily Visit Report',
                icon: Icons.description,
                gradientColors: [
                  Colors.teal.withOpacity(0.7),
                  Colors.green.withOpacity(0.7),
                ],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/dailyVisitReport',
                    arguments: {
                      'serverUrl': serverUrl,
                      'sid': sid,
                      'email': email,
                    },
                  );
                },
              ),
              // --- New Card for General Ledger Report ---
              DashboardCard(
                title: 'General Ledger Report',
                icon: Icons.book,
                gradientColors: [
                  Colors.blue.withOpacity(0.7),
                  Colors.indigo.withOpacity(0.7),
                ],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/generalLedgerReport',
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
    );
  }
}
