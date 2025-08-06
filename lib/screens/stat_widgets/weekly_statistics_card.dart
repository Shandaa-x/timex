import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'modern_card.dart';

class WeeklyStatisticsCard extends StatelessWidget {
  final double weeklyHours;
  final int selectedWeekNumber;
  final List<Map<String, dynamic>> chartData;

  const WeeklyStatisticsCard({
    super.key,
    required this.weeklyHours,
    required this.selectedWeekNumber,
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
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assessment, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Hours',
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
            '${weeklyHours.toStringAsFixed(0)}h',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Week $selectedWeekNumber',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 150, child: _buildWeeklyChart()),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          'No data for selected week',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    double maxHours = chartData.map((e) => e['hours'] as double).reduce((a, b) => a > b ? a : b);
    if (maxHours == 0) maxHours = 10;

    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxHours + 3,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final dayData = chartData[group.x.toInt()];
                  return BarTooltipItem(
                    'Day ${dayData['day']}\n${dayData['hours'].toStringAsFixed(1)}h',
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
                      final dayData = chartData[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${dayData['day']}',
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
                    toY: entry.value['hours'] > 0 ? entry.value['hours'] : 0.1,
                    color: entry.value['hours'] > 0 ? const Color(0xFF8B5CF6) : const Color(0xFFE5E7EB),
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
            left: (index + 0.45) * (280 / chartData.length) - 10,
            bottom: 30 + ((hours > 0 ? hours : 0.1) / (maxHours + 3)) * 120,
            child: Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(
                hours > 0 ? '${hours.toStringAsFixed(0)}h' : '0h',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: hours > 0 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}