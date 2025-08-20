import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../../services/money_format.dart';

class StatisticsDashboard extends StatefulWidget {
  const StatisticsDashboard({super.key});

  @override
  State<StatisticsDashboard> createState() => _StatisticsDashboardState();
}

class _StatisticsDashboardState extends State<StatisticsDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Real-time data
  double _totalWorkingHours = 0.0;
  int _totalFoodAmount = 0;
  bool _isWorkingToday = false;
  DateTime? _todayStartTime;
  String _currentSessionDuration = "00:00";
  
  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  StreamSubscription<DocumentSnapshot>? _todayCalendarSubscription;
  StreamSubscription<QuerySnapshot>? _todayEntriesSubscription;
  Timer? _currentSessionTimer;
  
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _startListeningToRealtimeData();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _todayCalendarSubscription?.cancel();
    _todayEntriesSubscription?.cancel();
    _currentSessionTimer?.cancel();
    super.dispose();
  }

  void _startListeningToRealtimeData() {
    if (_userId.isEmpty) return;

    // Listen to user document for total food amount
    _userDataSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data();
        final dynamic rawTotalFoodAmount = userData?['totalFoodAmount'] ?? 0;
        setState(() {
          _totalFoodAmount = rawTotalFoodAmount is String 
              ? int.tryParse(rawTotalFoodAmount) ?? 0 
              : (rawTotalFoodAmount as num).toInt();
        });
      }
    });

    // Listen to today's calendar data for total working hours
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    _todayCalendarSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .collection('calendarDays')
        .doc(todayString)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final dayData = snapshot.data();
        setState(() {
          _totalWorkingHours = (dayData?['workingHours'] ?? 0.0).toDouble();
        });
      }
    });

    // Listen to today's time entries for current session status
    _todayEntriesSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .collection('calendarDays')
        .doc(todayString)
        .collection('timeEntries')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _updateCurrentWorkingStatus(snapshot.docs);
      }
    });
  }

  void _updateCurrentWorkingStatus(List<QueryDocumentSnapshot> entryDocs) {
    if (entryDocs.isEmpty) {
      setState(() {
        _isWorkingToday = false;
        _todayStartTime = null;
      });
      _currentSessionTimer?.cancel();
      return;
    }

    // Sort entries by timestamp
    final entries = entryDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    entries.sort((a, b) {
      final timestampA = (a['timestamp'] as Timestamp).toDate();
      final timestampB = (b['timestamp'] as Timestamp).toDate();
      return timestampA.compareTo(timestampB);
    });

    final lastEntry = entries.last;
    final isCurrentlyWorking = lastEntry['type'] == 'check_in';

    setState(() {
      _isWorkingToday = isCurrentlyWorking;
      if (isCurrentlyWorking) {
        _todayStartTime = (lastEntry['timestamp'] as Timestamp).toDate();
        _startCurrentSessionTimer();
      } else {
        _todayStartTime = null;
        _currentSessionTimer?.cancel();
        _currentSessionDuration = "00:00";
      }
    });
  }

  void _startCurrentSessionTimer() {
    _currentSessionTimer?.cancel();
    _currentSessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_todayStartTime != null && _isWorkingToday && mounted) {
        final now = DateTime.now();
        final duration = now.difference(_todayStartTime!);
        setState(() {
          _currentSessionDuration = _formatDuration(duration);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String _formatMongolianHours(double hours) {
    final int h = hours.floor();
    final int m = ((hours - h) * 60).round();
    if (h > 0 && m > 0) return '$h цаг, $m минут';
    if (h > 0) return '$h цаг';
    return '$m минут';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Working Hours Statistics
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isWorkingToday 
                  ? [const Color(0xFF059669), const Color(0xFF10B981)]
                  : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _isWorkingToday ? Icons.work : Icons.access_time,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isWorkingToday ? 'Одоо ажиллаж буй' : 'Өнөөдрийн ажилласан цаг',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMongolianHours(_totalWorkingHours),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Нийт цаг',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  if (_isWorkingToday) ...[
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Text(
                      _currentSessionDuration,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Food Amount Statistics
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.restaurant_menu,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Нийт хоолны зардал',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      MoneyFormatService.formatWithSymbol(_totalFoodAmount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
