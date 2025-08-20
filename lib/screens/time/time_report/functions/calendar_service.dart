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
              primary: Color(0xFF3B82F6), // Blue accent matching the monthly statistics
              onPrimary: Colors.white,
              secondary: Color(0xFF3B82F6),
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
              surfaceVariant: Color(0xFFF8FAFC), // Light background
              onSurfaceVariant: Color(0xFF64748B),
              outline: Color(0xFFE2E8F0),
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineMedium: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              bodyLarge: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              bodyMedium: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF3B82F6).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              elevation: 8,
              shadowColor: Color(0x1A000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
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
