import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import '../../../../services/money_format.dart';

class EatenFoodDisplayWidget extends StatefulWidget {
  const EatenFoodDisplayWidget({
    super.key,
  });

  @override
  State<EatenFoodDisplayWidget> createState() => _EatenFoodDisplayWidgetState();
}

class _EatenFoodDisplayWidgetState extends State<EatenFoodDisplayWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, Map<String, dynamic>> _eatenFoodData = {};
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _eatensSubscription;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _eatensSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    _eatensSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .collection('eatens')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _processEatenData(snapshot);
      }
    });
  }

  void _processEatenData(QuerySnapshot snapshot) {
    final Map<String, Map<String, dynamic>> newData = {};
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateKey = doc.id;
      
      // Extract food data from the document
      if (data.containsKey('foods') && data['foods'] is List) {
        final foods = List<Map<String, dynamic>>.from(data['foods']);
        final totalPrice = data['totalPrice'] as int? ?? 0;
        final eatenAt = data['eatenAt'] as Timestamp?;
        
        newData[dateKey] = {
          'foods': foods,
          'totalPrice': totalPrice,
          'eatenAt': eatenAt,
          'foodCount': foods.length,
        };
      }
    }

    if (mounted) {
      setState(() {
        _eatenFoodData = newData;
        _isLoading = false;
      });
    }
  }

  Map<String, Map<String, dynamic>> get _filteredData {
    return _eatenFoodData;
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Даваа',
      'Мягмар',
      'Лхагва',
      'Пүрэв',
      'Баасан',
      'Бямба',
      'Ням',
    ];
    return weekdays[weekday - 1];
  }

  Widget _buildFoodImage(Map<String, dynamic> food, {double size = 48}) {
    if (food['image'] != null && food['image'].isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(food['image']),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFoodPlaceholder(size),
          ),
        ),
      );
    } else {
      return _buildFoodPlaceholder(size);
    }
  }

  Widget _buildFoodPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filteredData = _filteredData;
    final sortedDates = filteredData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    if (sortedDates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_meals_outlined,
                size: 48,
                color: Colors.grey[500],
              ),
              const SizedBox(height: 12),
              Text(
                'Идсэн хоолны мэдээлэл байхгүй байна',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final dayData = filteredData[dateKey]!;
              final foods = List<Map<String, dynamic>>.from(dayData['foods']);
              final totalPrice = dayData['totalPrice'] as int;
              final date = DateTime.parse(dateKey);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header (using green color to differentiate from unpaid)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${date.month}/${date.day}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green[800],
                                ),
                              ),
                              Text(
                                '${_getWeekdayName(date.weekday)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  MoneyFormatService.formatWithSymbol(totalPrice),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Food items list (without payment button)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...foods.map((food) {
                            final foodName = food['name']?.toString() ?? 'Unknown';
                            final price = food['price'] as int? ?? 0;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green[25],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  // Food image
                                  _buildFoodImage(food),
                                  const SizedBox(width: 16),
                                  // Food details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          foodName,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Price
                                  Text(
                                    MoneyFormatService.formatWithSymbol(price),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
