import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // Reusing DashboardCard
import 'sales_dashboard_screen.dart';

class SalesScreen extends StatelessWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const SalesScreen({
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
          'Sales Dashboard',
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
                  'Sales Hub',
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
                            title: 'Customers',
                            icon: Icons.people,
                            gradientColors: [
                              Theme.of(context).colorScheme.primary.withOpacity(
                                    0.7,
                                  ), // 0xFF0074c9
                              Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.7), // 0xFF005B99
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/customerList',
                                arguments: {
                                  'serverUrl': serverUrl,
                                  'sid': sid,
                                  'email': email,
                                },
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Sales Order',
                            icon: Icons.shopping_cart,
                            gradientColors: [
                              Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.7), // 0xFF005B99
                              Theme.of(context).colorScheme.primary.withOpacity(
                                    0.7,
                                  ), // 0xFF0074c9
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/sales_order',
                                arguments: {'serverUrl': serverUrl, 'sid': sid},
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Sales Invoice',
                            icon: Icons.receipt,
                            gradientColors: [
                              Theme.of(context).colorScheme.primary.withOpacity(
                                    0.7,
                                  ), // 0xFF0074c9
                              Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withOpacity(0.7), // 0xFF14B8A6
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/sales_invoice',
                                arguments: {'serverUrl': serverUrl, 'sid': sid},
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Delivery Note',
                            icon: Icons.local_shipping,
                            gradientColors: [
                              Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withOpacity(0.7), // 0xFF14B8A6
                              Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.7), // 0xFF005B99
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/delivery_note',
                                arguments: {'serverUrl': serverUrl, 'sid': sid},
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Daily Visit',
                            icon: Icons.event,
                            gradientColors: [
                              Theme.of(context).colorScheme.primary.withOpacity(
                                    0.7,
                                  ), // 0xFF0074c9
                              Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.7), // 0xFF005B99
                            ],
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/daily_visit',
                                arguments: {
                                  'serverUrl': serverUrl,
                                  'sid': sid,
                                  'email': email,
                                },
                              );
                            },
                          ),
                           DashboardCard(
                            title: 'Analytics',
                            icon: Icons.bar_chart,
                            gradientColors: [
                               Colors.orange.withOpacity(0.7),
                               Colors.deepOrange.withOpacity(0.7),
                            ],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SalesDashboardScreen(
                                    serverUrl: serverUrl,
                                    sid: sid,
                                  ),
                                ),
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
