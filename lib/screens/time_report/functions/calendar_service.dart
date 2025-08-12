import 'package:flutter/material.dart';

class CalendarService {
  // Show calendar dialog
  static Future<DateTime?> showCalendarDialog(
    BuildContext context,
    int selectedMonth,
    int selectedYear,
    int? selectedDay,
  ) async {
    final DateTime initialDate = selectedDay != null
        ? DateTime(selectedYear, selectedMonth, selectedDay)
        : DateTime(selectedYear, selectedMonth, 1);

    final DateTime firstDate = DateTime(selectedYear, selectedMonth, 1);
    final DateTime lastDate = DateTime(selectedYear, selectedMonth + 1, 0);

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
      selectableDayPredicate: (DateTime day) {
        // Only allow days within the selected month
        return day.month == selectedMonth && day.year == selectedYear;
      },
    );

    return selectedDate;
  }
}
