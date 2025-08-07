class TimeUtils {
  static String formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static String formatDateTime(DateTime dateTime) {
    return '${formatDateString(dateTime)} ${formatTime(dateTime)}';
  }

  static double calculateWorkingHours(DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    return duration.inMinutes / 60.0;
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}ц ${minutes}м';
  }

  static int getWeekNumber(DateTime date) {
    // Get January 1st of the year
    final jan1 = DateTime(date.year, 1, 1);

    // Find the first Monday of the year (or the Monday of the week containing Jan 1)
    final firstMonday = jan1.subtract(Duration(days: jan1.weekday - 1));

    // Special handling for 2025 - week 1 starts on December 30, 2024
    DateTime weekOneStart;
    if (date.year == 2025) {
      weekOneStart = DateTime(2024, 12, 30); // December 30, 2024
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

  static String getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'June',
      'July', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  static String getWeekdayName(int weekday) {
    const weekdays = [
      'Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'
    ];
    return weekdays[weekday - 1];
  }
}