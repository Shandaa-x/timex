void main() {
  // Test ISO 8601 week calculation for today (August 13, 2025)
  final date = DateTime(2025, 8, 13);
  
  print('Testing date: $date (${getDayName(date.weekday)})');
  print('Expected week: 33');
  
  final weekNumber = getISOWeekNumber(date);
  print('Calculated week: $weekNumber');
  
  // Test a few other dates to verify
  final testDates = [
    DateTime(2025, 1, 1),   // Jan 1 (Wed) - should be Week 1
    DateTime(2025, 1, 6),   // Jan 6 (Mon) - should be Week 2
    DateTime(2025, 8, 4),   // Aug 4 (Mon) - should be Week 32
    DateTime(2025, 8, 5),   // Aug 5 (Tue) - should be Week 32
    DateTime(2025, 8, 11),  // Aug 11 (Mon) - should be Week 33
    DateTime(2025, 8, 13),  // Aug 13 (Wed) - should be Week 33
    DateTime(2025, 12, 29), // Dec 29 (Mon) - should be Week 52
  ];
  
  for (var testDate in testDates) {
    final week = getISOWeekNumber(testDate);
    print('${formatDate(testDate)} (${getDayName(testDate.weekday)}) = Week $week');
  }
}

int getISOWeekNumber(DateTime date) {
  // ISO 8601 week numbering:
  // - Week starts on Monday (weekday 1)
  // - Week 1 is the first week with at least 4 days in the new year
  // - Week 1 contains January 4th

  // Find January 4th of the same year
  final DateTime jan4 = DateTime(date.year, 1, 4);

  // Find the Monday of the week containing January 4th
  final DateTime firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));

  // Calculate days since first Monday
  final int daysSinceFirstMonday = date.difference(firstMonday).inDays;

  // Calculate week number
  final int weekNumber = (daysSinceFirstMonday / 7).floor() + 1;

  // Handle edge cases for beginning and end of year
  if (weekNumber < 1) {
    // This date belongs to the last week of the previous year
    return getISOWeekNumber(DateTime(date.year - 1, 12, 31));
  } else if (weekNumber > 52) {
    // Check if this should be week 1 of next year
    final DateTime nextJan4 = DateTime(date.year + 1, 1, 4);
    final DateTime nextFirstMonday = nextJan4.subtract(Duration(days: nextJan4.weekday - 1));

    if (date.isAfter(nextFirstMonday) || date.isAtSameMomentAs(nextFirstMonday)) {
      return 1; // This is week 1 of next year
    } else {
      return weekNumber; // This is week 53 of current year (rare)
    }
  }

  return weekNumber;
}

String formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String getDayName(int weekday) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[weekday - 1];
}
