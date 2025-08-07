import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timex/screens/time_track/widgets/status_card.dart';
import 'package:timex/screens/time_track/widgets/time_display_card.dart';
import 'package:timex/screens/time_track/widgets/time_utils.dart';
import 'package:timex/screens/time_track/widgets/work_day.dart';
import 'package:timex/screens/time_track/widgets/working_hours_card.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'widgets/action_button.dart';

class TimeTrackScreen extends StatefulWidget {
  const TimeTrackScreen({super.key});

  @override
  State<TimeTrackScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Set work end time to 1:50 PM (13:50)
  static const int workEndHour = 20;
  static const int workEndMinute = 50;

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isWorking = false;
  bool _isLoading = false;
  WorkDay? _todayData;
  DateTime? _scheduledEndTime;
  
  // Multiple check-ins/check-outs with location tracking
  List<Map<String, dynamic>> _todayEntries = [];
  Position? _currentLocation;
  GoogleMapController? _mapController;
  
  // Food data for today
  List<Map<String, dynamic>> _todayFoods = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final dateString = TimeUtils.formatDateString(now);

      // Load today's entries (no user filter needed)
      final entriesSnapshot = await _firestore
          .collection('timeEntries')
          .where('date', isEqualTo: dateString)
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
          _startTime = _todayEntries.isNotEmpty ? 
              (_todayEntries.first['timestamp'] as Timestamp).toDate() : null;
          _endTime = (lastEntry['timestamp'] as Timestamp).toDate();
          _scheduledEndTime = null;
        }
      }

      // Also load legacy calendar data for compatibility
      final doc = await _firestore.collection('calendarDays').doc(dateString).get();
      if (doc.exists) {
        final data = doc.data()!;
        _todayData = WorkDay.fromMap(data);
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
        _showErrorMessage('Байршлын зөвшөөрөл байнга татгалзсан байна. Тохиргооноос нээнэ үү.');
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
    return DateTime(startTime.year, startTime.month, startTime.day, workEndHour, workEndMinute);
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
          body: 'Таны ажлын цаг дууслаа! "ЯВЛАА" товчийг дарж ажлаа дуусгаарай.',
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
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

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
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

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
        'সूनোটিফিकेशन সেট করতে পারलাম না। Settings এ গিয়ে exact alarm permission চালু করুন।',
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

  Future<void> _handleStartWork() async {
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

      // Save to timeEntries collection
      try {
        await _firestore.collection('timeEntries').add(timeEntryData);
        debugPrint('✅ Successfully saved check-in time entry to Firestore');
      } catch (firestoreError) {
        debugPrint('❌ Firestore error during check-in: $firestoreError');
        _showErrorMessage('Өгөгдөл хадгалахад алдаа гарлаа: $firestoreError');
        setState(() => _isLoading = false);
        return;
      }

      // Update calendar day - add to existing hours instead of overwriting
      final workDay = WorkDay.createNew(now);
      final existingDoc = await _firestore.collection('calendarDays').doc(workDay.documentId).get();
      
      if (existingDoc.exists) {
        // Update existing document - don't overwrite
        await _firestore.collection('calendarDays').doc(workDay.documentId).update({
          'lastCheckIn': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new document
        await _firestore.collection('calendarDays').doc(workDay.documentId).set(workDay.toMap());
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
      });

      // Reload entries to show the new check-in
      await _loadTodayData();

      // Schedule notifications
      await _scheduleEndWorkNotifications(scheduledEndTime);

      _showSuccessMessage(
        'Ажилд ирлээ! 🎉\nБайршил: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      print('❌ Error starting work: $e');
      _showErrorMessage('Алдаа гарлаацбцббц: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEndWork() async {
    if (_startTime == null) return;

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
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to timeEntries collection
      try {
        await _firestore.collection('timeEntries').add(timeEntryData);
        debugPrint('✅ Successfully saved check-out time entry to Firestore');
      } catch (firestoreError) {
        debugPrint('❌ Firestore error during check-out: $firestoreError');
        _showErrorMessage('Өгөгдөл хадгалахад алдаа гарлаа: $firestoreError');
        setState(() => _isLoading = false);
        return;
      }

      // Update calendar day - calculate total working hours from all entries
      final allEntries = await _firestore
          .collection('timeEntries')
          .where('date', isEqualTo: dateString)
          .get();

      // Convert to list and sort by timestamp
      final entryDocs = allEntries.docs.toList();
      entryDocs.sort((a, b) {
        final timestampA = (a.data()['timestamp'] as Timestamp).toDate();
        final timestampB = (b.data()['timestamp'] as Timestamp).toDate();
        return timestampA.compareTo(timestampB);
      });

      double totalHours = 0.0;
      DateTime? sessionStart;
      
      for (final entry in entryDocs) {
        final data = entry.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        
        if (data['type'] == 'check_in') {
          sessionStart = timestamp;
        } else if (data['type'] == 'check_out' && sessionStart != null) {
          totalHours += timestamp.difference(sessionStart).inMinutes / 60.0;
          sessionStart = null;
        }
      }

      await _firestore.collection('calendarDays').doc(dateString).update({
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
        if (_todayData != null) {
          _todayData = _todayData!.copyWith(endTime: now, workingHours: totalHours);
        }
      });

      // Reload entries to show the new check-out
      await _loadTodayData();

      _showSuccessMessage(
        'Ажлаас явлаа! Та ${totalHours.toStringAsFixed(1)} цаг ажилласан байна. 👋\nБайршил: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      print('tryhjtytyjtyj $e');
      _showErrorMessage(' wregergergergerg: $e');
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

      // Save to timeEntries collection
      try {
        await _firestore.collection('timeEntries').add(timeEntryData);
        debugPrint('✅ Successfully saved additional check-in time entry to Firestore');
      } catch (firestoreError) {
        debugPrint('❌ Firestore error during additional check-in: $firestoreError');
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

      // Reload entries to show the new check-in
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMapWidget() {
    if (_currentLocation == null && _todayEntries.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Өнөөдөр ажлын байршил оруулаагүй байна',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Build markers from all today's entries
    Set<Marker> markers = {};
    LatLng? centerPosition;

    // Add markers for each time entry with location
    for (int i = 0; i < _todayEntries.length; i++) {
      final entry = _todayEntries[i];
      final location = entry['location'];
      if (location != null && location['latitude'] != null && location['longitude'] != null) {
        final lat = location['latitude'] as double;
        final lng = location['longitude'] as double;
        final timestamp = (entry['timestamp'] as Timestamp).toDate();
        final type = entry['type'] as String;
        
        markers.add(
          Marker(
            markerId: MarkerId('entry_$i'),
            position: LatLng(lat, lng),
            icon: type == 'check_in' 
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: type == 'check_in' ? 'ИРЛЭЭ' : 'ЯВЛАА',
              snippet: '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
            ),
          ),
        );
        
        // Use the latest location as center
        centerPosition = LatLng(lat, lng);
      }
    }

    // If no entries have location, use current location
    if (centerPosition == null && _currentLocation != null) {
      centerPosition = LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
    }

    // Default to Ulaanbaatar if no location data
    centerPosition ??= const LatLng(47.9184, 106.9177);

    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: centerPosition,
            zoom: 16,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }

  Widget _buildTimeEntriesList() {
    if (_todayEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF6B7280)),
            SizedBox(width: 12),
            Text(
              'Өнөөдөр ямар ч орсон гарсан байхгүй байна',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
              maxLines: 3,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                const Text(
                  'Өнөөдрийн орсон гарсан',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayEntries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = _todayEntries[index];
              final timestamp = (entry['timestamp'] as Timestamp).toDate();
              final isCheckIn = entry['type'] == 'check_in';
              final location = entry['location'] as Map<String, dynamic>?;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCheckIn
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isCheckIn ? Icons.login : Icons.logout,
                        color: isCheckIn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCheckIn ? 'Ирлээ' : 'Явлаа',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            _formatTime(timestamp),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          if (location != null)
                            Text(
                              'GPS: ${location['latitude'].toStringAsFixed(4)}, ${location['longitude'].toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showLocationOnMap(location),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodayFoodsList() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.restaurant, color: Color(0xFFEF4444)),
                const SizedBox(width: 12),
                const Text(
                  'Өнөөдрийн хоол',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_todayFoods.length} хоол',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (_todayFoods.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Text(
                    'Өнөөдөр хоол нэмээгүй байна',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayFoods.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final food = _todayFoods[index];
                return InkWell(
                  onTap: () => _showFoodDetailDialog(food),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Food image or placeholder
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: food['image'] != null && food['image'].isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(food['image']),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.restaurant,
                                  color: Color(0xFFEF4444),
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Food details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food['name'] ?? 'Нэргүй хоол',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (food['description'] != null && food['description'].isNotEmpty)
                                Text(
                                  food['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (food['price'] != null)
                                Text(
                                  '₮ ${food['price']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF9CA3AF),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showFoodDetailDialog(Map<String, dynamic> food) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Хоолны дэлгэрэнгүй',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food image
                      if (food['image'] != null && food['image'].isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(food['image']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Food name
                      Text(
                        food['name'] ?? 'Нэргүй хоол',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Price
                      if (food['price'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₮ ${food['price']}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      if (food['description'] != null && food['description'].isNotEmpty) ...[
                        const Text(
                          'Тайлбар:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          food['description'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Added time
                      if (food['createdAt'] != null) ...[
                        const Text(
                          'Нэмсэн цаг:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimeFromMillis(food['createdAt']),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeFromMillis(int milliseconds) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showLocationOnMap(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Байршил'),
        content: Container(
          width: 300,
          height: 300,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(location['latitude'], location['longitude']),
              zoom: 17,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('location'),
                position: LatLng(location['latitude'], location['longitude']),
                infoWindow: InfoWindow(
                  title: 'Ажлын байршил',
                  snippet: 'Нарийвчлал: ${location['accuracy'].toStringAsFixed(1)}м',
                ),
              ),
            },
            mapType: MapType.normal,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo() {
    if (!_isWorking || _scheduledEndTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final timeLeft = _scheduledEndTime!.difference(now);

    if (timeLeft.isNegative) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ажлын цаг дууссан байна! Ажлаа дуусгаарай.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Ажлын цагийн хуваарь',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Дуусах цаг: ${_formatTime(_scheduledEndTime!)}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Text(
            'Үлдсэн хугацаа: ${timeLeft.inHours}:${(timeLeft.inMinutes % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
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

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Rest of your build method stays the same...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: _isWorking ? const Color(0xFF059669) : const Color(0xFF3B82F6),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _isWorking ? 'Ажил хийж байна...' : 'Цагийн бүртгэл',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isWorking
                        ? [const Color(0xFF059669), const Color(0xFF047857)]
                        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                  ),
                ),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : SliverList(
                    delegate: SliverChildListDelegate([
                      // Current Time Display
                      TimeDisplayCard(isWorking: _isWorking),

                      const SizedBox(height: 24),

                      // Schedule Info (NEW)
                      _buildScheduleInfo(),

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
                        ),

                      if (_startTime != null) const SizedBox(height: 24),

                      // Time Entries List (NEW)
                      _buildTimeEntriesList(),

                      // Today's Foods List (NEW)
                      _buildTodayFoodsList(),

                      // Google Maps Widget (NEW) - Above action buttons
                      _buildMapWidget(),

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
                      if (!_isWorking && _todayEntries.isNotEmpty && (_endTime != null || _todayEntries.last['type'] == 'check_out'))
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            ActionButton(
                              text: 'ДАХИН ИРЛЭЭ',
                              icon: Icons.refresh,
                              color: const Color(0xFF059669),
                              onPressed: _isLoading ? null : _handleAdditionalCheckIn,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),

                      if (_endTime != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Өнөөдрийн ажил дууссан байна!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
