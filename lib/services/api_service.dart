import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<Map<String, dynamic>> fetchPaymentEntries(
    String serverUrl,
    String sid, {
    int page = 1,
    int limit = 10,
  }) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.salestracking.get_payment_entry?page=$page&limit=$limit';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to load payment entries: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching payment entries: $e');
    }
  }

  static Future<List<String>> fetchNamingSeries(
      String serverUrl, String sid) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.salestracking.get_payment_entry_naming_series';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['message']['naming_series_options']);
      } else {
        throw Exception(
            'Failed to fetch naming series: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching naming series: $e');
    }
  }

  static Future<List<String>> fetchCustomers(
      String serverUrl, String sid) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.role_api.get_customers';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['message']['status'] == 'success') {
          List<dynamic> customers = data['message']['customers'];
          return customers
              .map((customer) =>
                  customer['customer_name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        } else {
          // Backend returned error due to permission or guest user
          throw Exception(data['message']['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception(
            'Failed to fetch customers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  static Future<List<String>> fetchSuppliers(
      String serverUrl, String sid) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.salestracking.get_suppliers';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> suppliers =
            List<Map<String, dynamic>>.from(data['message']['suppliers']);
        return suppliers
            .map((supplier) =>
                supplier['supplier_name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
            'Failed to fetch suppliers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching suppliers: $e');
    }
  }

  static Future<List<String>> fetchEmployees(
      String serverUrl, String sid) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.salestracking.get_employees';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> employees =
            List<Map<String, dynamic>>.from(data['message']['employees']);
        return employees
            .map((employee) =>
                employee['employee_name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
            'Failed to fetch employees: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching employees: $e');
    }
  }

  static Future<List<String>> fetchShareholders(
      String serverUrl, String sid) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.salestracking.get_shareholders';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> shareholders =
            List<Map<String, dynamic>>.from(data['message']['title']);
        return shareholders
            .map((shareholder) => shareholder['title']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
            'Failed to fetch shareholders: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching shareholders: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchCostCenters(
      String serverUrl, String sid) async {
    final url =
        '$serverUrl/api/method/saletracking.saletracking.salestracking_api.salestracking.get_cost_centers';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to fetch cost centers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching cost centers: $e');
    }
  }

  static Future<void> createPaymentEntry(String serverUrl, String sid,
      Map<String, dynamic> paymentEntryData) async {
    final url = '$serverUrl/api/resource/Payment Entry';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(paymentEntryData),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to create payment entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment entry: $e');
    }
  }
}
