import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// --- Data Models for Attendance API ---
class EmployeeAttendanceReport {
  final String employee;
  final String employeeName;
  final String fromDate;
  final String toDate;
  final TotalSummary totalSummary;
  final Map<String, MonthlySummary> monthlySummary;
  final Map<String, DateWiseDetail> dateWiseDetail;

  EmployeeAttendanceReport({
    required this.employee,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.totalSummary,
    required this.monthlySummary,
    required this.dateWiseDetail,
  });

  factory EmployeeAttendanceReport.fromJson(Map<String, dynamic> json) {
    var monthlySummaryMap = (json['monthly_summary'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, MonthlySummary.fromJson(value)),
    );
    var dateWiseDetailMap = (json['date_wise_detail'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, DateWiseDetail.fromJson(value)),
    );
    return EmployeeAttendanceReport(
      employee: json['employee'] ?? '',
      employeeName: json['employee_name'] ?? 'N/A',
      fromDate: json['from_date'] ?? '',
      toDate: json['to_date'] ?? '',
      totalSummary: TotalSummary.fromJson(json['total_summary'] ?? {}),
      monthlySummary: monthlySummaryMap,
      dateWiseDetail: dateWiseDetailMap,
    );
  }
}

class TotalSummary {
  final int present, absent, sickLeave, annualLeave;
  TotalSummary({required this.present, required this.absent, required this.sickLeave, required this.annualLeave});
  factory TotalSummary.fromJson(Map<String, dynamic> json) {
    return TotalSummary(
      present: (json['present'] ?? 0).toInt(),
      absent: (json['absent'] ?? 0).toInt(),
      sickLeave: (json['sick_leave'] ?? 0).toInt(),
      annualLeave: (json['annual_leave'] ?? 0).toInt(),
    );
  }
}

class MonthlySummary {
  final int present, absent, sickLeave, annualLeave;
  MonthlySummary({required this.present, required this.absent, required this.sickLeave, required this.annualLeave});
  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      present: (json['present'] ?? 0).toInt(),
      absent: (json['absent'] ?? 0).toInt(),
      sickLeave: (json['sick_leave'] ?? 0).toInt(),
      annualLeave: (json['annual_leave'] ?? 0).toInt(),
    );
  }
}

class DateWiseDetail {
  final String status;
  final String? leaveType;
  DateWiseDetail({required this.status, this.leaveType});
  factory DateWiseDetail.fromJson(Map<String, dynamic> json) {
    return DateWiseDetail(status: json['status'] ?? 'Unknown', leaveType: json['leave_type']);
  }
}

// --- Data Models for Leave Balance API ---
class LeaveBalanceReport {
    final String leaveType;
    final String employee;
    final String employeeName;
    final double openingBalance;
    final double leavesAllocated;
    final double leavesTaken;
    final double leavesExpired;
    final double closingBalance;
    final int isCarryForward;
    final int isExpired;

    LeaveBalanceReport({
        required this.leaveType,
        required this.employee,
        required this.employeeName,
        required this.openingBalance,
        required this.leavesAllocated,
        required this.leavesTaken,
        required this.leavesExpired,
        required this.closingBalance,
        required this.isCarryForward,
        required this.isExpired,
    });

    factory LeaveBalanceReport.fromJson(Map<String, dynamic> json) {
        return LeaveBalanceReport(
            leaveType: json['leave_type'] ?? 'N/A',
            employee: json['employee'] ?? '',
            employeeName: json['employee_name'] ?? 'N/A',
            openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
            leavesAllocated: (json['leaves_allocated'] as num?)?.toDouble() ?? 0.0,
            leavesTaken: (json['leaves_taken'] as num?)?.toDouble() ?? 0.0,
            leavesExpired: (json['leaves_expired'] as num?)?.toDouble() ?? 0.0,
            closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0.0,
            isCarryForward: (json['is_carry_forward'] as num?)?.toInt() ?? 0,
            isExpired: (json['is_expired'] as num?)?.toInt() ?? 0,
        );
    }
}


// --- Main Screen Widget ---
class LeaveDashboardScreen extends StatefulWidget {
  final String serverUrl, sid;
  const LeaveDashboardScreen({Key? key, required this.serverUrl, required this.sid}) : super(key: key);
  @override
  _LeaveDashboardScreenState createState() => _LeaveDashboardScreenState();
}

