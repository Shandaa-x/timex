import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'modern_card.dart';

class WeeklyStatisticsCard extends StatelessWidget {
  final double weeklyHours;
  final int selectedWeekNumber;
  final List<Map<String, dynamic>> chartData;
  final int selectedMonth;
  final int selectedYear;

  const WeeklyStatisticsCard({
    super.key,
    required this.weeklyHours,
    required this.selectedWeekNumber,
    required this.chartData,
    required this.selectedMonth,
    required this.selectedYear,
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
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assessment,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '7 хоногийн ажилласан цаг',
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
            '${weeklyHours.toStringAsFixed(1)}ц',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$selectedWeekNumber-р долоо хоног',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 120, child: _buildWeeklyChart()),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    // Generate all days for the selected week
    List<Map<String, dynamic>> allWeekDays = _generateAllWeekDays();

    if (allWeekDays.isEmpty) {
      return const Center(
        child: Text(
          'No data for selected week',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    double maxHours = allWeekDays
        .map((e) => e['hours'] as double)
        .reduce((a, b) => a > b ? a : b);
    if (maxHours == 0) maxHours = 10;

    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxHours + 2.5,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final dayData = allWeekDays[group.x.toInt()];
                  String tooltipText = '${dayData['dayName']}\n';

                  if (dayData['isHoliday'] == true) {
                    tooltipText += 'Амралт';
                  } else if (dayData['isWeekend'] == true) {
                    tooltipText += 'Амралт';
                  } else {
                    tooltipText += '${dayData['hours'].toStringAsFixed(1)}h';
                  }

                  return BarTooltipItem(
                    tooltipText,
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
                    if (value.toInt() < allWeekDays.length) {
                      final dayData = allWeekDays[value.toInt()];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayData['dayShort'],
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${dayData['day']}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: allWeekDays.asMap().entries.map((entry) {
              final dayData = entry.value;
              final hours = dayData['hours'] as double;
              final isHoliday = dayData['isHoliday'] as bool;
              final isWeekend = dayData['isWeekend'] as bool;

              Color barColor;
              if (isHoliday || isWeekend) {
                barColor = const Color(0xFFEF4444); // Red for holidays/weekends
              } else if (hours > 0) {
                barColor = const Color(0xFF8B5CF6); // Purple for work days
              } else {
                barColor = const Color(0xFFE5E7EB); // Gray for no work
              }

              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: (isHoliday || isWeekend)
                        ? 1.0
                        : (hours > 0 ? hours : 0.5),
                    color: barColor,
                    width: 24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        // Add text labels on top of bars
        ...allWeekDays.asMap().entries.map((entry) {
          final index = entry.key;
          final dayData = entry.value;
          final hours = dayData['hours'] as double;
          final isHoliday = dayData['isHoliday'] as bool;
          final isWeekend = dayData['isWeekend'] as bool;

          String labelText;
          Color labelColor;

          if (isHoliday || isWeekend) {
            labelText = 'амралт';
            labelColor = const Color(0xFFEF4444);
          } else if (hours > 0) {
            labelText = '${hours.toStringAsFixed(1)}h';
            labelColor = const Color(0xFF8B5CF6);
          } else {
            labelText = '0h';
            labelColor = const Color(0xFF64748B);
          }

          final barHeight = (isHoliday || isWeekend)
              ? 1.0
              : (hours > 0 ? hours : 0.5);

          return Positioned(
            left: (index + 0.5) * (300 / allWeekDays.length) - 15,
            bottom: 50 + (barHeight / (maxHours + 2.5)) * 90,
            child: Container(
              width: 32,
              alignment: Alignment.center,
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  List<Map<String, dynamic>> _generateAllWeekDays() {
    // Get all days for the selected week
    final weekStart = _getWeekStartDate(selectedYear, selectedWeekNumber);

    List<Map<String, dynamic>> weekDays = [];

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));

      // Find existing data for this day
      final existingDay = chartData.firstWhere(
        (day) =>
            day['day'] == date.day &&
            date.month == selectedMonth &&
            date.year == selectedYear,
        orElse: () => {
          'day': date.day,
          'hours': 0.0,
          'isHoliday': false,
          'isWeekend': _isWeekend(date),
        },
      );

      weekDays.add({
        'day': date.day,
        'dayName': _getDayName(date.weekday),
        'dayShort': _getDayShort(date.weekday),
        'hours': (existingDay['hours'] as num).toDouble(),
        'isHoliday': existingDay['isHoliday'] ?? false,
        'isWeekend': existingDay['isWeekend'] ?? _isWeekend(date),
        'date': date,
      });
    }

    return weekDays;
  }

  DateTime _getWeekStartDate(int year, int weekNumber) {
    // Get the first day of the year
    final firstDay = DateTime(year, 1, 1);

    // Calculate the start of the given week (Monday)
    final daysToAdd = (weekNumber - 1) * 7 - (firstDay.weekday - 1);
    return firstDay.add(Duration(days: daysToAdd));
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getDayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
