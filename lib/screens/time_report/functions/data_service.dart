import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to get current week number (ISO 8601 week numbering)
  static int getCurrentWeekNumber() {
    final date = DateTime.now();

    // ISO 8601 week numbering:
    // - Week starts on Monday (weekday 1)
    // - Week 1 is the first week with at least 4 days in the new year
    // - Week 1 contains January 4th

    // Find January 4th of the same year
    final DateTime jan4 = DateTime(date.year, 1, 4);

    // Find the Monday of the week containing January 4th
    final DateTime firstMonday = jan4.subtract(
      Duration(days: jan4.weekday - 1),
    );

    // Calculate days since first Monday
    final int daysSinceFirstMonday = date.difference(firstMonday).inDays;

    // Calculate week number
    final int weekNumber = (daysSinceFirstMonday / 7).floor() + 1;

    // Handle edge cases for beginning and end of year
    if (weekNumber < 1) {
      // This date belongs to the last week of the previous year
      return 1; // Simplified handling
    } else if (weekNumber > 52) {
      // Check if this should be week 1 of next year
      final DateTime nextJan4 = DateTime(date.year + 1, 1, 4);
      final DateTime nextFirstMonday = nextJan4.subtract(
        Duration(days: nextJan4.weekday - 1),
      );

      if (date.isAfter(nextFirstMonday) ||
          date.isAtSameMomentAs(nextFirstMonday)) {
        return 1; // This is week 1 of next year
      } else {
        return weekNumber; // This is week 53 of current year (rare)
      }
    }

    return weekNumber;
  }

  // Load monthly data
  static Future<Map<String, dynamic>> loadMonthlyData(
    String userId,
    int selectedMonth,
    int selectedYear,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendarDays')
          .where('month', isEqualTo: selectedMonth)
          .where('year', isEqualTo: selectedYear)
          .get();

      debugPrint(
        'Found ${querySnapshot.docs.length} documents for month $selectedMonth',
      );

      final List<Map<String, dynamic>> processedDays = [];
      double totalWorkedHours = 0.0;
      Set<int> weekNumbers = {};

      for (final doc in querySnapshot.docs) {
        final calendarDay = doc.data();
        final dateString = doc.id;

        debugPrint('Processing day: $dateString, data: $calendarDay');

        // Check if there are time entries for this day to determine if work was actually done
        final timeEntriesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('calendarDays')
            .doc(dateString)
            .collection('timeEntries')
            .get();

        // Check if there's at least one check-out entry (indicating work was completed)
        bool hasWorkEnded = false;
        if (timeEntriesSnapshot.docs.isNotEmpty) {
          final entries = timeEntriesSnapshot.docs
              .map((doc) => doc.data())
              .toList();
          entries.sort((a, b) {
            final timestampA = (a['timestamp'] as Timestamp).toDate();
            final timestampB = (b['timestamp'] as Timestamp).toDate();
            return timestampA.compareTo(timestampB);
          });

          // Check if the last entry is a check-out type
          if (entries.isNotEmpty) {
            final lastEntry = entries.last;
            hasWorkEnded =
                lastEntry['type'] == 'check_out' ||
                lastEntry['type'] == 'auto_check_out';
          }
        }

        final Map<String, dynamic> dayData = {
          'date': dateString,
          'day': calendarDay['day'],
          'weekNumber': calendarDay['weekNumber'],
          'workingHours': calendarDay['workingHours']?.toDouble() ?? 0.0,
          'confirmed': calendarDay['confirmed'] ?? false,
          'isHoliday': calendarDay['isHoliday'] ?? false,
          'attachmentImages': calendarDay['attachmentImages'] ?? [],
          'hasWorkEnded': hasWorkEnded,
        };

        // Only count confirmed days that are not holidays and have working hours
        if (dayData['confirmed'] &&
            !dayData['isHoliday'] &&
            dayData['workingHours'] > 0) {
          totalWorkedHours += dayData['workingHours'];
        }

        if (calendarDay['weekNumber'] != null) {
          weekNumbers.add(calendarDay['weekNumber']);
        }
        processedDays.add(dayData);
      }

      processedDays.sort((a, b) => a['date'].compareTo(b['date']));

      return {
        'days': processedDays,
        'weekNumbers': weekNumbers.toList()..sort(),
        'totalHours': totalWorkedHours,
      };
    } catch (e) {
      debugPrint('Error loading monthly data: $e');
      throw e;
    }
  }

  // Load single day data
  static Future<Map<String, dynamic>?> loadSelectedDayData(
    String userId,
    int selectedDay,
    int selectedMonth,
    int selectedYear,
  ) async {
    final dateString =
        '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${selectedDay.toString().padLeft(2, '0')}';

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendarDays')
          .doc(dateString)
          .get();

      if (doc.exists) {
        final calendarDay = doc.data()!;

        // Check for time entries
        final timeEntriesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('calendarDays')
            .doc(dateString)
            .collection('timeEntries')
            .get();

        bool hasWorkEnded = false;
        if (timeEntriesSnapshot.docs.isNotEmpty) {
          final entries = timeEntriesSnapshot.docs
              .map((doc) => doc.data())
              .toList();
          entries.sort((a, b) {
            final timestampA = (a['timestamp'] as Timestamp).toDate();
            final timestampB = (b['timestamp'] as Timestamp).toDate();
            return timestampA.compareTo(timestampB);
          });

          if (entries.isNotEmpty) {
            final lastEntry = entries.last;
            hasWorkEnded =
                lastEntry['type'] == 'check_out' ||
                lastEntry['type'] == 'auto_check_out';
          }
        }

        return {
          'date': dateString,
          'day': calendarDay['day'],
          'weekNumber': calendarDay['weekNumber'],
          'workingHours': calendarDay['workingHours']?.toDouble() ?? 0.0,
          'confirmed': calendarDay['confirmed'] ?? false,
          'isHoliday': calendarDay['isHoliday'] ?? false,
          'attachmentImages': calendarDay['attachmentImages'] ?? [],
          'hasWorkEnded': hasWorkEnded,
        };
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error loading day data: $e');
      return null;
    }
  }

  // Load eaten food data for the selected month
  static Future<Map<String, bool>> loadEatenFoodData(
    String userId,
    int selectedMonth,
    int selectedYear,
  ) async {
    try {
      final Map<String, bool> eatenForDayData = {};

      final endOfMonth = DateTime(selectedYear, selectedMonth + 1, 0);
      final startDocId =
          '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-01';
      final endDocId =
          '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}';

      // Use range query to get all calendar days for the month
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('calendarDays')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get();

      // Process the results
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        eatenForDayData[dateKey] = data['eatenForDay'] as bool? ?? false;
      }

      // Fill in missing days with false (not eaten)
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dateKey =
            '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        eatenForDayData[dateKey] ??= false;
      }

      return eatenForDayData;
    } catch (e) {
      debugPrint('Error loading eaten food data: $e');
      return {};
    }
  }
}
