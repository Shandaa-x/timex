import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timex/screens/time_track/time_utils.dart';

import 'holiday_utils.dart';

class WorkDay {
  final DateTime date;
  final int day;
  final int month;
  final int year;
  final int weekNumber;
  final bool isHoliday;
  final DateTime? startTime;
  final DateTime? endTime;
  final double workingHours;
  final bool confirmed;
  final List<String> attachmentImages;

  WorkDay({
    required this.date,
    required this.day,
    required this.month,
    required this.year,
    required this.weekNumber,
    required this.isHoliday,
    this.startTime,
    this.endTime,
    this.workingHours = 0.0,
    this.confirmed = false,
    this.attachmentImages = const [],
  });

  factory WorkDay.createNew(DateTime dateTime) {
    return WorkDay(
      date: dateTime,
      day: dateTime.day,
      month: dateTime.month,
      year: dateTime.year,
      weekNumber: TimeUtils.getWeekNumber(dateTime),
      isHoliday: HolidayUtils.isHoliday(dateTime),
      startTime: dateTime,
    );
  }

  factory WorkDay.fromMap(Map<String, dynamic> map) {
    return WorkDay(
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      day: map['day'] ?? 0,
      month: map['month'] ?? 0,
      year: map['year'] ?? 0,
      weekNumber: map['weekNumber'] ?? 0,
      isHoliday: map['isHoliday'] ?? false,
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      workingHours: (map['workingHours'] ?? 0.0).toDouble(),
      confirmed: map['confirmed'] ?? false,
      attachmentImages: List<String>.from(map['attachmentImages'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'day': day,
      'month': month,
      'year': year,
      'weekNumber': weekNumber,
      'isHoliday': isHoliday,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'workingHours': workingHours,
      'confirmed': confirmed,
      'attachmentImages': attachmentImages,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get documentId => TimeUtils.formatDateString(date);

  WorkDay copyWith({
    DateTime? date,
    int? day,
    int? month,
    int? year,
    int? weekNumber,
    bool? isHoliday,
    DateTime? startTime,
    DateTime? endTime,
    double? workingHours,
    bool? confirmed,
    List<String>? attachmentImages,
  }) {
    return WorkDay(
      date: date ?? this.date,
      day: day ?? this.day,
      month: month ?? this.month,
      year: year ?? this.year,
      weekNumber: weekNumber ?? this.weekNumber,
      isHoliday: isHoliday ?? this.isHoliday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      workingHours: workingHours ?? this.workingHours,
      confirmed: confirmed ?? this.confirmed,
      attachmentImages: attachmentImages ?? this.attachmentImages,
    );
  }
}