class _LeaveDashboardScreenState extends State<LeaveDashboardScreen> {
  // State for Attendance Chart
  List<EmployeeAttendanceReport>? _attendanceReportData;
  bool _isAttendanceLoading = true;
  bool _isManagerView = false;
  late DateTime _attendanceFromDate, _attendanceToDate;
  String? _selectedEmployeeForAttendance;
  Map<String, String> _employeeDropdownItems = {};

  // State for Yearly Leave Summary Chart
  List<LeaveBalanceReport>? _yearlyLeaveData;
  bool _isYearlyLeaveLoading = true;
  int _selectedYear = DateTime.now().year;
  String? _selectedEmployeeForYearly;

  // State for Leave Balance Details Chart
  List<LeaveBalanceReport>? _leaveDetailsData;
  bool _isLeaveDetailsLoading = true;
  late DateTime _leaveDetailsFromDate, _leaveDetailsToDate;
  String? _selectedEmployeeForDetails;


  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _attendanceFromDate = DateTime(now.year, now.month, 1);
    _attendanceToDate = DateTime(now.year, now.month + 1, 0);
    _leaveDetailsFromDate = DateTime(now.year, 1, 1);
    _leaveDetailsToDate = DateTime(now.year, 12, 31);
    _fetchAttendanceData(isInitialLoad: true);
    _fetchYearlyLeaveData();
    _fetchLeaveDetailsData();
  }

  Future<void> _fetchAttendanceData({bool isInitialLoad = false}) async {
    setState(() => _isAttendanceLoading = true);
    final params = {'from_date': DateFormat('yyyy-MM-dd').format(_attendanceFromDate), 'to_date': DateFormat('yyyy-MM-dd').format(_attendanceToDate)};
    if (_selectedEmployeeForAttendance != null) params['employee'] = _selectedEmployeeForAttendance!;
    final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.attendance.get_employee_attendance_report').replace(queryParameters: params);
    try {
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'] as List;
        final reports = data.map((item) => EmployeeAttendanceReport.fromJson(item)).toList();
        if (isInitialLoad) {
          final allEmpUrl = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.attendance.get_employee_attendance_report');
          final allEmpResponse = await http.get(allEmpUrl, headers: {'Cookie': 'sid=${widget.sid}'});
          if (allEmpResponse.statusCode == 200) {
            final allEmpData = json.decode(allEmpResponse.body)['message'] as List;
            final allReports = allEmpData.map((item) => EmployeeAttendanceReport.fromJson(item)).toList();
            if (allReports.length > 1) {
              setState(() {
                _isManagerView = true;
                _employeeDropdownItems = {for (var r in allReports) r.employee: r.employeeName};
              });
            }
          }
        }
        setState(() => _attendanceReportData = reports);
      } else {
        throw Exception('Failed to load attendance data');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isAttendanceLoading = false);
    }
  }
  
  Future<void> _fetchYearlyLeaveData() async {
    setState(() => _isYearlyLeaveLoading = true);
    final params = {'year': _selectedYear.toString()};
     if (_selectedEmployeeForYearly != null) params['employee'] = _selectedEmployeeForYearly!;
    final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.leave.get_employee_leave_balance').replace(queryParameters: params);
    try {
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'] as List;
        final reports = data.map((item) => LeaveBalanceReport.fromJson(item)).toList();
        setState(() => _yearlyLeaveData = reports);
      } else {
        throw Exception('Failed to load yearly leave data');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isYearlyLeaveLoading = false);
    }
  }

  Future<void> _fetchLeaveDetailsData() async {
    setState(() => _isLeaveDetailsLoading = true);
    final params = {'from_date': DateFormat('yyyy-MM-dd').format(_leaveDetailsFromDate), 'to_date': DateFormat('yyyy-MM-dd').format(_leaveDetailsToDate)};
     if (_selectedEmployeeForDetails != null) params['employee'] = _selectedEmployeeForDetails!;
    final url = Uri.parse('${widget.serverUrl}/api/method/saletracking.saletracking.salestracking_api.leave.get_employee_leave_balance').replace(queryParameters: params);
    try {
      final response = await http.get(url, headers: {'Cookie': 'sid=${widget.sid}'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'] as List;
        final reports = data.map((item) => LeaveBalanceReport.fromJson(item)).toList();
        setState(() => _leaveDetailsData = reports);
      } else {
        throw Exception('Failed to load leave details data');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLeaveDetailsLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance & Leave Report', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0074c9)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildChartCard(
                title: 'Attendance Summary',
                filters: _buildAttendanceFilters(),
                chartContent: _buildAttendanceChartContent(),
              ),
              const SizedBox(height: 16),
               _buildChartCard(
                title: 'Yearly Leave Summary',
                filters: _buildYearlyLeaveFilters(),
                chartContent: _buildYearlyLeaveChartContent(),
              ),
              const SizedBox(height: 16),
              _buildChartCard(
                title: 'Annual Leave Balance Details',
                filters: _buildLeaveDetailsFilters(),
                chartContent: _buildLeaveBalanceDetailsChartContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget filters, required Widget chartContent}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            filters,
            const Divider(height: 32),
            SizedBox(height: 300, child: chartContent),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceFilters() {
     return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDateFilter('From', _attendanceFromDate, (date) {
              setState(() => _attendanceFromDate = date);
              _fetchAttendanceData();
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildDateFilter('To', _attendanceToDate, (date) {
               setState(() => _attendanceToDate = date);
              _fetchAttendanceData();
            })),
          ],
        ),
        if (_isManagerView) ...[
          const SizedBox(height: 12),
          _buildEmployeeSearchFilter(
            onChanged: (value) {
              setState(() => _selectedEmployeeForAttendance = value);
              _fetchAttendanceData();
            },
            onClear: () {
              setState(() => _selectedEmployeeForAttendance = null);
              _fetchAttendanceData();
            }
          ),
        ],
      ],
    );
  }
  
  Widget _buildYearlyLeaveFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: List.generate(10, (index) => DateTime.now().year - index)
                .map((year) => DropdownMenuItem(value: year, child: Text(year.toString())))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
                _fetchYearlyLeaveData();
              }
            },
          ),
        ),
        if (_isManagerView) ...[
          const SizedBox(width: 12),
          Expanded(child: _buildEmployeeSearchFilter(
             onChanged: (value) {
              setState(() => _selectedEmployeeForYearly = value);
              _fetchYearlyLeaveData();
            },
            onClear: () {
              setState(() => _selectedEmployeeForYearly = null);
              _fetchYearlyLeaveData();
            }
          )),
        ]
      ],
    );
  }

  Widget _buildLeaveDetailsFilters() {
     return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDateFilter('From', _leaveDetailsFromDate, (date) {
              setState(() => _leaveDetailsFromDate = date);
              _fetchLeaveDetailsData();
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildDateFilter('To', _leaveDetailsToDate, (date) {
               setState(() => _leaveDetailsToDate = date);
              _fetchLeaveDetailsData();
            })),
          ],
        ),
        if (_isManagerView) ...[
          const SizedBox(height: 12),
          _buildEmployeeSearchFilter(
             onChanged: (value) {
              setState(() => _selectedEmployeeForDetails = value);
              _fetchLeaveDetailsData();
            },
            onClear: () {
              setState(() => _selectedEmployeeForDetails = null);
              _fetchLeaveDetailsData();
            }
          ),
        ],
      ],
    );
  }

  Widget _buildDateFilter(String label, DateTime date, Function(DateTime) onDateChanged) {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (pickedDate != null) {
          onDateChanged(pickedDate);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(DateFormat.yMMMd().format(date)),
      ),
    );
  }

  Widget _buildEmployeeSearchFilter({required ValueChanged<String?> onChanged, required VoidCallback onClear}) {
    return Autocomplete<MapEntry<String, String>>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return _employeeDropdownItems.entries;
        return _employeeDropdownItems.entries.where((e) => e.value.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (option) => option.value,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Search Employee',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                controller.clear();
                onClear();
              },
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(onTap: () => onSelected(option), child: ListTile(title: Text(option.value)));
                },
              ),
            ),
          ),
        );
      },
      onSelected: (selection) => onChanged(selection.key),
    );
  }
  
  Widget _buildAttendanceChartContent() {
    bool isMultiMonthView = _attendanceToDate.difference(_attendanceFromDate).inDays > 31;
    if (_isAttendanceLoading) return const Center(child: CircularProgressIndicator());
    if (_attendanceReportData == null || _attendanceReportData!.isEmpty) return const Center(child: Text('No data for selected filters.'));
    
    Widget chart;
    if (isMultiMonthView) {
      chart = _buildMonthlySummaryChart(_attendanceReportData!.first);
    } else if (_isManagerView && _selectedEmployeeForAttendance == null) {
      chart = _buildAdminChart(_attendanceReportData!);
    } else {
      chart = _buildEmployeeChart(_attendanceReportData!.first);
    }
    return Column(children: [Expanded(child: chart), const SizedBox(height: 16), _buildLegend()]);
  }
  
  Widget _buildYearlyLeaveChartContent() {
    if (_isYearlyLeaveLoading) return const Center(child: CircularProgressIndicator());
    if (_yearlyLeaveData == null || _yearlyLeaveData!.isEmpty) return const Center(child: Text('No data for selected filters.'));
    
    final annualLeaveData = _yearlyLeaveData!.where((report) => report.leaveType == 'Annual Leave').toList();
    if (annualLeaveData.isEmpty) return const Center(child: Text('No Annual Leave data found.'));

    Map<String, Map<String, double>> aggregatedData = {};
    for (var report in annualLeaveData) {
        aggregatedData.putIfAbsent(report.employeeName, () => {'taken': 0, 'carry_forward': 0, 'expired': 0});
        aggregatedData[report.employeeName]!['taken'] = (aggregatedData[report.employeeName]!['taken'] ?? 0) + report.leavesTaken;
        if (report.isCarryForward == 1) {
            aggregatedData[report.employeeName]!['carry_forward'] = (aggregatedData[report.employeeName]!['carry_forward'] ?? 0) + report.openingBalance;
        }
        aggregatedData[report.employeeName]!['expired'] = (aggregatedData[report.employeeName]!['expired'] ?? 0) + report.leavesExpired;
    }
    
    final chartData = aggregatedData.entries.toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = chartData.length * (15 * 3 + 20.0);
    final maxVal = chartData.expand((e) => [e.value['taken']!, e.value['carry_forward']!, e.value['expired']!]).reduce((a, b) => a > b ? a : b);


    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
               width: chartWidth < screenWidth - 64 ? screenWidth - 64 : chartWidth,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final employeeName = chartData[groupIndex].key;
                        String title;
                        double value;
                        switch(rodIndex) {
                          case 0:
                            title = 'Taken';
                            value = chartData[groupIndex].value['taken']!;
                            break;
                          case 1:
                            title = 'Carried Forward';
                            value = chartData[groupIndex].value['carry_forward']!;
                            break;
                          case 2:
                            title = 'Expired';
                             value = chartData[groupIndex].value['expired']!;
                            break;
                          default:
                            return null;
                        }
                        return BarTooltipItem(
                          '$employeeName\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: '$title: ${value.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.yellow),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(chartData.length, (index) {
                    final data = chartData[index].value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(toY: data['taken']!, color: Colors.orange, width: 15),
                        BarChartRodData(toY: data['carry_forward']!, color: Colors.teal, width: 15),
                        BarChartRodData(toY: data['expired']!, color: Colors.redAccent, width: 15),
                      ],
                    );
                  }),
                   titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (value, meta) {
                           if (value.toInt() < chartData.length) return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(chartData[value.toInt()].key.split(' ').first, style: const TextStyle(fontSize: 10)));
                           return const Text('');
                      })),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade400), left: BorderSide(color: Colors.grey.shade400))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _legendItem('Taken', Colors.orange),
            _legendItem('Carried Forward', Colors.teal),
            _legendItem('Expired', Colors.redAccent),
          ],
        )
      ],
    );
  }

  Widget _buildLeaveBalanceDetailsChartContent() {
    if (_isLeaveDetailsLoading) return const Center(child: CircularProgressIndicator());
    if (_leaveDetailsData == null || _leaveDetailsData!.isEmpty) return const Center(child: Text('No data for selected filters.'));

    final annualLeaveData = _leaveDetailsData!.where((report) => report.leaveType == 'Annual Leave').toList();
    if (annualLeaveData.isEmpty) return const Center(child: Text('No Annual Leave data found.'));
    
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = annualLeaveData.length * (12 * 5 + 30.0);
    final maxVal = annualLeaveData.expand((r) => [r.openingBalance, r.leavesAllocated, r.leavesTaken, r.leavesExpired, r.closingBalance]).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
               width: chartWidth < screenWidth - 64 ? screenWidth - 64 : chartWidth,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final report = annualLeaveData[groupIndex];
                        String title;
                        double value;
                         switch(rodIndex) {
                          case 0:
                            title = 'Opening';
                            value = report.openingBalance;
                            break;
                          case 1:
                            title = 'Allocated';
                            value = report.leavesAllocated;
                            break;
                          case 2:
                            title = 'Taken';
                            value = report.leavesTaken;
                            break;
                          case 3:
                            title = 'Expired';
                            value = report.leavesExpired;
                            break;
                          case 4:
                            title = 'Closing';
                            value = report.closingBalance;
                            break;
                          default:
                            return null;
                        }
                        return BarTooltipItem(
                          '${report.employeeName}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: '$title: ${value.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.yellow),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(annualLeaveData.length, (index) {
                    final report = annualLeaveData[index];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(toY: report.openingBalance, color: Colors.blueGrey, width: 12),
                        BarChartRodData(toY: report.leavesAllocated, color: Colors.lightGreen, width: 12),
                        BarChartRodData(toY: report.leavesTaken, color: Colors.orange, width: 12),
                        BarChartRodData(toY: report.leavesExpired, color: Colors.redAccent, width: 12),
                        BarChartRodData(toY: report.closingBalance, color: Colors.purple, width: 12),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (value, meta) {
                           if (value.toInt() < annualLeaveData.length) return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(annualLeaveData[value.toInt()].employeeName.split(' ').first, style: const TextStyle(fontSize: 8)));
                           return const Text('');
                      })),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade400), left: BorderSide(color: Colors.grey.shade400))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _legendItem('Opening', Colors.blueGrey),
            _legendItem('Allocated', Colors.lightGreen),
            _legendItem('Taken', Colors.orange),
            _legendItem('Expired', Colors.redAccent),
            _legendItem('Closing', Colors.purple),
          ],
        )
      ],
    );
  }

  /// Builds the chart for Admin/Manager view (multiple employees, daily summary)
  Widget _buildAdminChart(List<EmployeeAttendanceReport> reports) {
    const double barWidth = 22.0;
    const double spaceBetweenBars = 18.0;
    final double chartWidth = reports.length * (barWidth + spaceBetweenBars);
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth < screenWidth - 64 ? screenWidth - 64 : chartWidth,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 35, // Increased for spacing
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final report = reports[groupIndex];
                  final touchedStackItem = rod.rodStackItems[rodIndex];
                  String statusText = "";
                  if (touchedStackItem.color == Colors.green) statusText = "Present: ${report.totalSummary.present} days";
                  else if (touchedStackItem.color == Colors.red) statusText = "Absent: ${report.totalSummary.absent} days";
                  else if (touchedStackItem.color == Colors.blue) statusText = "Sick Leave: ${report.totalSummary.sickLeave} days";
                  else if (touchedStackItem.color == Colors.orange) statusText = "Annual Leave: ${report.totalSummary.annualLeave} days";
                  
                  return BarTooltipItem(
                    '${report.employeeName}\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    children: [TextSpan(text: statusText, style: const TextStyle(color: Colors.yellow, fontSize: 12))],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 5,
                  getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < reports.length) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4.0,
                        child: Text(reports[index].employeeName.split(' ').first, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                left: BorderSide(color: Colors.grey.shade400, width: 2),
                top: const BorderSide(color: Colors.transparent),
                right: const BorderSide(color: Colors.transparent),
              ),
            ),
            barGroups: List.generate(reports.length, (index) {
              final report = reports[index];
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (report.totalSummary.present + report.totalSummary.absent + report.totalSummary.sickLeave + report.totalSummary.annualLeave).toDouble(),
                    width: barWidth,
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    rodStackItems: [
                      BarChartRodStackItem(0, report.totalSummary.present.toDouble(), Colors.green),
                      BarChartRodStackItem(report.totalSummary.present.toDouble(), (report.totalSummary.present + report.totalSummary.absent).toDouble(), Colors.red),
                      BarChartRodStackItem((report.totalSummary.present + report.totalSummary.absent).toDouble(), (report.totalSummary.present + report.totalSummary.absent + report.totalSummary.sickLeave).toDouble(), Colors.blue),
                      BarChartRodStackItem((report.totalSummary.present + report.totalSummary.absent + report.totalSummary.sickLeave).toDouble(), (report.totalSummary.present + report.totalSummary.absent + report.totalSummary.sickLeave + report.totalSummary.annualLeave).toDouble(), Colors.orange),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Builds the chart for a single employee view (daily summary)
  Widget _buildEmployeeChart(EmployeeAttendanceReport report) {
    final details = report.dateWiseDetail;
    final fromDate = DateTime.parse(report.fromDate);
    final toDate = DateTime.parse(report.toDate);
    final daysInRange = toDate.difference(fromDate).inDays + 1;
    const double barWidth = 18.0;
    const double spaceBetweenBars = 12.0;
    final double chartWidth = daysInRange * (barWidth + spaceBetweenBars);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth, 
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: 1,
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final day = fromDate.add(Duration(days: value.toInt()));
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4.0,
                      child: Text(day.day.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                left: const BorderSide(color: Colors.transparent),
                top: const BorderSide(color: Colors.transparent),
                right: const BorderSide(color: Colors.transparent),
              ),
            ),
            barGroups: List.generate(daysInRange, (index) {
              final date = fromDate.add(Duration(days: index));
              final dateKey = DateFormat('yyyy-MM-dd').format(date);
              final detail = details[dateKey];
              Color barColor = Colors.grey.shade300;
              if (detail != null) {
                switch (detail.status) {
                  case 'Present': barColor = Colors.green; break;
                  case 'Absent': barColor = Colors.red; break;
                  case 'On Leave':
                    if (detail.leaveType == 'Sick Leave') barColor = Colors.blue;
                    else if (detail.leaveType == 'Annual Leave') barColor = Colors.orange;
                    break;
                }
              }
              return BarChartGroupData(
                x: index,
                barRods: [BarChartRodData(toY: 1, color: barColor, width: barWidth, borderRadius: const BorderRadius.all(Radius.circular(4)))],
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Builds the chart for a single employee view (monthly summary)
  Widget _buildMonthlySummaryChart(EmployeeAttendanceReport report) {
    final monthlySummaries = report.monthlySummary.entries.toList();
    monthlySummaries.sort((a, b) => a.key.compareTo(b.key)); // Sort by month

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 35, // Increased for spacing
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 5,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < monthlySummaries.length) {
                  final monthKey = monthlySummaries[index].key;
                  final monthDate = DateFormat('yyyy-MM').parse(monthKey);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(DateFormat.MMM().format(monthDate), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade400, width: 2),
            left: BorderSide(color: Colors.grey.shade400, width: 2),
            top: const BorderSide(color: Colors.transparent),
            right: const BorderSide(color: Colors.transparent),
          ),
        ),
        barGroups: List.generate(monthlySummaries.length, (index) {
          final summary = monthlySummaries[index].value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (summary.present + summary.absent + summary.sickLeave + summary.annualLeave).toDouble(),
                width: 22,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                rodStackItems: [
                  BarChartRodStackItem(0, summary.present.toDouble(), Colors.green),
                  BarChartRodStackItem(summary.present.toDouble(), (summary.present + summary.absent).toDouble(), Colors.red),
                  BarChartRodStackItem((summary.present + summary.absent).toDouble(), (summary.present + summary.absent + summary.sickLeave).toDouble(), Colors.blue),
                  BarChartRodStackItem((summary.present + summary.absent + summary.sickLeave).toDouble(), (summary.present + summary.absent + summary.sickLeave + summary.annualLeave).toDouble(), Colors.orange),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Builds the legend for the chart colors
  Widget _buildLegend() {
    return Wrap(
      spacing: 16.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        _legendItem('Present', Colors.green),
        _legendItem('Absent', Colors.red),
        _legendItem('Sick Leave', Colors.blue),
        _legendItem('Annual Leave', Colors.orange),
        _legendItem('No Data', Colors.grey.shade300),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
