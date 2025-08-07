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
            '${monthlyHours.toStringAsFixed(1)}h',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
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
                    'Week ${weekData['week']}\n${weekData['hours'].toStringAsFixed(1)}h',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w100),
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
                    if (value.toInt() < allWeeksData.length) {
                      final weekData = allWeeksData[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'W${weekData['week']}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: allWeeksData.asMap().entries.map((entry) {
              final hours = entry.value['hours'] as double;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: hours > 0 ? hours : 0.5, // Show small bar for 0 hours
                    color: hours > 0 ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                    width: 32,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        // Add text labels on top of bars
        ...allWeeksData.asMap().entries.map((entry) {
          final index = entry.key;
          final hours = entry.value['hours'] as double;
          final barHeight = hours > 0 ? hours : 0.5;

          return Positioned(
            left: (index + 0.5) * (290 / allWeeksData.length) - 15,
            bottom: 30 + (barHeight / (maxHours + 5)) * 120,
            child: Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(
                '${hours.toStringAsFixed(1)}h',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: hours > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  List<Map<String, dynamic>> _generateAllWeeksData() {
    // Get all weeks in the selected month
    final lastDay = DateTime(selectedYear, selectedMonth + 1, 0);
    
    Set<int> monthWeeks = {};
    
    // Find all week numbers that occur in this month
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(selectedYear, selectedMonth, day);
      final weekNumber = _getWeekNumber(date);
      monthWeeks.add(weekNumber);
    }
    
    // Sort weeks and create data
    List<int> sortedWeeks = monthWeeks.toList()..sort();
    
    return sortedWeeks.map((weekNum) {
      // Find hours for this week from chartData
      final existingWeek = chartData.firstWhere(
        (week) => week['week'] == weekNum,
        orElse: () => {'week': weekNum, 'hours': 0.0},
      );
      
      return {
        'week': weekNum,
        'hours': (existingWeek['hours'] as num).toDouble(),
      };
    }).toList();
  }

  int _getWeekNumber(DateTime date) {
    // Get week number of year
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return weekNumber;
  }
}