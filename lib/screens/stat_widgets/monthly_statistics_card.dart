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
            '${monthlyHours.toStringAsFixed(0)}h',
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
    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          'No confirmed working hours for this month',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    double maxHours = chartData.map((e) => e['hours'] as double).reduce((a, b) => a > b ? a : b);

    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxHours + 15,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final weekData = chartData[group.x.toInt()];
                  return BarTooltipItem(
                    'Week ${weekData['week']}\n${weekData['hours'].toStringAsFixed(1)}h',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    if (value.toInt() < chartData.length) {
                      final weekData = chartData[value.toInt()];
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
            barGroups: chartData.asMap().entries.map((entry) {
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value['hours'],
                    color: const Color(0xFF059669),
                    width: 32,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        // Add text labels on top of bars
        ...chartData.asMap().entries.map((entry) {
          final index = entry.key;
          final hours = entry.value['hours'] as double;

          return Positioned(
            left: (index + 0.45) * (270 / chartData.length) - 10,
            bottom: 30 + (hours / (maxHours + 15)) * 120,
            child: Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                '${hours.toStringAsFixed(0)}h',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}