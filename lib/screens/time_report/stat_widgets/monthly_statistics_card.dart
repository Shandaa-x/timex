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
                'Сарын ажилласан цаг',
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
            '${monthNames[selectedMonth - 1]} $selectedYear: Нийт ажилласан цаг',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 250, child: _buildMonthlyChart()),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '7 хоногууд',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildWeeklyStatistics(),
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
            maxY: 50, // Fixed scale from 0 to 50 hours
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final weekData = allWeeksData[group.x.toInt()];
                  final dateRange = _getWeekDateRange(weekData['week']);
                  return BarTooltipItem(
                    'Week ${weekData['week']} ($dateRange)\n${formatMongolianHours(weekData['hours'])}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
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
                      final weekData = allWeeksData[index];
                      final dateRange = _getWeekDateRange(weekData['week']);
                      return Transform.rotate(
                        angle: -0.4, // 45 degrees in radians
                        child: Text(
                          dateRange,
                          style: const TextStyle(
                            color: Color(0xFF64748B), 
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                  reservedSize: 50, // Increased for diagonal text
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: 10, // Show every 10 hours
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
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
              final hours = weekData['hours'].toDouble();
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: hours,
                    color: const Color(0xFF059669),
                    width: 24, // Increased width from 16 to 24
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
            // Add text above bars showing the hours
            extraLinesData: ExtraLinesData(
              horizontalLines: [],
              verticalLines: [],
            ),
          ),
        ),
        // Overlay to show hours on top of bars
        // Positioned.fill(
        //   child: CustomPaint(
        //     painter: BarTextPainter(allWeeksData),
        //   ),
        // ),
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

  String _getWeekDateRange(int weekNumber) {
    // Calculate the start date of the week
    DateTime weekOneStart;
    if (selectedYear == 2025) {
      weekOneStart = DateTime(2024, 12, 30);
    } else {
      final jan4 = DateTime(selectedYear, 1, 4);
      weekOneStart = jan4.subtract(Duration(days: jan4.weekday - 1));
    }

    final weekStart = weekOneStart.add(Duration(days: (weekNumber - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Format the date range as MM.DD - MM.DD
    final startMonth = weekStart.month.toString().padLeft(2, '0');
    final startDay = weekStart.day.toString().padLeft(2, '0');
    final endMonth = weekEnd.month.toString().padLeft(2, '0');
    final endDay = weekEnd.day.toString().padLeft(2, '0');

    return '$startMonth.$startDay - $endMonth.$endDay';
  }

  Widget _buildWeeklyStatistics() {
    final allWeeksData = _generateAllWeeksData();
    
    if (allWeeksData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_view_week,
                size: 16,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              const Text(
                'Weekly Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...allWeeksData.map((weekData) {
            final weekNumber = weekData['week'] as int;
            final hours = weekData['hours'] as double;
            final dateRange = _getWeekDateRange(weekNumber);
            
            if (hours == 0) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$weekNumber-р долоо хоног',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Text(
                          dateRange,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      formatMongolianHours(hours),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (allWeeksData.every((week) => week['hours'] == 0))
            const Center(
              child: Text(
                'No working hours recorded this month',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BarTextPainter extends CustomPainter {
  final List<Map<String, dynamic>> weekData;

  BarTextPainter(this.weekData);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final chartWidth = size.width;
    final chartHeight = size.height;
    final barCount = weekData.length;
    
    if (barCount == 0) return;

    final barSpacing = chartWidth / barCount;
    
    for (int i = 0; i < weekData.length; i++) {
      final hours = weekData[i]['hours'] as double;
      
      if (hours > 0) {
        // Calculate bar position
        final barCenterX = (i + 0.5) * barSpacing;
        final barTopY = chartHeight - (chartHeight * (hours / 50)); // 50 is maxY
        
        // Format hours text
        String hoursText;
        if (hours >= 1) {
          hoursText = '${hours.floor()}ц';
          if (hours % 1 != 0) {
            final minutes = ((hours % 1) * 60).round();
            hoursText += ' ${minutes}м';
          }
        } else {
          final minutes = (hours * 60).round();
          hoursText = '${minutes}м';
        }
        
        textPainter.text = TextSpan(
          text: hoursText,
          style: const TextStyle(
            color: Color(0xFF059669),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        
        textPainter.layout();
        
        // Position text above the bar
        final textX = barCenterX - (textPainter.width / 2);
        final textY = barTopY - textPainter.height - 4;
        
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}