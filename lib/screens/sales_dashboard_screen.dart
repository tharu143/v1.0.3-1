import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// A model class for chart data to make it easier to work with.
class ChartData {
  final String label;
  final double value;
  ChartData(this.label, this.value);
}

// A model class for customer data.
class CustomerData {
  final String name;
  final double totalAmount;
  final int invoiceCount;

  CustomerData({
    required this.name,
    required this.totalAmount,
    required this.invoiceCount,
  });

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    return CustomerData(
      name: json['customer'] ?? 'Unknown',
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      invoiceCount: json['invoice_count'] ?? 0,
    );
  }
}

class SalesDashboardScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const SalesDashboardScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _SalesDashboardScreenState createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  // Data holders
  Map<String, dynamic>? _salesSummary;
  List<CustomerData> _bestCustomers = [];
  List<ChartData> _monthlySales = [];
  List<ChartData> _quarterlySales = [];
  
  // Loading states for each section
  bool _isSummaryLoading = true;
  bool _isCustomersLoading = true;
  bool _isMonthlyLoading = true;
  bool _isQuarterlyLoading = true;
  
  int _touchedIndex = -1;

  // Date filters for each chart
  DateTime? _salesSummaryFromDate;
  DateTime? _salesSummaryToDate;
  DateTime? _topCustomersFromDate;
  DateTime? _topCustomersToDate;
  DateTime? _monthlySalesFromDate;
  DateTime? _monthlySalesToDate;
  DateTime? _quarterlySalesFromDate;
  DateTime? _quarterlySalesToDate;


  @override
  void initState() {
    super.initState();
    // Set default date range to the current year for monthly/quarterly charts
    final now = DateTime.now();
    _salesSummaryFromDate = DateTime(now.year, now.month, 1);
    _salesSummaryToDate = DateTime(now.year, now.month + 1, 0);
    _topCustomersFromDate = DateTime(now.year, now.month, 1);
    _topCustomersToDate = DateTime(now.year, now.month + 1, 0);
    _monthlySalesFromDate = DateTime(now.year, 1, 1);
    _monthlySalesToDate = DateTime(now.year, 12, 31);
    _quarterlySalesFromDate = DateTime(now.year, 1, 1);
    _quarterlySalesToDate = DateTime(now.year, 12, 31);

    _fetchAllData();
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _fetchAllData() async {
    setState(() {
      _isSummaryLoading = true;
      _isCustomersLoading = true;
      _isMonthlyLoading = true;
      _isQuarterlyLoading = true;
    });
    await Future.wait([
      _fetchSalesSummary(),
      _fetchBestCustomers(),
      _fetchMonthlySales(),
      _fetchQuarterlySales(),
    ]);
  }

  Future<void> _fetchSalesSummary() async {
    setState(() => _isSummaryLoading = true);
    try {
      final queryParams = {'from_date': _formatDate(_salesSummaryFromDate!), 'to_date': _formatDate(_salesSummaryToDate!)};
      final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_sales_summary').replace(queryParameters: queryParams);
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        setState(() => _salesSummary = json.decode(response.body)['message']);
      }
    } finally {
       if(mounted) setState(() => _isSummaryLoading = false);
    }
  }

  Future<void> _fetchBestCustomers() async {
     setState(() => _isCustomersLoading = true);
    try {
      final queryParams = {'from_date': _formatDate(_topCustomersFromDate!), 'to_date': _formatDate(_topCustomersToDate!)};
      final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_best_customer_for_ipo').replace(queryParameters: queryParams);
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null && data['message']['overall'] is List) {
          setState(() => _bestCustomers = (data['message']['overall'] as List).map((json) => CustomerData.fromJson(json)).toList());
        }
      }
    } finally {
      if(mounted) setState(() => _isCustomersLoading = false);
    }
  }

  Future<void> _fetchMonthlySales() async {
    setState(() => _isMonthlyLoading = true);
    try {
      final queryParams = {'from_date': _formatDate(_monthlySalesFromDate!), 'to_date': _formatDate(_monthlySalesToDate!), 'monthly': 'true'};
      final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_sales_summary').replace(queryParameters: queryParams);
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null && data['message']['monthly'] is List) {
          setState(() => _monthlySales = (data['message']['monthly'] as List).map((item) => ChartData(DateFormat('MMM').format(DateTime(0, item['month'])), (item['amount'] ?? 0.0).toDouble())).toList());
        }
      }
    } finally {
      if(mounted) setState(() => _isMonthlyLoading = false);
    }
  }

  Future<void> _fetchQuarterlySales() async {
    setState(() => _isQuarterlyLoading = true);
    try {
      final queryParams = {'from_date': _formatDate(_quarterlySalesFromDate!), 'to_date': _formatDate(_quarterlySalesToDate!), 'quarterly': 'true'};
      final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_sales_summary').replace(queryParameters: queryParams);
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null && data['message']['quarterly'] is List) {
          setState(() => _quarterlySales = (data['message']['quarterly'] as List).map((item) => ChartData('Q${item['quarter']}', (item['amount'] ?? 0.0).toDouble())).toList());
        }
      }
    } finally {
      if(mounted) setState(() => _isQuarterlyLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate, String chartType) async {
    DateTime? initialDate;
    switch(chartType) {
      case 'summary':
        initialDate = isFromDate ? _salesSummaryFromDate : _salesSummaryToDate;
        break;
      case 'customers':
        initialDate = isFromDate ? _topCustomersFromDate : _topCustomersToDate;
        break;
      case 'monthly':
        initialDate = isFromDate ? _monthlySalesFromDate : _monthlySalesToDate;
        break;
      case 'quarterly':
        initialDate = isFromDate ? _quarterlySalesFromDate : _quarterlySalesToDate;
        break;
    }

    final DateTime? picked = await showDatePicker(context: context, initialDate: initialDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
    if (picked != null) {
      setState(() {
        switch(chartType) {
          case 'summary':
            isFromDate ? _salesSummaryFromDate = picked : _salesSummaryToDate = picked;
            break;
          case 'customers':
            isFromDate ? _topCustomersFromDate = picked : _topCustomersToDate = picked;
            break;
          case 'monthly':
            isFromDate ? _monthlySalesFromDate = picked : _monthlySalesToDate = picked;
            break;
          case 'quarterly':
            isFromDate ? _quarterlySalesFromDate = picked : _quarterlySalesToDate = picked;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAnythingLoading = _isSummaryLoading || _isCustomersLoading || _isMonthlyLoading || _isQuarterlyLoading;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Sales Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isAnythingLoading && _salesSummary == null // Show initial full screen loader
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAllData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (_salesSummary != null) ...[
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildChartCard(
                      title: "Sales Comparison",
                      fromDate: _salesSummaryFromDate,
                      toDate: _salesSummaryToDate,
                      chartType: 'summary',
                      onApply: _fetchSalesSummary,
                      isLoading: _isSummaryLoading,
                      chart: _buildSalesSummaryChart(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildChartCard(
                    title: "Monthly Sales",
                    fromDate: _monthlySalesFromDate,
                    toDate: _monthlySalesToDate,
                    chartType: 'monthly',
                    onApply: _fetchMonthlySales,
                    isLoading: _isMonthlyLoading,
                    chart: _buildGenericBarChart(_monthlySales, Colors.teal),
                  ),
                  const SizedBox(height: 24),
                  _buildChartCard(
                    title: "Quarterly Sales",
                    fromDate: _quarterlySalesFromDate,
                    toDate: _quarterlySalesToDate,
                    chartType: 'quarterly',
                    onApply: _fetchQuarterlySales,
                    isLoading: _isQuarterlyLoading,
                    chart: _buildGenericBarChart(_quarterlySales, Colors.indigo),
                  ),
                  const SizedBox(height: 24),
                  _buildChartCard(
                    title: "Top Customers",
                    fromDate: _topCustomersFromDate,
                    toDate: _topCustomersToDate,
                    chartType: 'customers',
                    onApply: _fetchBestCustomers,
                    isLoading: _isCustomersLoading,
                    chart: _buildBestCustomersChart(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart, required bool isLoading, required DateTime? fromDate, required DateTime? toDate, required String chartType, required VoidCallback onApply}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDatePickerButton(context, 'From', fromDate, true, chartType),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                _buildDatePickerButton(context, 'To', toDate, false, chartType),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Apply Filter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: onApply,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 350,
              child: isLoading ? const Center(child: CircularProgressIndicator()) : chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(BuildContext context, String label, DateTime? date, bool isFrom, String chartType) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        TextButton(
          onPressed: () => _selectDate(context, isFrom, chartType),
          child: Text(
            date != null ? _formatDate(date) : 'Select Date',
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildSummaryCard('Total Sales', _salesSummary!['total_sales']['amount'], Icons.trending_up, Colors.blue),
        _buildSummaryCard('Sales Today', _salesSummary!['sales_today']['amount'], Icons.today, Colors.green),
        _buildSummaryCard('This Month', _salesSummary!['sales_this_month']['amount'], Icons.calendar_month, Colors.orange),
        _buildSummaryCard('Last Month', _salesSummary!['sales_last_month']['amount'], Icons.history, Colors.purple),
      ],
    );
  }

  Widget _buildSummaryCard(String title, dynamic amount, IconData icon, Color color) {
    final formattedAmount = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 2).format(amount ?? 0.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.7), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              children: [
                 Icon(icon, color: Colors.white, size: 24),
                 const SizedBox(width: 8),
                 Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formattedAmount, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryChart() {
    final salesData = {
      'Today': (_salesSummary!['sales_today']['amount'] ?? 0.0).toDouble(),
      'This Month': (_salesSummary!['sales_this_month']['amount'] ?? 0.0).toDouble(),
      'Last Month': (_salesSummary!['sales_last_month']['amount'] ?? 0.0).toDouble(),
    };
    final barColors = [Colors.blue, Colors.orange, Colors.purple];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (salesData.values.isEmpty ? 100 : salesData.values.reduce((a, b) => a > b ? a : b) * 1.4),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String period = salesData.keys.elementAt(group.x.toInt());
              return BarTooltipItem('$period\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[TextSpan(text: 'AED ${rod.toY.toStringAsFixed(2)}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500))],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(salesData.keys.elementAt(value.toInt()), style: const TextStyle(fontSize: 12))), reservedSize: 30)),
          leftTitles: AxisTitles(axisNameWidget: const Text("AED", style: TextStyle(fontSize: 10)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(NumberFormat.compact().format(value), style: const TextStyle(fontSize: 10)))), 
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        barGroups: salesData.entries.map((entry) {
          final index = salesData.keys.toList().indexOf(entry.key);
          return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: entry.value, gradient: LinearGradient(colors: [barColors[index].withOpacity(0.7), barColors[index]], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 30, borderRadius: BorderRadius.circular(6))]);
        }).toList(),
      ),
    );
  }

  Widget _buildGenericBarChart(List<ChartData> data, Color color) {
    if (data.isEmpty) return const Center(child: Text("No data available for this period."));
    final chartWidth = data.length * 70.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: (data.map((d) => d.value).reduce((a, b) => a > b ? a : b) * 1.4),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final item = data[group.x.toInt()];
                  return BarTooltipItem('${item.label}\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: <TextSpan>[TextSpan(text: 'AED ${item.value.toStringAsFixed(2)}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500))],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(data[value.toInt()].label, style: const TextStyle(fontSize: 12))), reservedSize: 30)),
              leftTitles: AxisTitles(axisNameWidget: const Text("AED", style: TextStyle(fontSize: 10)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(NumberFormat.compact().format(value), style: const TextStyle(fontSize: 10)))), 
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
            barGroups: data.asMap().entries.map((entry) {
              return BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: entry.value.value, gradient: LinearGradient(colors: [color.withOpacity(0.7), color], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 40, borderRadius: BorderRadius.circular(6))]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBestCustomersChart() {
    if (_bestCustomers.isEmpty) return const Center(child: Text("No customer data available for this period."));
    final barColors = [Colors.green, Colors.teal, Colors.cyan, Colors.lightBlue, Colors.indigo, Colors.red, Colors.pink, Colors.amber, Colors.deepOrange, Colors.brown];
    final chartWidth = _bestCustomers.length * 80.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: (_bestCustomers.map((c) => c.totalAmount).reduce((a, b) => a > b ? a : b) * 1.4),
            barTouchData: BarTouchData(
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                setState(() {
                  _touchedIndex = (event.isInterestedForInteractions && barTouchResponse?.spot != null) ? barTouchResponse!.spot!.touchedBarGroupIndex : -1;
                });
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final customer = _bestCustomers[group.x.toInt()];
                  return BarTooltipItem('${customer.name}\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: <TextSpan>[
                      TextSpan(text: 'AED ${customer.totalAmount.toStringAsFixed(2)}\n', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500)),
                      TextSpan(text: '${customer.invoiceCount} Invoices', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final customer = _bestCustomers[value.toInt()];
                    String shortName = customer.name.length > 10 ? '${customer.name.substring(0, 8)}...' : customer.name;
                    return SideTitleWidget(axisSide: meta.axisSide, space: 4.0, child: Text(shortName, style: const TextStyle(fontSize: 10)));
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(axisNameWidget: const Text("AED", style: TextStyle(fontSize: 10)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(NumberFormat.compact().format(value), style: const TextStyle(fontSize: 10)))), 
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
            barGroups: _bestCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;
              final isTouched = index == _touchedIndex;
              final color = barColors[index % barColors.length];
              return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: customer.totalAmount, gradient: LinearGradient(colors: [color.withOpacity(0.7), color], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: isTouched ? 45 : 40, borderRadius: BorderRadius.circular(6), borderSide: isTouched ? BorderSide(color: color.withRed(200), width: 2) : const BorderSide(width: 0))]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
