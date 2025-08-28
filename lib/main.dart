import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kepler_tech_app/screens/login_screen.dart';
import 'package:kepler_tech_app/screens/dashboard_screen.dart';
import 'package:kepler_tech_app/screens/customer_list_screen.dart';
import 'package:kepler_tech_app/screens/customer_detail_screen.dart';
import 'package:kepler_tech_app/screens/add_new_customer_screen.dart';
import 'package:kepler_tech_app/screens/sales_invoice_screen.dart';
import 'package:kepler_tech_app/screens/sales_order_screen.dart';
import 'package:kepler_tech_app/screens/sales_screen.dart';
import 'package:kepler_tech_app/screens/delivery_note_screen.dart';
import 'package:kepler_tech_app/screens/delivery_note_detail_screen.dart';
import 'package:kepler_tech_app/screens/delivery_note_list_screen.dart';
import 'package:kepler_tech_app/screens/delivered_detail_screen.dart';
import 'package:kepler_tech_app/screens/completed_delivery_detail_screen.dart';
import 'package:kepler_tech_app/screens/create_sales_order_screen.dart';
import 'package:kepler_tech_app/screens/hr_screen.dart';
import 'package:kepler_tech_app/screens/leave_application_list_screen.dart';
import 'package:kepler_tech_app/screens/employee_list_screen.dart';
import 'package:kepler_tech_app/screens/attendance_list_screen.dart';
import 'package:kepler_tech_app/screens/attendance_details_screen.dart';
import 'package:kepler_tech_app/screens/accounting_screen.dart';
import 'package:kepler_tech_app/screens/payment_entry_list_screen.dart';
import 'package:kepler_tech_app/screens/payment_entry_create_screen.dart';
import 'package:kepler_tech_app/screens/payment_entry_detail_screen.dart';
import 'package:kepler_tech_app/screens/sales_invoice_detail_screen.dart';
import 'package:kepler_tech_app/screens/daily_visit_screen.dart';
import 'package:kepler_tech_app/screens/create_opportunity_screen.dart';
import 'package:kepler_tech_app/screens/crm_screen.dart';
import 'package:kepler_tech_app/screens/lead_list_screen.dart';
import 'package:kepler_tech_app/screens/lead_detail_screen.dart';
import 'package:kepler_tech_app/screens/quotation_list_screen.dart';
import 'package:kepler_tech_app/screens/opportunity_list_screen.dart';
import 'package:kepler_tech_app/screens/opportunity_detail_screen.dart';
import 'package:kepler_tech_app/screens/create_lead_screen.dart';
import 'package:kepler_tech_app/screens/create_opportunity_from_lead_screen.dart';
import 'package:kepler_tech_app/screens/create_quotation_screen.dart';
import 'package:kepler_tech_app/screens/create_quotation_from_lead_screen.dart';
import 'package:kepler_tech_app/screens/quotation_detail_screen.dart';
import 'package:kepler_tech_app/screens/create_sales_order_from_quotation_screen.dart';
import 'package:kepler_tech_app/screens/new_opptunity_create_screen.dart';
import 'package:kepler_tech_app/screens/new_quotation_create_screen.dart';
import 'package:kepler_tech_app/screens/leave_dashboard_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");
    debugPrint(
      "dotenv loaded successfully. Maps_API_KEY: ${dotenv.env['Maps_API_KEY']}",
    );
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kepler Tech LLC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0074c9),
          secondary: Color(0xFF005B99),
          tertiary: Color(0xFF14B8A6),
          background: Color(0xFFF3F4F6),
          surface: Color(0xFFFFFFFF),
          surfaceVariant: Color(0xFFE5E7EB),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          titleMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
          bodySmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF0074c9), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0074c9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          // Changed to CardThemeData
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        bool hasRequiredArgs(Map<String, dynamic>? args) {
          return args != null &&
              args.containsKey('serverUrl') &&
              args.containsKey('sid') &&
              args.containsKey('email');
        }

        bool hasServerArgs(Map<String, dynamic>? args) {
          return args != null &&
              args.containsKey('serverUrl') &&
              args.containsKey('sid');
        }

        List<String>? convertToStringList(dynamic list) {
          if (list == null) return null;
          if (list is List) {
            return list.map((item) => item.toString()).toList();
          }
          return null;
        }

        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/dashboard':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  fullName: args['fullName'] ?? 'User',
                  email: args['email'],
                ),
              );
            }
            break;
          case '/leaveDashboard':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => LeaveDashboardScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/crm':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CrmScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/leadList':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => LeadListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/leadDetail':
            if (hasServerArgs(args) && args!.containsKey('lead')) {
              return MaterialPageRoute(
                builder: (_) => LeadDetailScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  lead: args['lead'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/quotationList':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => QuotationListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/quotationDetail':
            if (hasRequiredArgs(args) && args!.containsKey('quotation')) {
              return MaterialPageRoute(
                builder: (_) => QuotationDetailScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  quotation: args['quotation'],
                ),
              );
            }
            break;
          case '/createSalesOrderFromQuotation':
            if (hasRequiredArgs(args) && args!.containsKey('quotation')) {
              return MaterialPageRoute(
                builder: (_) => CreateSalesOrderFromQuotationScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  quotation: args['quotation'],
                ),
              );
            }
            break;
          case '/opportunityList':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => OpportunityListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/opportunityDetail':
            if (hasRequiredArgs(args) && args!.containsKey('opportunity')) {
              return MaterialPageRoute(
                builder: (_) => OpportunityDetailScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  opportunity: args['opportunity'],
                ),
              );
            }
            break;
          case '/createQuotation':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateQuotationScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  lead: args['lead'],
                ),
              );
            }
            break;
          case '/createQuotationFromLead':
            if (hasRequiredArgs(args) && args!.containsKey('lead')) {
              return MaterialPageRoute(
                builder: (_) => CreateQuotationFromLeadScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  lead: args['lead'],
                ),
              );
            }
            break;
          case '/sales':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => SalesScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/customerList':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CustomerListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/customerDetail':
            if (hasServerArgs(args) && args!.containsKey('customer')) {
              return MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(
                  customer: args['customer'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/addNewCustomer':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => AddNewCustomerScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/sales_invoice':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => SalesInvoiceScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  filterIds: convertToStringList(args['filterIds']),
                ),
              );
            }
            break;
          case '/salesInvoiceDetail':
            if (hasServerArgs(args) && args!.containsKey('invoiceId')) {
              return MaterialPageRoute(
                builder: (_) => SalesInvoiceDetailScreen(
                  invoiceId: args!['invoiceId'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/sales_order':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => SalesOrderScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/createSalesOrder':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateSalesOrderScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/delivery_note':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => DeliveryNoteScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  filterIds: convertToStringList(args['filterIds']),
                ),
              );
            }
            break;

          case '/delivery_note_list':
            if (hasServerArgs(args) && args!.containsKey('statusFilter')) {
              return MaterialPageRoute(
                builder: (_) => DeliveryNoteListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  statusFilter: args['statusFilter'],
                ),
              );
            }
            break;

          case '/deliveryNoteDetail':
            if (hasServerArgs(args) && args!.containsKey('noteId')) {
              return MaterialPageRoute(
                builder: (_) => DeliveryNoteDetailScreen(
                  noteId: args!['noteId'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/deliveredDetail':
            if (hasServerArgs(args) && args!.containsKey('noteId')) {
              return MaterialPageRoute(
                builder: (_) => DeliveredDetailScreen(
                  noteId: args!['noteId'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/completedDeliveryDetail':
            if (hasServerArgs(args) && args!.containsKey('noteId')) {
              return MaterialPageRoute(
                builder: (_) => CompletedDeliveryDetailScreen(
                  noteId: args!['noteId'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/hr':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) =>
                    HRScreen(serverUrl: args!['serverUrl'], sid: args['sid']),
              );
            }
            break;
          case '/leaveApplicationList':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => LeaveApplicationListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/employeeList':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => EmployeeListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/attendanceList':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => AttendanceListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/attendanceDetails':
            if (hasServerArgs(args) && args!.containsKey('attendance')) {
              return MaterialPageRoute(
                builder: (_) => AttendanceDetailsScreen(
                  attendance: args!['attendance'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/accounting':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => AccountingScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/paymentEntryList':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => PaymentEntryListScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/paymentEntryCreate':
            if (hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => PaymentEntryCreateScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/paymentEntryDetail':
            if (hasServerArgs(args) && args!.containsKey('paymentEntry')) {
              return MaterialPageRoute(
                builder: (_) => PaymentEntryDetailScreen(
                  paymentEntry: args!['paymentEntry'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
          case '/daily_visit':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => DailyVisitScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/newQuotationCreateScreen':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => NewQuotationCreateScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/create_opportunity':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateOpportunityScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  partyName: args['partyName'],
                  initialOpportunityDiscussion:
                      args['initialOpportunityDiscussion'],
                ),
              );
            }
            break;
          case '/createLead':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateLeadScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/newOpptunityCreate':
            if (hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => NewOpptunityCreateScreen(
                  serverUrl: args!['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;
          case '/createOpportunityFromLead':
            if (hasRequiredArgs(args) &&
                args!.containsKey('leadId') &&
                args.containsKey('partyName')) {
              return MaterialPageRoute(
                builder: (_) => CreateOpportunityFromLeadScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  leadId: args['leadId'],
                  partyName: args['partyName'],
                  opportunityOwner: args['opportunityOwner'],
                ),
              );
            }
            break;
          default:
            debugPrint(
              'Route: ${settings.name}, Arguments: ${settings.arguments}',
            );
            return MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('Page not found'))),
            );
        }
        debugPrint('Invalid arguments for route: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Invalid arguments'))),
        );
      },
    );
  }
}
