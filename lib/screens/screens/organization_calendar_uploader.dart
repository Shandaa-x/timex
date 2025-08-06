import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class OrganizationCalendarUploader {
  static Future<void> uploadCalendarForOrganization(String organizationId) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DateTime startDate = DateTime(2025, 1, 1);

      // Define holidays
      final Set<String> holidays = {
        '2025-01-01', '2025-02-10', '2025-02-11', '2025-02-12',
        '2025-03-08', '2025-05-01', '2025-06-01', '2025-07-11',
        '2025-07-12', '2025-07-13', '2025-11-26', '2025-12-31',
      };

      print('Uploading calendar for organization: $organizationId');

      const int batchSize = 50;
      int uploadedCount = 0;

      for (int i = 0; i < 365; i += batchSize) {
        final WriteBatch batch = firestore.batch();
        final int endIndex = (i + batchSize < 365) ? i + batchSize : 365;

        for (int j = i; j < endIndex; j++) {
          final DateTime currentDate = startDate.add(Duration(days: j));
          final String documentId = _formatDateAsId(currentDate);
          final bool isHoliday = holidays.contains(documentId);
          final bool isWeekend = currentDate.weekday == 6 || currentDate.weekday == 7;

          double workingHours;
          if (isHoliday || isWeekend) {
            workingHours = 0.0;
          } else if (currentDate.weekday == 5) {
            workingHours = 6.0; // Friday
          } else {
            workingHours = 8.0; // Regular day
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

          // Upload to organizations/{orgId}/calendarDays/{date}
          final DocumentReference docRef = firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('calendarDays')
              .doc(documentId);

          batch.set(docRef, dayData);
        }

        await batch.commit();
        uploadedCount += (endIndex - i);
        print('Progress: $uploadedCount/365 days uploaded');

        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Calendar uploaded successfully for organization: $organizationId');

    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  static String _formatDateAsId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static int _getWeekNumber(DateTime date) {
    final DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    final int daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    final int firstWeekday = firstDayOfYear.weekday;
    return ((daysSinceFirstDay + firstWeekday - 1) / 7).ceil();
  }
}

// Usage example
Future<void> main() async {
  // Replace with your organization ID
  const String organizationId = 'your-organization-id-here';

  try {
    await OrganizationCalendarUploader.uploadCalendarForOrganization(organizationId);
  } catch (e) {
    print('Failed: $e');
  }
}