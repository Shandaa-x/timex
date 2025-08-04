import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class CalendarUploader {
  static Future<void> uploadCalendarDays() async {
    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;

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

      // Upload in batches to avoid timeout
      const int batchSize = 50;
      int uploadedCount = 0;

      for (int i = 0; i < 365; i += batchSize) {
        final WriteBatch batch = firestore.batch();
        final int endIndex = (i + batchSize < 365) ? i + batchSize : 365;

        for (int j = i; j < endIndex; j++) {
          final DateTime currentDate = startDate.add(Duration(days: j));
          final String documentId = _formatDateAsId(currentDate);
          final bool isHoliday = holidays.contains(documentId);
          final bool isWeekend = currentDate.weekday == 6 || currentDate.weekday == 7; // Sat or Sun

          // Calculate working hours
          double workingHours;
          if (isHoliday) {
            workingHours = 0.0;
          } else if (currentDate.weekday == 7) { // Sunday
            workingHours = 0.0;
          } else if (currentDate.weekday == 6) { // Saturday
            workingHours = 0.0;           // Or set to 4.0 for half day
          } else if (currentDate.weekday == 5) { // Friday
            workingHours = 7.0;           // Friday
          } else {
            workingHours = 8.5;           // Monday-Thursday (including lunch break)
          }

          final Map<String, dynamic> dayData = {
            'confirmed': true,
            'day': currentDate.day,
            'isHoliday': isHoliday,
            'month': currentDate.month,
            'weekNumber': _getWeekNumber(currentDate),
            'workingHours': workingHours,
            'year': currentDate.year,
          };

          // Create document with date as ID
          final DocumentReference docRef = firestore
              .collection('calendarDays')
              .doc(documentId);

          batch.set(docRef, dayData);
        }

        // Commit the batch
        await batch.commit();
        uploadedCount += (endIndex - i);

        print('Uploaded batch: $uploadedCount/365 days');

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Successfully uploaded all 365 calendar days!');

    } catch (e) {
      print('❌ Error uploading calendar data: $e');
      rethrow;
    }
  }

  // Format date as YYYY-MM-DD for document ID
  static String _formatDateAsId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Calculate week number of the year
  static int _getWeekNumber(DateTime date) {
    final DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    final int daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    final int firstWeekday = firstDayOfYear.weekday;
    return ((daysSinceFirstDay + firstWeekday - 1) / 7).ceil();
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