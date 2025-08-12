import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../services/money_format.dart';

class WeekViewWidget extends StatefulWidget {
  final DateTime currentWeek;
  final Map<String, List<Map<String, dynamic>>> weekMeals;
  final Function(String date, String mealType, Map<String, dynamic> meal)
      onMealTap;
  final Function(String date, String mealType) onAddMeal;
  final Function(String date, String mealType, Map<String, dynamic> meal)
      onMealLongPress;
  final Function(Map<String, dynamic> updatedFood)? onFoodUpdated;

  const WeekViewWidget({
    super.key,
    required this.currentWeek,
    required this.weekMeals,
    required this.onMealTap,
    required this.onAddMeal,
    required this.onMealLongPress,
    this.onFoodUpdated,
  });

  @override
  State<WeekViewWidget> createState() => _WeekViewWidgetState();
}

class _WeekViewWidgetState extends State<WeekViewWidget> {
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _expandedFoods = {};
  final String _currentUserId = 'user_123'; // Mock user ID - in real app, get from auth
  bool _isLoading = false;
  
  // Payment and eaten status tracking
  Map<String, bool> _eatenForDayData = {}; // Track which days food was eaten
  Map<String, bool> _paidMeals = {}; // Track which individual meals are paid for

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    await Future.wait([
      _loadEatenForDayData(),
      _loadMealPaymentStatus(),
    ]);
  }

  // Load eaten for day data for the current week
  Future<void> _loadEatenForDayData() async {
    try {
      final weekStart = widget.currentWeek.subtract(Duration(days: widget.currentWeek.weekday - 1));
      final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));

      for (final day in weekDays) {
        final dateKey = _formatDateKey(day);
        
        final calendarDoc = await FirebaseFirestore.instance
            .collection('calendarDays')
            .doc(dateKey)
            .get();

        if (calendarDoc.exists) {
          final data = calendarDoc.data()!;
          _eatenForDayData[dateKey] = data['eatenForDay'] as bool? ?? false;
        } else {
          _eatenForDayData[dateKey] = false;
        }
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading eaten for day data: $e');
    }
  }

  // Load meal payment status for the current week
  Future<void> _loadMealPaymentStatus() async {
    try {
      final userId = 'current_user'; // Replace with actual user ID
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final docSnapshot = await FirebaseFirestore.instance
          .collection('mealPayments')
          .doc('$userId-$monthKey')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _paidMeals = Map<String, bool>.from(data['paidMeals'] ?? {});
      } else {
        _paidMeals = {};
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading meal payment status: $e');
      _paidMeals = {};
    }
  }

  @override
  void didUpdateWidget(WeekViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentWeek != widget.currentWeek) {
      _loadWeekData();
    }
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCommentController(String foodId) {
    if (!_commentControllers.containsKey(foodId)) {
      _commentControllers[foodId] = TextEditingController();
    }
    return _commentControllers[foodId]!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final weekStart =
        widget.currentWeek.subtract(Duration(days: widget.currentWeek.weekday - 1));
    final weekDays =
        List.generate(7, (index) => weekStart.add(Duration(days: index)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Week days header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: weekDays.map((day) {
                final isToday = _isToday(day);
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primaryLight.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getDayName(day.weekday),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isToday
                                ? AppTheme.primaryLight
                                : colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppTheme.primaryLight
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isToday
                                    ? AppTheme.onPrimaryLight
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Foods grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: weekDays.map((day) {
                  final dateKey = _formatDateKey(day);
                  final dayFoods = widget.weekMeals[dateKey] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Day header
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isToday(day)
                                ? AppTheme.primaryLight.withOpacity(0.05)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_getDayName(day.weekday)}, ${_getMonthName(day.month)} ${day.day}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _isToday(day)
                                        ? AppTheme.primaryLight
                                        : colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isToday(day))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Today',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.onPrimaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Foods list
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              if (dayFoods.isEmpty)
                                _buildAddFoodButton(context, dateKey)
                              else
                                ...dayFoods.map((food) => 
                                    _buildFoodItemWithComments(context, dateKey, food)),
                              if (dayFoods.isNotEmpty)
                                const SizedBox(height: 8),
                              if (dayFoods.isNotEmpty)
                                _buildAddFoodButton(context, dateKey),
                              
                              // Payment status section
                              // const SizedBox(height: 12),
                              // _buildPaymentStatusSection(context, dateKey, dayFoods),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemWithComments(BuildContext context, String dateKey, Map<String, dynamic> food) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foodId = food['id'] ?? '';
    final isExpanded = _expandedFoods[foodId] ?? false;
    final comments = List<Map<String, dynamic>>.from(food['comments'] ?? []);
    final isLiked = (food['likes'] as List<dynamic>? ?? []).contains(_currentUserId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.successLight.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food header with image, name, price
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Food image
                if (food['image'] != null && food['image'].isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(food['image']),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.successLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.restaurant,
                        color: AppTheme.successLight,
                        size: 24,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),

                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food['name'] as String? ?? 'Unknown Food',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (food['description'] != null && food['description'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            food['description'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // Price
                if (food['price'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      MoneyFormatService.formatWithSymbol(food['price'] ?? 0),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successLight,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Like and comment buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: () => _toggleLike(dateKey, food),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLiked ? Colors.red.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLiked ? Colors.red.withOpacity(0.3) : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${food['likesCount'] ?? 0}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isLiked ? Colors.red : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Comment toggle button
                GestureDetector(
                  onTap: () => _toggleComments(foodId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isExpanded ? AppTheme.primaryLight.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isExpanded ? AppTheme.primaryLight.withOpacity(0.3) : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: isExpanded ? AppTheme.primaryLight : Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${food['commentsCount'] ?? 0}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isExpanded ? AppTheme.primaryLight : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Comments section (expanded)
          if (isExpanded) ...[
            const SizedBox(height: 12),
            
            // Add comment section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryLight,
                    child: const Text(
                      'Y',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _getCommentController(foodId),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: AppTheme.primaryLight),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: theme.textTheme.bodySmall,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(dateKey, food),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _addComment(dateKey, food),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Comments list
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...comments.map((comment) => _buildCommentItem(context, dateKey, food, comment)),
            ],
            
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildAddFoodButton(BuildContext context, String dateKey) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Check if the date is in the past
    final selectedDate = DateTime.parse(dateKey);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isPastDate = selectedDateOnly.isBefore(todayDate);
    
    return GestureDetector(
      onTap: isPastDate ? null : () => widget.onAddMeal(dateKey, ''), // Disable tap for past dates
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isPastDate 
              ? colorScheme.surface.withOpacity(0.5)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPastDate 
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              color: isPastDate 
                  ? AppTheme.primaryLight.withOpacity(0.3)
                  : AppTheme.primaryLight,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isPastDate ? 'Past Date' : 'Add Food',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isPastDate 
                    ? AppTheme.primaryLight.withOpacity(0.3)
                    : AppTheme.primaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleComments(String foodId) {
    setState(() {
      _expandedFoods[foodId] = !(_expandedFoods[foodId] ?? false);
    });
  }

  Future<void> _toggleLike(String dateKey, Map<String, dynamic> food) async {
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = '${dateKey}-foods';
      final docRef = FirebaseFirestore.instance.collection('foods').doc(documentId);
      
      // Get current document
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }

      final data = docSnapshot.data()!;
      final foods = List<Map<String, dynamic>>.from(data['foods'] ?? []);
      
      // Find the food item by ID - handle various ID scenarios
      final foodId = food['id']?.toString();
      if (foodId == null || foodId.isEmpty) {
        throw Exception('Food ID is missing or empty');
      }
      
      final foodIndex = foods.indexWhere((f) => f['id']?.toString() == foodId);
      if (foodIndex == -1) {
        // Debug: Print available food IDs for troubleshooting
        final availableIds = foods.map((f) => f['id']?.toString() ?? 'null').toList();
        print('❌ Food item not found in _toggleLike. Looking for ID: $foodId');
        print('📋 Available food IDs: $availableIds');
        throw Exception('Food item not found. Expected ID: $foodId');
      }

      final currentFood = Map<String, dynamic>.from(foods[foodIndex]);
      final likes = List<String>.from(currentFood['likes'] ?? []);
      
      if (likes.contains(_currentUserId)) {
        // Remove like
        likes.remove(_currentUserId);
      } else {
        // Add like
        likes.add(_currentUserId);
      }
      
      // Update the food item
      currentFood['likes'] = likes;
      currentFood['likesCount'] = likes.length;
      foods[foodIndex] = currentFood;
      
      // Update Firestore
      await docRef.update({
        'foods': foods,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      setState(() {
        widget.weekMeals[dateKey]?[widget.weekMeals[dateKey]!.indexWhere((f) => f['id'] == food['id'])] = currentFood;
      });
      
      // Notify parent if callback provided
      if (widget.onFoodUpdated != null) {
        widget.onFoodUpdated!(currentFood);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment(String dateKey, Map<String, dynamic> food) async {
    final foodId = food['id']?.toString() ?? '';
    final commentText = _getCommentController(foodId).text.trim();
    if (commentText.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = '${dateKey}-foods';
      final docRef = FirebaseFirestore.instance.collection('foods').doc(documentId);
      
      // Get current document
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }

      final data = docSnapshot.data()!;
      final foods = List<Map<String, dynamic>>.from(data['foods'] ?? []);
      
      // Find the food item by ID - handle various ID scenarios
      if (foodId.isEmpty) {
        throw Exception('Food ID is missing or empty');
      }
      
      final foodIndex = foods.indexWhere((f) => f['id']?.toString() == foodId);
      if (foodIndex == -1) {
        // Debug: Print available food IDs for troubleshooting
        final availableIds = foods.map((f) => f['id']?.toString() ?? 'null').toList();
        print('❌ Food item not found in _addComment. Looking for ID: $foodId');
        print('📋 Available food IDs: $availableIds');
        throw Exception('Food item not found. Expected ID: $foodId');
      }

      final currentFood = Map<String, dynamic>.from(foods[foodIndex]);
      final comments = List<Map<String, dynamic>>.from(currentFood['comments'] ?? []);
      
      // Create new comment
      final newComment = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': _currentUserId,
        'userName': 'You', // In real app, get from user profile
        'text': commentText,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'likes': <String>[],
        'likesCount': 0,
      };
      
      comments.add(newComment);
      
      // Update the food item
      currentFood['comments'] = comments;
      currentFood['commentsCount'] = comments.length;
      foods[foodIndex] = currentFood;
      
      // Update Firestore
      await docRef.update({
        'foods': foods,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      setState(() {
        widget.weekMeals[dateKey]?[widget.weekMeals[dateKey]!.indexWhere((f) => f['id'] == food['id'])] = currentFood;
        _getCommentController(foodId).clear();
      });
      
      // Notify parent if callback provided
      if (widget.onFoodUpdated != null) {
        widget.onFoodUpdated!(currentFood);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCommentLike(String dateKey, Map<String, dynamic> food, String commentId) async {
    // Add haptic feedback
    HapticFeedback.selectionClick();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = '${dateKey}-foods';
      final docRef = FirebaseFirestore.instance.collection('foods').doc(documentId);
      
      // Get current document
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }

      final data = docSnapshot.data()!;
      final foods = List<Map<String, dynamic>>.from(data['foods'] ?? []);
      
      // Find the food item by ID - handle various ID scenarios
      final foodId = food['id']?.toString();
      if (foodId == null || foodId.isEmpty) {
        throw Exception('Food ID is missing or empty');
      }
      
      final foodIndex = foods.indexWhere((f) => f['id']?.toString() == foodId);
      if (foodIndex == -1) {
        // Debug: Print available food IDs for troubleshooting
        final availableIds = foods.map((f) => f['id']?.toString() ?? 'null').toList();
        print('❌ Food item not found in _toggleCommentLike. Looking for ID: $foodId');
        print('📋 Available food IDs: $availableIds');
        throw Exception('Food item not found. Expected ID: $foodId');
      }

      final currentFood = Map<String, dynamic>.from(foods[foodIndex]);
      final comments = List<Map<String, dynamic>>.from(currentFood['comments'] ?? []);
      
      // Find the comment by ID
      final commentIndex = comments.indexWhere((c) => c['id'] == commentId);
      if (commentIndex == -1) {
        throw Exception('Comment not found');
      }

      final currentComment = Map<String, dynamic>.from(comments[commentIndex]);
      final likes = List<String>.from(currentComment['likes'] ?? []);
      
      if (likes.contains(_currentUserId)) {
        // Remove like
        likes.remove(_currentUserId);
      } else {
        // Add like
        likes.add(_currentUserId);
      }
      
      // Update the comment
      currentComment['likes'] = likes;
      currentComment['likesCount'] = likes.length;
      comments[commentIndex] = currentComment;
      
      // Update the food item
      currentFood['comments'] = comments;
      foods[foodIndex] = currentFood;
      
      // Update Firestore
      await docRef.update({
        'foods': foods,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      setState(() {
        widget.weekMeals[dateKey]?[widget.weekMeals[dateKey]!.indexWhere((f) => f['id'] == food['id'])] = currentFood;
      });
      
      // Notify parent if callback provided
      if (widget.onFoodUpdated != null) {
        widget.onFoodUpdated!(currentFood);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating comment like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildCommentItem(BuildContext context, String dateKey, Map<String, dynamic> food, Map<String, dynamic> comment) {
    final theme = Theme.of(context);
    final isCommentLiked = (comment['likes'] as List<dynamic>? ?? []).contains(_currentUserId);
    final commentLikes = comment['likesCount'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  (comment['userName'] as String? ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['userName'] ?? 'Unknown User',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatCommentTime(comment['createdAt']),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment['text'] ?? '',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleCommentLike(dateKey, food, comment['id']),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCommentLiked ? Icons.favorite : Icons.favorite_border,
                      color: isCommentLiked ? Colors.red : Colors.grey[600],
                      size: 14,
                    ),
                    if (commentLikes > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$commentLikes',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    final DateTime commentTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(commentTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildPaymentStatusSection(BuildContext context, String dateKey, List<Map<String, dynamic>> dayFoods) {
    final theme = Theme.of(context);
    final wasEaten = _eatenForDayData[dateKey] ?? false;
    
    if (dayFoods.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check payment status
    bool hasUnpaidMeals = false;
    bool hasAnyMeals = dayFoods.isNotEmpty;
    
    if (hasAnyMeals && wasEaten) {
      for (int i = 0; i < dayFoods.length; i++) {
        final mealKey = '${dateKey}_$i';
        final isPaid = _paidMeals[mealKey] ?? false;
        if (!isPaid) {
          hasUnpaidMeals = true;
          break;
        }
      }
    }

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!hasAnyMeals) {
      return const SizedBox.shrink();
    } else if (!wasEaten) {
      statusText = 'Хоол идээгүй';
      statusColor = Colors.grey;
      statusIcon = Icons.cancel_outlined;
    } else if (hasUnpaidMeals) {
      statusText = 'Төлбөр төлөх';
      statusColor = Colors.orange;
      statusIcon = Icons.payment;
    } else {
      statusText = 'Төлбөр төлсөн';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
