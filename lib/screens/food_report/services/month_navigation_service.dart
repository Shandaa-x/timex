class MonthNavigationService {
  // Get month name in Mongolian
  static String getMonthName(int month) {
    const months = [
      '1-р сар',
      '2-р сар',
      '3-р сар',
      '4-р сар',
      '5-р сар',
      '6-р сар',
      '7-р сар',
      '8-р сар',
      '9-р сар',
      '10-р сар',
      '11-р сар',
      '12-р сар',
    ];
    return months[month - 1];
  }

  // Navigate to previous month
  static DateTime navigateToPreviousMonth(DateTime currentMonth) {
    return DateTime(currentMonth.year, currentMonth.month - 1, 1);
  }

  // Navigate to next month
  static DateTime navigateToNextMonth(DateTime currentMonth) {
    return DateTime(currentMonth.year, currentMonth.month + 1, 1);
  }

  // Check if it's current month
  static bool isCurrentMonth(DateTime selectedMonth) {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  // Get formatted month year string
  static String getFormattedMonthYear(DateTime month) {
    return '${getMonthName(month.month)} ${month.year}';
  }

  // Get end of month date
  static DateTime getEndOfMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0);
  }

  // Get days in month
  static int getDaysInMonth(DateTime month) {
    return getEndOfMonth(month).day;
  }

  // Generate date key for a specific day
  static String generateDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Generate month key for collections
  static String generateMonthKey(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }
}
