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
    // Set default date range to the current month for summary/customers
    // and current year for monthly/quarterly charts
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

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

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
      final queryParams = {
        'from_date': DateFormat('yyyy-MM-dd').format(_salesSummaryFromDate!),
        'to_date': DateFormat('yyyy-MM-dd').format(_salesSummaryToDate!)
      };
      final url = Uri.parse(
              '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_sales_summary')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        setState(() => _salesSummary = json.decode(response.body)['message']);
      }
    } finally {
      if (mounted) setState(() => _isSummaryLoading = false);
    }
  }

  Future<void> _fetchBestCustomers() async {
    setState(() => _isCustomersLoading = true);
    try {
      final queryParams = {
        'from_date': DateFormat('yyyy-MM-dd').format(_topCustomersFromDate!),
        'to_date': DateFormat('yyyy-MM-dd').format(_topCustomersToDate!)
      };
      final url = Uri.parse(
              '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_best_customer_for_ipo')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null && data['message']['overall'] is List) {
          setState(() => _bestCustomers =
              (data['message']['overall'] as List)
                  .map((json) => CustomerData.fromJson(json))
                  .toList());
        }
      }
    } finally {
      if (mounted) setState(() => _isCustomersLoading = false);
    }
  }

  Future<void> _fetchMonthlySales() async {
    setState(() => _isMonthlyLoading = true);
    try {
      final queryParams = {
        'from_date': DateFormat('yyyy-MM-dd').format(_monthlySalesFromDate!),
        'to_date': DateFormat('yyyy-MM-dd').format(_monthlySalesToDate!),
        'monthly': 'true'
      };
      final url = Uri.parse(
              '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_sales_summary')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null && data['message']['monthly'] is List) {
          setState(() => _monthlySales =
              (data['message']['monthly'] as List)
                  .map((item) => ChartData(
                      DateFormat('MMM').format(DateTime(0, item['month'])),
                      (item['amount'] ?? 0.0).toDouble()))
                  .toList());
        }
      }
    } finally {
      if (mounted) setState(() => _isMonthlyLoading = false);
    }
  }

  Future<void> _fetchQuarterlySales() async {
    setState(() => _isQuarterlyLoading = true);
    try {
      final queryParams = {
        'from_date': DateFormat('yyyy-MM-dd').format(_quarterlySalesFromDate!),
        'to_date': DateFormat('yyyy-MM-dd').format(_quarterlySalesToDate!),
        'quarterly': 'true'
      };
      final url = Uri.parse(
              '${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.sales_dashboard.get_sales_summary')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null &&
            data['message']['quarterly'] is List) {
          setState(() => _quarterlySales =
              (data['message']['quarterly'] as List)
                  .map((item) => ChartData(
                      'Q${item['quarter']}', (item['amount'] ?? 0.0).toDouble()))
                  .toList());
        }
      }
    } finally {
      if (mounted) setState(() => _isQuarterlyLoading = false);
    }
  }

  // A single method to handle date range selection for any chart.
  Future<void> _selectDateRange(
      BuildContext context, String chartType, VoidCallback onApply) async {
    DateTimeRange? initialDateRange;
    switch (chartType) {
      case 'summary':
        initialDateRange = DateTimeRange(
            start: _salesSummaryFromDate!, end: _salesSummaryToDate!);
        break;
      case 'customers':
        initialDateRange = DateTimeRange(
            start: _topCustomersFromDate!, end: _topCustomersToDate!);
        break;
      case 'monthly':
        initialDateRange = DateTimeRange(
            start: _monthlySalesFromDate!, end: _monthlySalesToDate!);
        break;
      case 'quarterly':
        initialDateRange = DateTimeRange(
            start: _quarterlySalesFromDate!, end: _quarterlySalesToDate!);
        break;
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        switch (chartType) {
          case 'summary':
            _salesSummaryFromDate = picked.start;
            _salesSummaryToDate = picked.end;
            break;
          case 'customers':
            _topCustomersFromDate = picked.start;
            _topCustomersToDate = picked.end;
            break;
          case 'monthly':
            _monthlySalesFromDate = picked.start;
            _monthlySalesToDate = picked.end;
            break;
          case 'quarterly':
            _quarterlySalesFromDate = picked.start;
            _quarterlySalesToDate = picked.end;
            break;
        }
      });
      onApply(); // Apply filter immediately after picking.
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAnythingLoading = _isSummaryLoading ||
        _isCustomersLoading ||
        _isMonthlyLoading ||
        _isQuarterlyLoading;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Sales Analytics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isAnythingLoading &&
              _salesSummary ==
                  null // Show initial full screen loader only on first load
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
                    chart: _buildGenericBarChart(
                        _monthlySales, Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  _buildChartCard(
                    title: "Quarterly Sales",
                    fromDate: _quarterlySalesFromDate,
                    toDate: _quarterlySalesToDate,
                    chartType: 'quarterly',
                    onApply: _fetchQuarterlySales,
                    isLoading: _isQuarterlyLoading,
                    chart: _buildGenericBarChart(_quarterlySales,
                        Theme.of(context).colorScheme.secondary),
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

  // Refactored chart card with a cleaner filter UI
  Widget _buildChartCard(
      {required String title,
      required Widget chart,
      required bool isLoading,
      required DateTime? fromDate,
      required DateTime? toDate,
      required String chartType,
      required VoidCallback onApply}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap( // Changed Row to Wrap to handle overflow
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8.0, // Add spacing if the content wraps to the next line
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: Text('${_formatDate(fromDate!)} - ${_formatDate(toDate!)}'),
                  onPressed: () => _selectDateRange(context, chartType, onApply),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300)
                      )
                    ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chart,
            ),
          ],
        ),
      ),
    );
  }

  // Summary cards grid now uses LayoutBuilder for responsiveness
  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust grid based on available width
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
        double childAspectRatio = constraints.maxWidth < 380 ? 2.0 : (constraints.maxWidth < 600 ? 1.8 : 2.2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _buildSummaryCard('Total Sales', _salesSummary!['total_sales']['amount'],
                Icons.trending_up, Colors.blue),
            _buildSummaryCard('Sales Today', _salesSummary!['sales_today']['amount'],
                Icons.today, Colors.green),
            _buildSummaryCard(
                'This Month',
                _salesSummary!['sales_this_month']['amount'],
                Icons.calendar_month,
                Colors.orange),
            _buildSummaryCard(
                'Last Month',
                _salesSummary!['sales_last_month']['amount'],
                Icons.history,
                Colors.purple),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String title, dynamic amount, IconData icon, Color color) {
    final formattedAmount = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 2)
        .format(amount ?? 0.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withOpacity(0.7),
          color
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
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
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formattedAmount,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryChart() {
    final salesData = {
      'Today': (_salesSummary!['sales_today']['amount'] ?? 0.0).toDouble(),
      'This Month':
          (_salesSummary!['sales_this_month']['amount'] ?? 0.0).toDouble(),
      'Last Month':
          (_salesSummary!['sales_last_month']['amount'] ?? 0.0).toDouble(),
    };
    final barColors = [Colors.blue, Colors.orange, Colors.purple];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (salesData.values.isEmpty
                ? 100
                : salesData.values.reduce((a, b) => a > b ? a : b)) *
            1.4,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            fitInsideHorizontally: true, // Tooltip chart kulla show aagum
            fitInsideVertically: true, // Tooltip chart kulla show aagum
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String period = salesData.keys.elementAt(group.x.toInt());
              return BarTooltipItem(
                '$period\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                      text: 'AED ${rod.toY.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.yellow, fontWeight: FontWeight.w500)),
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
                  getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(salesData.keys.elementAt(value.toInt()),
                          style: const TextStyle(fontSize: 12))),
                  reservedSize: 30)),
          leftTitles: AxisTitles(
              axisNameWidget:
                  const Text("AED", style: TextStyle(fontSize: 10)),
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                      NumberFormat.compact().format(value),
                      style: const TextStyle(fontSize: 10)))),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        barGroups: salesData.entries.map((entry) {
          final index = salesData.keys.toList().indexOf(entry.key);
          return BarChartGroupData(x: index, barRods: [
            BarChartRodData(
                toY: entry.value,
                gradient: LinearGradient(colors: [
                  barColors[index].withOpacity(0.7),
                  barColors[index]
                ], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                width: 35,
                borderRadius: BorderRadius.circular(6))
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildGenericBarChart(List<ChartData> data, Color color) {
    if (data.isEmpty)
      return const Center(child: Text("No data available for this period."));
    
    // Make chart width responsive to the amount of data
    final chartWidth = (data.length * 80.0).clamp(MediaQuery.of(context).size.width, double.infinity);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY:
                (data.map((d) => d.value).reduce((a, b) => a > b ? a : b)) * 1.4,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey,
                fitInsideHorizontally: true, // Tooltip chart kulla show aagum
                fitInsideVertically: true, // Tooltip chart kulla show aagum
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final item = data[group.x.toInt()];
                  return BarTooltipItem(
                    '${item.label}\n',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    children: <TextSpan>[
                      TextSpan(
                          text: 'AED ${item.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.yellow,
                              fontWeight: FontWeight.w500)),
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
                      getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(data[value.toInt()].label,
                              style: const TextStyle(fontSize: 12))),
                      reservedSize: 30)),
              leftTitles: AxisTitles(
                  axisNameWidget:
                      const Text("AED", style: TextStyle(fontSize: 10)),
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact().format(value),
                          style: const TextStyle(fontSize: 10)))),
              topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
            barGroups: data.asMap().entries.map((entry) {
              return BarChartGroupData(x: entry.key, barRods: [
                BarChartRodData(
                    toY: entry.value.value,
                    gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter),
                    width: 45,
                    borderRadius: BorderRadius.circular(6))
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBestCustomersChart() {
    if (_bestCustomers.isEmpty)
      return const Center(
          child: Text("No customer data available for this period."));
    
    // Base color for the customer chart
    final Color baseColor = Theme.of(context).colorScheme.primary;
    final chartWidth = (_bestCustomers.length * 90.0).clamp(MediaQuery.of(context).size.width, double.infinity);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: (_bestCustomers
                    .map((c) => c.totalAmount)
                    .reduce((a, b) => a > b ? a : b)) *
                1.4,
            barTouchData: BarTouchData(
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                setState(() {
                  _touchedIndex =
                      (event.isInterestedForInteractions && barTouchResponse?.spot != null)
                          ? barTouchResponse!.spot!.touchedBarGroupIndex
                          : -1;
                });
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                fitInsideHorizontally: true, // Tooltip chart kulla show aagum
                fitInsideVertically: true, // Tooltip chart kulla show aagum
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final customer = _bestCustomers[group.x.toInt()];
                  return BarTooltipItem(
                    '${customer.name}\n',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    children: <TextSpan>[
                      TextSpan(
                          text: 'AED ${customer.totalAmount.toStringAsFixed(2)}\n',
                          style: const TextStyle(
                              color: Colors.yellow,
                              fontWeight: FontWeight.w500)),
                      TextSpan(
                          text: '${customer.invoiceCount} Invoices',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
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
                    String shortName = customer.name.length > 10
                        ? '${customer.name.substring(0, 8)}...'
                        : customer.name;
                    return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4.0,
                        child: Text(shortName,
                            style: const TextStyle(fontSize: 10)));
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(
                  axisNameWidget:
                      const Text("AED", style: TextStyle(fontSize: 10)),
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact().format(value),
                          style: const TextStyle(fontSize: 10)))),
              topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
            barGroups: _bestCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;
              final isTouched = index == _touchedIndex;
              
              // Generate a palette of harmonious colors from the base color
              final color = HSLColor.fromColor(baseColor).withHue((HSLColor.fromColor(baseColor).hue + index * 25) % 360).toColor();

              return BarChartGroupData(x: index, barRods: [
                BarChartRodData(
                    toY: customer.totalAmount,
                    gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter),
                    width: isTouched ? 50 : 45,
                    borderRadius: BorderRadius.circular(6),
                    borderSide: isTouched
                        ? BorderSide(color: color.withBlue(255), width: 2)
                        : const BorderSide(width: 0))
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

