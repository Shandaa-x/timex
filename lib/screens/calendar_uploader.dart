import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';

class CalendarUploader {
  static Future<void> uploadCalendarDays() async {
    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final Random random = Random();

      // Generate 365 days starting from January 1, 2025
      final DateTime startDate = DateTime(2025, 1, 1);

      // Define holidays (customize these for your country/organization)
      final Set<String> holidays = {
        '2025-01-01', // New Year's Day
        '2025-02-10', // Lunar New Year
        '2025-02-11', // Lunar New Year
        '2025-02-12', // Lunar New Year
        '2025-03-08', // Women's Day
        '2025-05-01', // Labor Day
        '2025-06-01', // Children's Day
        '2025-07-11', // Naadam Day 1
        '2025-07-12', // Naadam Day 2
        '2025-07-13', // Naadam Day 3
        '2025-11-26', // Independence Day
        '2025-12-29', // Independence Day
        '2025-12-31', // New Year's Eve
      };

      print('Starting upload of 365 calendar days...');
      print('Note: Using ISO 8601 week numbering (Monday = start of week)');
      print('January 1, 2025 (Wednesday) is in Week 1');
      print('Approximately half of the days will have confirmed=false');

      // Create a list of day indices and shuffle to randomly select which days are confirmed
      List<int> dayIndices = List.generate(365, (index) => index);
      dayIndices.shuffle(random);

      // First half will be confirmed=true, second half will be confirmed=false
      Set<int> confirmedDays = dayIndices.take(182).toSet(); // 182 days confirmed
      // Remaining 183 days will be unconfirmed

      // Upload in batches to avoid timeout
      const int batchSize = 50;
      int uploadedCount = 0;
      int confirmedCount = 0;
      int unconfirmedCount = 0;

      for (int i = 0; i < 365; i += batchSize) {
        final WriteBatch batch = firestore.batch();
        final int endIndex = (i + batchSize < 365) ? i + batchSize : 365;

        for (int j = i; j < endIndex; j++) {
          final DateTime currentDate = startDate.add(Duration(days: j));
          final String documentId = _formatDateAsId(currentDate);
          final bool isHoliday = holidays.contains(documentId);

          // Determine if this day should be confirmed (roughly 50/50 split)
          final bool isConfirmed = confirmedDays.contains(j);

          if (isConfirmed) {
            confirmedCount++;
          } else {
            unconfirmedCount++;
          }

          // Calculate working hours
          double workingHours;
          if (isHoliday) {
            workingHours = 0.0;
          } else if (currentDate.weekday == 7) {
            // Sunday
            workingHours = 0.0;
          } else if (currentDate.weekday == 6) {
            // Saturday
            workingHours = 0.0; // Or set to 4.0 for half day
          } else if (currentDate.weekday == 5) {
            // Friday
            workingHours = 7.0; // Friday
          } else {
            workingHours = 8.5; // Monday-Thursday (including lunch break)
          }

          // Get ISO 8601 week number
          final int weekNumber = _getISOWeekNumber(currentDate);

          final Map<String, dynamic> dayData = {
            'confirmed': isConfirmed,
            'day': currentDate.day,
            'isHoliday': isHoliday,
            'month': currentDate.month,
            'weekNumber': weekNumber,
            'workingHours': workingHours,
            'year': currentDate.year,
          };

          // Create document with date as ID
          final DocumentReference docRef = firestore.collection('calendarDays').doc(documentId);

          batch.set(docRef, dayData);

          // Debug log for first few days
          if (j < 10) {
            print('Day ${j + 1}: ${_formatDateAsId(currentDate)} (${_getDayName(currentDate.weekday)}) = Week $weekNumber');
          }
        }

        // Commit the batch
        await batch.commit();
        uploadedCount += (endIndex - i);

        print('Uploaded batch: $uploadedCount/365 days');

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Successfully uploaded all 365 calendar days!');
      print('📊 Summary:');
      print('   - Confirmed days: $confirmedCount');
      print('   - Unconfirmed days: $unconfirmedCount');
      print('   - Total days: ${confirmedCount + unconfirmedCount}');
      print('   - Confirmed percentage: ${(confirmedCount / 365 * 100).toStringAsFixed(1)}%');

      // Print some sample week ranges for verification
      print('\n📅 Sample Week Ranges:');
      _printSampleWeeks();

    } catch (e) {
      print('❌ Error uploading calendar data: $e');
      rethrow;
    }
  }

  // Format date as YYYY-MM-DD for document ID
  static String _formatDateAsId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Calculate ISO 8601 week number
  static int _getISOWeekNumber(DateTime date) {
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
      return _getISOWeekNumber(DateTime(date.year - 1, 12, 31));
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

  // Helper function to get day name
  static String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  // Print sample week ranges for verification
  static void _printSampleWeeks() {
    final sampleDates = [
      DateTime(2025, 1, 1),   // Jan 1 (Wed) - should be Week 1
      DateTime(2025, 1, 6),   // Jan 6 (Mon) - should be Week 2
      DateTime(2025, 8, 4),   // Aug 4 (Mon) - should be Week 32
      DateTime(2025, 8, 5),   // Aug 5 (Tue) - should be Week 32
      DateTime(2025, 12, 29), // Dec 29 (Mon) - should be Week 52
    ];

    for (var date in sampleDates) {
      final weekNum = _getISOWeekNumber(date);
      print('   ${_formatDateAsId(date)} (${_getDayName(date.weekday)}) = Week $weekNum');
    }
  }
}

// Main function to run the upload
Future<void> main() async {
  print('🗓️  Uploading 365 Calendar Days to Firestore');
  print('===========================================');

  try {
    await CalendarUploader.uploadCalendarDays();
    print('🎉 Upload completed successfully!');
  } catch (e) {
    print('💥 Upload failed: $e');
  }
}