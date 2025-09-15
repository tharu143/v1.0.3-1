import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // Reusing DashboardCard

class CrmScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const CrmScreen({
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
          'CRM Dashboard',
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
                child: Text(
                  'CRM Hub',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
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
                            title: 'Lead',
                            icon: Icons.person_search,
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
                                '/leadList',
                                arguments: {
                                  'serverUrl': serverUrl,
                                  'sid': sid,
                                  'email': email,
                                },
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Opportunity',
                            icon: Icons.lightbulb,
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
                                '/opportunityList',
                                arguments: {
                                  'serverUrl': serverUrl,
                                  'sid': sid,
                                  'email': email,
                                },
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Quotation',
                            icon: Icons.request_quote,
                            gradientColors: [
                              Theme.of(context).colorScheme.primary.withOpacity(
                                0.7,
                              ), // 0xFF0074c9
                              Theme.of(context).colorScheme.tertiary
                                  .withOpacity(0.7), // 0xFF14B8A6
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/quotationList',
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
    );
  }
}
