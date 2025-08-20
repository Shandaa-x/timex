import 'monthly_data.dart';

class ChartCalculator {
  static ChartData calculateChartData(List<Map<String, dynamic>> days, int? selectedWeekNumber) {
    // Calculate monthly chart data (weeks in the selected month)
    List<Map<String, dynamic>> monthlyChartData = [];
    Map<int, double> weeklyHours = {};

    // Group hours by week number for the selected month
    for (var day in days) {
      if (day['confirmed'] && !day['isHoliday'] && day['workingHours'] > 0) {
        final weekNumber = day['weekNumber'] as int;
        weeklyHours[weekNumber] = (weeklyHours[weekNumber] ?? 0) + day['workingHours'];
      }
    }

    // Convert to chart data format
    final sortedWeeks = weeklyHours.keys.toList()..sort();
    for (var weekNumber in sortedWeeks) {
      monthlyChartData.add({'week': weekNumber, 'hours': weeklyHours[weekNumber] ?? 0.0});
    }

    // Calculate weekly chart data if a week is selected
    List<Map<String, dynamic>> weeklyChartData = [];
    double calculatedWeeklyHours = 0.0;

    if (selectedWeekNumber != null) {
      Map<int, double> dailyHours = {};

      // Group hours by day for the selected week
      for (var day in days) {
        if (day['weekNumber'] == selectedWeekNumber) {
          final dayOfMonth = day['day'] as int;
          double hours = 0.0;

          if (day['confirmed'] && !day['isHoliday'] && day['workingHours'] > 0) {
            hours = day['workingHours'];
            calculatedWeeklyHours += hours;
          }

          dailyHours[dayOfMonth] = hours;
        }
      }

      // Convert to chart data format
      final sortedDays = dailyHours.keys.toList()..sort();
      for (var dayOfMonth in sortedDays) {
        weeklyChartData.add({'day': dayOfMonth, 'hours': dailyHours[dayOfMonth] ?? 0.0});
      }
    }

    return ChartData(
      monthlyChartData: monthlyChartData,
      weeklyChartData: weeklyChartData,
      weeklyHours: calculatedWeeklyHours,
    );
  }
}