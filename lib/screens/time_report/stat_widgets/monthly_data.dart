class MonthlyData {
  final List<Map<String, dynamic>> days;
  final List<int> weekNumbers;
  final double totalHours;

  MonthlyData({
    required this.days,
    required this.weekNumbers,
    required this.totalHours,
  });
}

class ChartData {
  final List<Map<String, dynamic>> monthlyChartData;
  final List<Map<String, dynamic>> weeklyChartData;
  final double weeklyHours;

  ChartData({
    required this.monthlyChartData,
    required this.weeklyChartData,
    required this.weeklyHours,
  });
}