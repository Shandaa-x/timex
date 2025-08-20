import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timex/screens/main/home/widgets/custom_sliver_appbar.dart';
import 'package:timex/screens/time/time_track/widgets/status_card.dart';
import 'package:timex/screens/time/time_track/widgets/time_display_card.dart';
import 'package:timex/screens/time/time_track/widgets/time_utils.dart';
import 'package:timex/screens/time/time_track/widgets/work_day.dart';
import 'package:timex/screens/time/time_track/widgets/working_hours_card.dart';
import 'package:timex/screens/time/time_track/widgets/map_widget.dart';
import 'package:timex/screens/time/time_track/widgets/time_entries_list_widget.dart';
import 'package:timex/screens/time/time_track/widgets/food_eaten_status_widget.dart';
import 'package:timex/screens/time/time_track/widgets/schedule_info_widget.dart';
import 'package:timex/screens/time/time_track/widgets/location_map_dialog.dart';
import 'package:timex/widgets/custom_drawer.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/action_button.dart';

class TimeTrackScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const TimeTrackScreen({super.key, this.onNavigateToTab});

  @override
  State<TimeTrackScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Set work end time to 1:50 PM (13:50)
  static const int workEndHour = 17;
  static const int workEndMinute = 00;

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isWorking = false;
  bool _isLoading = false;
  WorkDay? _todayData;
  DateTime? _scheduledEndTime;

  // Multiple check-ins/check-outs with location tracking
  List<Map<String, dynamic>> _todayEntries = [];
  Position? _currentLocation;

  // Food data for today
  List<Map<String, dynamic>> _todayFoods = [];
  bool _eatenForToday = false; // Track if food was eaten today
  double _totalWorkingHours = 0.0; // Track total working hours for the day

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Auto-end work tracking
  bool _manuallyEndedWork = false;
  Timer? _autoEndTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupAnimations();
    _loadTodayData();
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      // Request notification permission
      await Permission.notification.request();

      // Request location permissions
      await Permission.location.request();
      await Permission.locationWhenInUse.request();

      // For Android 12+, request exact alarm permission
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      print('📱 Exact alarm permission status: $exactAlarmStatus');

      if (exactAlarmStatus.isDenied) {
        print('📱 Requesting exact alarm permission...');
        final result = await Permission.scheduleExactAlarm.request();
        print('📱 Exact alarm permission result: $result');
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  // Helper method to ensure calendar day document exists
  Future<void> _ensureCalendarDayExists(String dateString) async {
    final calendarDayRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('calendarDays')
        .doc(dateString);
    final calendarDayDoc = await calendarDayRef.get();

    if (!calendarDayDoc.exists) {
      // Create the calendar day document first
      final now = DateTime.now();
      final workDay = WorkDay.createNew(now);
      await calendarDayRef.set(workDay.toMap());
      debugPrint('✅ Created calendar day document: $dateString');
    }
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final dateString = TimeUtils.formatDateString(now);

      // Load today's entries (no user filter needed)
      final entriesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(dateString)
          .collection('timeEntries')
          .get();

      _todayEntries = entriesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by timestamp on client side to avoid index requirement
      _todayEntries.sort((a, b) {
        final timestampA = (a['timestamp'] as Timestamp).toDate();
        final timestampB = (b['timestamp'] as Timestamp).toDate();
        return timestampA.compareTo(timestampB);
      });

      // Load today's foods
      await _loadTodayFoods(dateString);

      // Determine current status
      if (_todayEntries.isNotEmpty) {
        final lastEntry = _todayEntries.last;
        _isWorking = lastEntry['type'] == 'check_in';

        if (_isWorking) {
          _startTime = (lastEntry['timestamp'] as Timestamp).toDate();
          _endTime = null;
          _scheduledEndTime = _getScheduledEndTime(_startTime!);
        } else {
          _startTime = _todayEntries.isNotEmpty
              ? (_todayEntries.first['timestamp'] as Timestamp).toDate()
              : null;
          _endTime = (lastEntry['timestamp'] as Timestamp).toDate();
          _scheduledEndTime = null;
        }
      }

      // Calculate total working hours from all entries
      _totalWorkingHours = _calculateTotalWorkingHours(
        _todayEntries,
        currentSessionStart: _isWorking ? _startTime : null,
      );

      // Also load legacy calendar data for compatibility
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(dateString)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _todayData = WorkDay.fromMap(data);
        _eatenForToday = data['eatenForDay'] as bool? ?? false;
      } else {
        _eatenForToday = false;
      }

      // Schedule daily food notification
      await _scheduleFoodNotification();
    } catch (e) {
      debugPrint('Error loading today data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodayFoods(String dateString) async {
    try {
      final foodDocId = '$dateString-foods';
      final foodDoc = await _firestore.collection('foods').doc(foodDocId).get();

      if (foodDoc.exists) {
        final data = foodDoc.data();
        if (data != null && data['foods'] != null) {
          _todayFoods = List<Map<String, dynamic>>.from(data['foods']);
        } else {
          _todayFoods = [];
        }
      } else {
        _todayFoods = [];
      }
    } catch (e) {
      debugPrint('Error loading today foods: $e');
      _todayFoods = [];
    }
  }

  Future<void> _scheduleFoodNotification() async {
    try {
      final now = DateTime.now();
      final foodTime = DateTime(now.year, now.month, now.day, 17, 0); // 5:00 PM

      // Only schedule if it's in the future
      if (foodTime.isAfter(now)) {
        await _scheduleNotification(
          id: 100, // Different ID from work notifications
          title: '🍽️ Хоолны цаг болжээ!',
          body: 'Өнөөдрийн хоолоо идэж, аппликэйшнд бүртгээрэй!',
          scheduledTime: foodTime,
        );
        print('📅 Scheduled food notification for: $foodTime');
      }
    } catch (e) {
      print('❌ Error scheduling food notification: $e');
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorMessage('Байршлын зөвшөөрөл хэрэгтэй байна');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorMessage(
          'Байршлын зөвшөөрөл байнга татгалзсан байна. Тохиргооноос нээнэ үү.',
        );
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      _showErrorMessage('Байршил авахад алдаа гарлаа: $e');
      return null;
    }
  }

  DateTime _getScheduledEndTime(DateTime startTime) {
    return DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      workEndHour,
      workEndMinute,
    );
  }

  Future<void> _scheduleEndWorkNotifications(DateTime endTime) async {
    try {
      // Cancel any existing notifications
      await _cancelScheduledNotifications();

      final now = DateTime.now();

      // Schedule 10-minute warning
      final tenMinutesBefore = endTime.subtract(const Duration(minutes: 10));
      if (tenMinutesBefore.isAfter(now)) {
        await _scheduleNotification(
          id: 1,
          title: '⏰ Ажил дуусахад 10 минут үлдлээ',
          body: 'Таны ажлын цаг 13:50 цагт дуусна. Бэлдэхээ мартуузай!',
          scheduledTime: tenMinutesBefore,
        );
        print('📅 Scheduled 10-minute notification for: $tenMinutesBefore');
      }

      // Schedule 5-minute warning
      final fiveMinutesBefore = endTime.subtract(const Duration(minutes: 5));
      if (fiveMinutesBefore.isAfter(now)) {
        await _scheduleNotification(
          id: 2,
          title: '🚨 Ажил дуусахад 5 минут үлдлээ',
          body: 'Таны ажлын цаг удахгүй дуусна. Ажлаа дуусгахаа мартуузай!',
          scheduledTime: fiveMinutesBefore,
        );
        print('📅 Scheduled 5-minute notification for: $fiveMinutesBefore');
      }

      // Schedule final notification at end time
      if (endTime.isAfter(now)) {
        await _scheduleNotification(
          id: 3,
          title: '🎯 Ажлын цаг дууслаа',
          body:
              'Таны ажлын цаг дууслаа! "ЯВЛАА" товчийг дарж ажлаа дуусгаарай.',
          scheduledTime: endTime,
        );
        print('📅 Scheduled end-time notification for: $endTime');
      }
    } catch (e) {
      print('❌ Error scheduling notifications: $e');
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      // Try exact scheduling first
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'work_schedule_channel',
            'Work Schedule Notifications',
            channelDescription: 'Notifications for work schedule reminders',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            autoCancel: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('✅ Successfully scheduled exact notification $id');
    } catch (e) {
      print('⚠️ Exact scheduling failed, trying fallback: $e');
      // Try fallback scheduling
      await _scheduleNotificationFallback(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
      );
    }
  }

  Future<void> _scheduleNotificationFallback({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'work_schedule_channel',
            'Work Schedule Notifications',
            channelDescription: 'Notifications for work schedule reminders',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock, // Fallback mode
      );
      print('✅ Successfully scheduled fallback notification $id');
    } catch (e) {
      print('❌ Fallback scheduling also failed: $e');
      _showErrorMessage(
        'সুনোটিফিकेশন সেট করতে পারলাম না। Settings এ গিয়ে exact alarm permission চালু করুন।',
      );
    }
  }

  Future<void> _cancelScheduledNotifications() async {
    try {
      // Cancel specific work-related notifications
      await _notificationsPlugin.cancel(1); // 10-minute warning
      await _notificationsPlugin.cancel(2); // 5-minute warning
      await _notificationsPlugin.cancel(3); // End time notification
      await _notificationsPlugin.cancel(100); // Food notification
      print('✅ Cancelled scheduled notifications');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }

  // Helper to get current user ID
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  Future<void> _handleStartWork() async {
    print('🚀 Starting work process...');
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final dateString = TimeUtils.formatDateString(now);
      print('📅 Working with date: $dateString');

      // Get current location
      print('📍 Getting current location...');
      final location = await _getCurrentLocation();
      if (location == null) {
        print('❌ Location is null, aborting');
        setState(() => _isLoading = false);
        return;
      }
      print('✅ Location obtained: ${location.latitude}, ${location.longitude}');

      // Ensure calendar day document exists
      print('📝 Ensuring calendar day exists...');
      await _ensureCalendarDayExists(dateString);
      print('✅ Calendar day document ready');

      // Create time entry for check-in (no userId needed)
      final timeEntryData = {
        'date': dateString,
        'timestamp': Timestamp.fromDate(now),
        'type': 'check_in',
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to timeEntries subcollection
      print('💾 Saving time entry to Firestore...');
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('calendarDays')
            .doc(dateString)
            .collection('timeEntries')
            .add(timeEntryData);
        print('✅ Successfully saved check-in time entry to Firestore');
      } catch (firestoreError) {
        print('❌ Firestore error during check-in: $firestoreError');
        _showErrorMessage('Өгөгдөл хадгалахад алдаа гарлаа: $firestoreError');
        setState(() => _isLoading = false);
        return;
      }

      // Update calendar day - add to existing hours instead of overwriting
      print('📝 Updating calendar day document...');
      final workDay = WorkDay.createNew(now);
      final existingDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(workDay.documentId)
          .get();

      if (existingDoc.exists) {
        // Update existing document - don't overwrite
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('calendarDays')
            .doc(workDay.documentId)
            .update({
              'lastCheckIn': Timestamp.fromDate(now),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        print('✅ Updated existing calendar day document');
      } else {
        // Create new document
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('calendarDays')
            .doc(workDay.documentId)
            .set(workDay.toMap());
        print('✅ Created new calendar day document');
      }

      // Calculate scheduled end time
      final scheduledEndTime = _getScheduledEndTime(now);

      setState(() {
        _startTime = now;
        _endTime = null;
        _isWorking = true;
        _todayData = workDay;
        _scheduledEndTime = scheduledEndTime;
        _currentLocation = location;
        _manuallyEndedWork = false;
      });

      // Reload entries to show the new check-in and update total working hours
      print('🔄 Reloading today\'s data...');
      await _loadTodayData();
      print('✅ Data reloaded successfully');

      // Schedule notifications
      print('⏰ Scheduling notifications...');
      await _scheduleEndWorkNotifications(scheduledEndTime);

      // Schedule auto-end work at 10 PM
      _scheduleAutoEndWork();

      _showSuccessMessage(
        'Ажилд ирлээ! 🎉\nБайршил: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      );
      print('🎉 Work started successfully!');
    } catch (e) {
      print('❌ Error starting work: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      _showErrorMessage('Алдаа гарлаа: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEndWork() async {
    if (_startTime == null) return;

    // Mark that user manually ended work
    _manuallyEndedWork = true;
    _autoEndTimer?.cancel(); // Cancel auto-end timer

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final dateString = TimeUtils.formatDateString(now);

      // Get current location
      final location = await _getCurrentLocation();
      if (location == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Ensure calendar day document exists
      await _ensureCalendarDayExists(dateString);

      // Create time entry for check-out (no userId needed)
      final timeEntryData = {
        'date': dateString,
        'timestamp': Timestamp.fromDate(now),
        'type': 'check_out',
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
        'autoEnded': false, // Flag to indicate this was manual
        'manualLeave': true, // Flag to indicate user clicked ЯВЛАА
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to timeEntries subcollection
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('calendarDays')
            .doc(dateString)
            .collection('timeEntries')
            .add(timeEntryData);
        debugPrint('✅ Successfully saved check-out time entry to Firestore');
      } catch (firestoreError) {
        debugPrint('❌ Firestore error during check-out: $firestoreError');
        _showErrorMessage('Өгөгдөл хадгалахад алдаа гарлаа: $firestoreError');
        setState(() => _isLoading = false);
        return;
      }

      // Update calendar day - calculate total working hours from all entries
      final allEntries = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(dateString)
          .collection('timeEntries')
          .get();

      // Convert to list and sort by timestamp
      final entryDocs = allEntries.docs.toList();
      entryDocs.sort((a, b) {
        final timestampA = (a.data()['timestamp'] as Timestamp).toDate();
        final timestampB = (b.data()['timestamp'] as Timestamp).toDate();
        return timestampA.compareTo(timestampB);
      });

      // Convert to our format for calculation
      final allEntriesData = entryDocs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      final totalHours = _calculateTotalWorkingHours(allEntriesData);

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(dateString)
          .update({
            'endTime': Timestamp.fromDate(now),
            'workingHours': totalHours,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Cancel all scheduled notifications since work ended
      await _cancelScheduledNotifications();

      setState(() {
        _endTime = now;
        _isWorking = false;
        _scheduledEndTime = null;
        _currentLocation = location;
        _totalWorkingHours = totalHours;
        if (_todayData != null) {
          _todayData = _todayData!.copyWith(
            endTime: now,
            workingHours: totalHours,
          );
        }
      });

      // Reload entries to show the new check-out
      await _loadTodayData();

      _showSuccessMessage(
        'Ажлаас явлаа! Та ${totalHours.toStringAsFixed(1)} цаг ажилласан байна. 👋\nБайршил: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      print('❌ Error ending work: $e');
      _showErrorMessage('Ажлаас гарахад алдаа гарлаа: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAdditionalCheckIn() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final dateString = TimeUtils.formatDateString(now);

      // Get current location
      final location = await _getCurrentLocation();
      if (location == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Ensure calendar day document exists
      await _ensureCalendarDayExists(dateString);

      // Create time entry for additional check-in (no userId needed)
      final timeEntryData = {
        'date': dateString,
        'timestamp': Timestamp.fromDate(now),
        'type': 'check_in',
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to timeEntries subcollection
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('calendarDays')
            .doc(dateString)
            .collection('timeEntries')
            .add(timeEntryData);
        debugPrint(
          '✅ Successfully saved additional check-in time entry to Firestore',
        );
      } catch (firestoreError) {
        debugPrint(
          '❌ Firestore error during additional check-in: $firestoreError',
        );
        _showErrorMessage('Өгөгдөл хадгалахад алдаа гарлаа: $firestoreError');
        setState(() => _isLoading = false);
        return;
      }

      // Calculate scheduled end time
      final scheduledEndTime = _getScheduledEndTime(now);

      setState(() {
        _startTime = now;
        _endTime = null;
        _isWorking = true;
        _scheduledEndTime = scheduledEndTime;
        _currentLocation = location;
      });

      // Reload entries to show the new check-in and update total working hours
      await _loadTodayData();

      // Schedule notifications
      await _scheduleEndWorkNotifications(scheduledEndTime);

      _showSuccessMessage(
        'Дахин ажилд ирлээ! 🎉\nБайршил: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      print('❌ Error with additional check-in: $e');
      _showErrorMessage('Алдаа гарлаа: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLocationOnMap(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => LocationMapDialog(location: location),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _scheduleAutoEndWork() {
    // Cancel any existing timer
    _autoEndTimer?.cancel();

    final now = DateTime.now();
    final autoEndTime = DateTime(
      now.year,
      now.month,
      now.day,
      22,
      0,
    ); // 10:00 PM

    if (autoEndTime.isAfter(now)) {
      final duration = autoEndTime.difference(now);
      _autoEndTimer = Timer(duration, () {
        if (_isWorking && !_manuallyEndedWork) {
          _handleAutoEndWork();
        }
      });
      print('📅 Scheduled auto-end work for: $autoEndTime');
    }
  }

  Future<void> _handleAutoEndWork() async {
    if (!_isWorking || _startTime == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final autoEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        22,
        0,
      ); // 10:00 PM
      final startDate = TimeUtils.formatDateString(
        _startTime!,
      ); // Use start date, not auto-end date

      // Ensure calendar day document exists
      await _ensureCalendarDayExists(startDate);

      // Get current location (or use last known location)
      Position? location = await _getCurrentLocation();

      // If location fails, use a default/last known location
      location ??= Position(
        latitude: 47.9184, // Default Ulaanbaatar coordinates
        longitude: 106.9177,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      // Create time entry for automatic check-out - but keep it on the same day as check-in
      final timeEntryData = {
        'date': startDate, // Use the same date as when work started
        'timestamp': Timestamp.fromDate(autoEndTime),
        'type': 'auto_check_out', // Different type to track auto end
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
        'autoEnded': true, // Flag to indicate this was automatic
        'manualLeave': false, // Flag to indicate user didn't click ЯВЛАА
        'incompleteWork': true, // Flag to indicate work was not properly closed
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to timeEntries subcollection
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(startDate)
          .collection('timeEntries')
          .add(timeEntryData);

      // Update calendar day to mark as incomplete
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(startDate)
          .update({
            'endTime': Timestamp.fromDate(autoEndTime),
            'incompleteWork': true, // Mark as incomplete work
            'autoEnded': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update UI state - but don't mark as fully ended
      setState(() {
        _endTime = autoEndTime;
        _isWorking = false;
      });

      // Calculate total working hours
      final totalHours = autoEndTime.difference(_startTime!).inMinutes / 60.0;

      // Cancel any remaining notifications
      await _cancelScheduledNotifications();

      // Reload data to reflect changes
      await _loadTodayData();

      _showAutoEndMessage(totalHours);
    } catch (e) {
      print('❌ Error during auto-end work: $e');
      _showErrorMessage('Автомат дуусгахад алдаа гарлаа: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAutoEndMessage(double totalHours) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Ажил автоматаар дууссан!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '22:00 цагт автоматаар дууссан. Та ${totalHours.toStringAsFixed(1)} цаг ажилласан байна.',
              style: const TextStyle(color: Colors.white),
            ),
            const Text(
              '⚠️ "ЯВЛАА" товчийг дараагүй байна',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // Method to calculate total working hours from all time entries
  double _calculateTotalWorkingHours(
    List<Map<String, dynamic>> entries, {
    DateTime? currentSessionStart,
  }) {
    double totalHours = 0.0;
    DateTime? sessionStart;

    // Process all completed sessions from entries
    for (final entry in entries) {
      final timestamp = (entry['timestamp'] as Timestamp).toDate();

      if (entry['type'] == 'check_in') {
        sessionStart = timestamp;
      } else if ((entry['type'] == 'check_out' ||
              entry['type'] == 'auto_check_out') &&
          sessionStart != null) {
        totalHours += timestamp.difference(sessionStart).inMinutes / 60.0;
        sessionStart = null;
      }
    }

    // Add current session if working
    if (currentSessionStart != null && _isWorking) {
      totalHours +=
          DateTime.now().difference(currentSessionStart).inMinutes / 60.0;
    }

    return totalHours;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoEndTimer?.cancel(); // Cancel auto-end timer
    super.dispose();
  }

  // Rest of your build method stays the same...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: CustomDrawer(
        onNavigateToTab: widget.onNavigateToTab,
      ),
      body: CustomScrollView(
        slivers: [
          // App Bar
          // SliverAppBar(
          //   expandedHeight: 120,
          //   floating: false,
          //   pinned: true,
          //   backgroundColor: _isWorking
          //       ? const Color(0xFF059669)
          //       : const Color(0xFF3B82F6),
          //   elevation: 0,
          //   flexibleSpace: FlexibleSpaceBar(
          //     background: Container(
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           begin: Alignment.topLeft,
          //           end: Alignment.bottomRight,
          //           colors: _isWorking
          //               ? [const Color(0xFF059669), const Color(0xFF047857)]
          //               : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          //         ),
          //       ),
          //       child: SafeArea(
          //         child: Padding(
          //           padding: const EdgeInsets.symmetric(
          //             horizontal: 20,
          //             vertical: 16,
          //           ),
          //           child: Column(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             mainAxisAlignment: MainAxisAlignment.end,
          //             children: [
          //               Row(
          //                 children: [
          //                   // User Profile Image
          //                   Container(
          //                     width: 50,
          //                     height: 50,
          //                     decoration: BoxDecoration(
          //                       shape: BoxShape.circle,
          //                       border: Border.all(
          //                         color: Colors.white.withOpacity(0.3),
          //                         width: 2,
          //                       ),
          //                       boxShadow: [
          //                         BoxShadow(
          //                           color: Colors.black.withOpacity(0.1),
          //                           blurRadius: 8,
          //                           offset: const Offset(0, 2),
          //                         ),
          //                       ],
          //                     ),
          //                     child: ClipOval(
          //                       child: Container(
          //                         color: Colors.white.withOpacity(0.2),
          //                         child: const Icon(
          //                           Icons.person,
          //                           color: Colors.white,
          //                           size: 28,
          //                         ),
          //                       ),
          //                     ),
          //                   ),
          //                   const SizedBox(width: 16),
          //                   // Hello text and status
          //                   Expanded(
          //                     child: Column(
          //                       crossAxisAlignment: CrossAxisAlignment.start,
          //                       children: [
          //                         Text(
          //                           'Сайн байна уу!',
          //                           style: TextStyle(
          //                             color: Colors.white.withOpacity(0.9),
          //                             fontSize: 14,
          //                             fontWeight: FontWeight.w400,
          //                           ),
          //                         ),
          //                         const SizedBox(height: 2),
          //                         Text(
          //                           _isWorking
          //                               ? 'Ажил хийж байна...'
          //                               : 'Цагийн бүртгэл',
          //                           style: const TextStyle(
          //                             fontWeight: FontWeight.w700,
          //                             fontSize: 18,
          //                             color: Colors.white,
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                   ),
          //                   // Notification Icon
          //                   Container(
          //                     decoration: BoxDecoration(
          //                       shape: BoxShape.circle,
          //                       color: Colors.white.withOpacity(0.1),
          //                     ),
          //                     child: IconButton(
          //                       icon: const Icon(
          //                         Icons.notifications_outlined,
          //                         color: Colors.white,
          //                         size: 24,
          //                       ),
          //                       onPressed: () {
          //                         // TODO: Handle notification tap
          //                         ScaffoldMessenger.of(context).showSnackBar(
          //                           const SnackBar(
          //                             content: Text('Мэдэгдлүүдийг харах'),
          //                             duration: Duration(seconds: 2),
          //                           ),
          //                         );
          //                       },
          //                     ),
          //                   ),
          //                 ],
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          //   shape: const RoundedRectangleBorder(
          //     borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          //   ),
          // ),
          CustomSliverAppBar(
            leftIcon: Icons.person,
            onLeftTap: () => print("Home tapped"),
            rightIcon: Icons.notifications,
            onRightTap: () => print("Settings tapped"),
            subtitle: "Сайн байна уу!",
            title: _isWorking ? 'Ажил хийж байна...' : 'Цагийн бүртгэл',
            gradientColors: _isWorking
                ? [const Color(0xFF059669), const Color(0xFF3B82F6)]
                : [const Color(0xFF3B82F6), const Color(0xFF3B82F6)],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate([
                      // Current Time Display
                      TimeDisplayCard(isWorking: _isWorking),

                      const SizedBox(height: 24),

                      // Schedule Info
                      ScheduleInfoWidget(
                        isWorking: _isWorking,
                        scheduledEndTime: _scheduledEndTime,
                      ),

                      // Status Card
                      StatusCard(
                        startTime: _startTime,
                        endTime: _endTime,
                        isWorking: _isWorking,
                        todayData: _todayData,
                      ),

                      const SizedBox(height: 24),

                      // Working Hours Card
                      if (_startTime != null)
                        WorkingHoursCard(
                          startTime: _startTime!,
                          endTime: _endTime,
                          isWorking: _isWorking,
                          totalWorkingHours: _totalWorkingHours,
                        ),

                      if (_startTime != null) const SizedBox(height: 24),

                      // Time Entries List
                      TimeEntriesListWidget(
                        todayEntries: _todayEntries,
                        onLocationTap: _showLocationOnMap,
                      ),

                      // Food Eaten Status Widget
                      FoodEatenStatusWidget(
                        todayFoods: _todayFoods,
                        eatenForDay: _eatenForToday,
                        dateString: TimeUtils.formatDateString(DateTime.now()),
                        onStatusChanged: () {
                          // Reload today's data when status changes
                          _loadTodayData();
                        },
                      ),

                      // Google Maps Widget
                      MapWidget(
                        currentLocation: _currentLocation,
                        todayEntries: _todayEntries,
                        onLocationTap: _showLocationOnMap,
                      ),

                      // Action Buttons
                      if (!_isWorking && _endTime == null)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: ActionButton(
                                text: 'ИРЛЭЭ',
                                icon: Icons.login,
                                color: const Color(0xFF059669),
                                onPressed: _isLoading ? null : _handleStartWork,
                                isLoading: _isLoading,
                              ),
                            );
                          },
                        ),

                      if (_isWorking)
                        ActionButton(
                          text: 'ЯВЛАА',
                          icon: Icons.logout,
                          color: const Color(0xFFEF4444),
                          onPressed: _isLoading ? null : _handleEndWork,
                          isLoading: _isLoading,
                        ),

                      // Additional check-in button (if not currently working but have entries)
                      if (!_isWorking &&
                          _todayEntries.isNotEmpty &&
                          (_endTime != null ||
                              _todayEntries.last['type'] == 'check_out'))
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            ActionButton(
                              text: 'ДАХИН ИРЛЭЭ',
                              icon: Icons.refresh,
                              color: const Color(0xFF059669),
                              onPressed: _isLoading
                                  ? null
                                  : _handleAdditionalCheckIn,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),

                      const SizedBox(height: 32),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}
