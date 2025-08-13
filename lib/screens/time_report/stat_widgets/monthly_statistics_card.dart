import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'modern_card.dart';

class MonthlyStatisticsCard extends StatelessWidget {
  final double monthlyHours;
  final List<String> monthNames;
  final int selectedMonth;
  final int selectedYear;
  final List<Map<String, dynamic>> chartData;

  const MonthlyStatisticsCard({
    super.key,
    required this.monthlyHours,
    required this.monthNames,
    required this.selectedMonth,
    required this.selectedYear,
    required this.chartData,
  });

  String formatMongolianHours(double hours) {
    final int h = hours.floor();
    final int m = ((hours - h) * 60).round();
    if (h > 0 && m > 0) return '$h цаг, $m минут';
    if (h > 0) return '$h цаг';
    return '$h цаг, $m минут';
  }

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Monthly Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatMongolianHours(monthlyHours),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total for ${monthNames[selectedMonth - 1]} $selectedYear',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 150, child: _buildMonthlyChart()),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    // Generate all weeks for the selected month
    List<Map<String, dynamic>> allWeeksData = _generateAllWeeksData();

    if (allWeeksData.isEmpty) {
      return const Center(
        child: Text(
          'No data available for this month',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    double maxHours = allWeeksData.map((e) => e['hours'] as double).reduce((a, b) => a > b ? a : b);
    if (maxHours == 0) maxHours = 10; // Set minimum scale

    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxHours + 5,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final weekData = allWeeksData[group.x.toInt()];
                  return BarTooltipItem(
                    'Week ${weekData['week']}\n${formatMongolianHours(weekData['hours'])}',
                    const TextStyle(color: Colors.black, fontWeight: FontWeight.w100),
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
                    final index = value.toInt();
                    if (index >= 0 && index < allWeeksData.length) {
                      return Text(
                        'W${allWeeksData[index]['week']}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      );
                    }
                    return const Text('');
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: 10,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: const Color(0xFFE2E8F0),
                  strokeWidth: 1,
                );
              },
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            barGroups: allWeeksData.asMap().entries.map((entry) {
              final index = entry.key;
              final weekData = entry.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: weekData['hours'].toDouble(),
                    color: const Color(0xFF059669),
                    width: 16,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateAllWeeksData() {
    // Create a map to group chart data by week
    Map<int, double> weekHours = {};

    for (final item in chartData) {
      final week = item['week'] as int;
      final hours = (item['hours'] as num).toDouble();
      weekHours[week] = (weekHours[week] ?? 0.0) + hours;
    }

    // Get the first and last week of the month
    final firstDayOfMonth = DateTime(selectedYear, selectedMonth, 1);
    final lastDayOfMonth = DateTime(selectedYear, selectedMonth + 1, 0);

    final firstWeek = _getWeekNumber(firstDayOfMonth);
    final lastWeek = _getWeekNumber(lastDayOfMonth);

    // Generate data for all weeks in the range
    List<Map<String, dynamic>> allWeeksData = [];
    
    if (firstWeek <= lastWeek) {
      // Normal case - all weeks are in the same year
      for (int week = firstWeek; week <= lastWeek; week++) {
        allWeeksData.add({
          'week': week,
          'hours': weekHours[week] ?? 0.0,
        });
      }
    } else {
      // Year boundary case - first week is in previous year
      // Add weeks from first week to end of year (typically week 52 or 53)
      for (int week = firstWeek; week <= 53; week++) {
        allWeeksData.add({
          'week': week,
          'hours': weekHours[week] ?? 0.0,
        });
      }
      // Add weeks from start of new year to last week
      for (int week = 1; week <= lastWeek; week++) {
        allWeeksData.add({
          'week': week,
          'hours': weekHours[week] ?? 0.0,
        });
      }
    }

    return allWeeksData;
  }

  int _getWeekNumber(DateTime date) {
    // Special handling for 2025 - week 1 starts on December 30, 2024
    DateTime weekOneStart;
    if (date.year == 2025) {
      weekOneStart = DateTime(2024, 12, 30);
    } else {
      // For other years, use standard ISO week calculation
      final jan4 = DateTime(date.year, 1, 4);
      final firstWeekStart = jan4.subtract(Duration(days: jan4.weekday - 1));
      weekOneStart = firstWeekStart;
    }

    // Calculate week number
    final daysSinceWeekOne = date.difference(weekOneStart).inDays;
    final weekNumber = (daysSinceWeekOne / 7).floor() + 1;

    // Ensure week number is at least 1
    return weekNumber < 1 ? 1 : weekNumber;
  }
}