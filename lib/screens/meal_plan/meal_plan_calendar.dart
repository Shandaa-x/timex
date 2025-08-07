import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timex/screens/meal_plan/widgets/custom_app_bar.dart';
import '../../theme/app_theme.dart';
import './widgets/calendar_header_widget.dart';
import './widgets/add_food_bottom_sheet.dart';
import './widgets/food_detail_dialog.dart';
import './widgets/month_view_widget.dart';
import './widgets/week_view_widget.dart';

class MealPlanCalendar extends StatefulWidget {
  const MealPlanCalendar({super.key});

  @override
  State<MealPlanCalendar> createState() => _MealPlanCalendarState();
}

class _MealPlanCalendarState extends State<MealPlanCalendar>
    with TickerProviderStateMixin {
  bool _isWeekView = true;
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  bool _isOffline = false;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  // Food data - map of date string to list of foods
  final Map<String, List<Map<String, dynamic>>> _foodData = {};

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    _checkConnectivity();
    _loadFoodData();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _checkConnectivity() {
    // Simulate connectivity check
    setState(() {
      _isOffline = false; // Mock online state
    });
  }

  Future<void> _loadFoodData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      setState(() {
        _foodData.clear();
      });

      // Create document ID range for the current month
      final startDocId = '${now.year}-${now.month.toString().padLeft(2, '0')}-01-foods';
      final endDocId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}-foods';

      try {
        // Use a range query to get all food documents for the current month
        final querySnapshot = await FirebaseFirestore.instance
            .collection('foods')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
            .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
            .get();

        // Process all documents at once
        for (final doc in querySnapshot.docs) {
          if (doc.exists) {
            final data = doc.data();
            final dateKey = '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';
            
            // Extract foods array from the document
            if (data['foods'] != null && data['foods'] is List) {
              final foods = List<Map<String, dynamic>>.from(data['foods']);
              
              // Add backward compatibility for existing foods without new fields
              final processedFoods = foods.map((food) {
                return {
                  'id': food['id'] ?? 'food_${DateTime.now().millisecondsSinceEpoch}_${foods.indexOf(food)}', // Ensure unique ID
                  'name': food['name'] ?? 'Unknown Food',
                  'description': food['description'] ?? '',
                  'price': food['price'] ?? 0,
                  'image': food['image'] ?? '',
                  'createdAt': food['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
                  'likes': food['likes'] ?? <String>[],
                  'likesCount': food['likesCount'] ?? 0,
                  'comments': food['comments'] ?? <Map<String, dynamic>>[],
                  'commentsCount': food['commentsCount'] ?? 0,
                };
              }).toList();
              
              if (_foodData[dateKey] == null) {
                _foodData[dateKey] = [];
              }
              _foodData[dateKey]!.addAll(processedFoods);
            }
          }
        }

        print('✅ Loaded ${querySnapshot.docs.length} food documents in a single query');
      } catch (e) {
        print('❌ Error loading food data with range query: $e');
        // Fallback to individual queries if range query fails
        await _loadFoodDataFallback(now);
      }

      setState(() {
        // Update UI after loading all data
      });
    } catch (e) {
      print('❌ Error loading food data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fallback method for individual document queries
  Future<void> _loadFoodDataFallback(DateTime now) async {
    print('🔄 Using fallback method with individual queries...');
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // Use batch processing to reduce loading time
    final futures = <Future<void>>[];
    
    for (int day = 1; day <= daysInMonth; day++) {
      final documentId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}-foods';
      
      futures.add(_loadSingleDayFood(documentId));
    }

    // Wait for all queries to complete
    await Future.wait(futures);
    print('✅ Fallback loading completed');
  }

  Future<void> _loadSingleDayFood(String documentId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final dateKey = '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';
        
        // Extract foods array from the document
        if (data['foods'] != null && data['foods'] is List) {
          final foods = List<Map<String, dynamic>>.from(data['foods']);
          
          // Add backward compatibility for existing foods without new fields
          final processedFoods = foods.map((food) {
            return {
              'id': food['id'] ?? 'food_${DateTime.now().millisecondsSinceEpoch}_${foods.indexOf(food)}', // Ensure unique ID
              'name': food['name'] ?? 'Unknown Food',
              'description': food['description'] ?? '',
              'price': food['price'] ?? 0,
              'image': food['image'] ?? '',
              'createdAt': food['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
              'likes': food['likes'] ?? <String>[],
              'likesCount': food['likesCount'] ?? 0,
              'comments': food['comments'] ?? <Map<String, dynamic>>[],
              'commentsCount': food['commentsCount'] ?? 0,
            };
          }).toList();
          
          if (_foodData[dateKey] == null) {
            _foodData[dateKey] = [];
          }
          _foodData[dateKey]!.addAll(processedFoods);
        }
      }
    } catch (e) {
      // Skip documents that don't exist or can't be accessed
      // Don't print error for each missing document to reduce noise
    }
  }

  void _toggleView() {
    setState(() {
      _isWeekView = !_isWeekView;
    });
  }

  void _navigatePrevious() {
    setState(() {
      if (_isWeekView) {
        _currentDate = _currentDate.subtract(const Duration(days: 7));
      } else {
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      }
    });
    _loadFoodData(); // Reload data for new date range
  }

  void _navigateNext() {
    setState(() {
      if (_isWeekView) {
        _currentDate = _currentDate.add(const Duration(days: 7));
      } else {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      }
    });
    _loadFoodData(); // Reload data for new date range
  }

  void _onFoodTap(String date, String mealType, Map<String, dynamic> food) {
    // Show food details dialog with comments and likes
    showDialog(
      context: context,
      builder: (context) => FoodDetailDialog(
        food: food,
        dateKey: date,
        onFoodUpdated: (updatedFood) => _updateFoodInCalendar(date, updatedFood),
      ),
    );
  }

  void _updateFoodInCalendar(String date, Map<String, dynamic> updatedFood) {
    setState(() {
      if (_foodData[date] != null) {
        final foodIndex = _foodData[date]!.indexWhere((f) => f['id'] == updatedFood['id']);
        if (foodIndex != -1) {
          _foodData[date]![foodIndex] = updatedFood;
        }
      }
    });
  }

  void _onAddFood(String date, String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddFoodBottomSheet(
        selectedDate: date,
        onFoodAdded: (food) => _addFoodToCalendar(date, food),
      ),
    );
  }

  void _addFoodToCalendar(String date, Map<String, dynamic> food) {
    setState(() {
      if (_foodData[date] == null) {
        _foodData[date] = [];
      }
      _foodData[date]!.add(food);
    });
  }

  void _onDateTap(DateTime date) {
    if (!_isWeekView) {
      setState(() {
        _currentDate = date;
        _isWeekView = true;
      });
    }
  }

  Future<void> _refreshFoodData() async {
    await _loadFoodData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Food data synced successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showAddFoodBottomSheet() {
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });

    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    _onAddFood(todayKey, ''); // Pass empty string for mealType since we don't use it
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomAppBar(
        title: 'Food Plan',
        variant: CustomAppBarVariant.mealPlan,
      ),
      body: Column(
        children: [
          // Offline indicator
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.amber,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Offline - Showing cached food data',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Calendar header
          CalendarHeaderWidget(
            currentDate: _currentDate,
            isWeekView: _isWeekView,
            onPreviousPressed: _navigatePrevious,
            onNextPressed: _navigateNext,
            onViewToggle: _toggleView,
          ),

          // Calendar content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFoodData,
              color: colorScheme.primary,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading food data...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isWeekView
                      ? WeekViewWidget(
                          currentWeek: _currentDate,
                          weekMeals: _foodData,
                          onMealTap: _onFoodTap,
                          onAddMeal: _onAddFood,
                          onMealLongPress: (date, mealType, food) {}, // Remove long press functionality
                          onFoodUpdated: (updatedFood) {
                            // Find which date this food belongs to and update it
                            for (final dateKey in _foodData.keys) {
                              final foodIndex = _foodData[dateKey]!.indexWhere((f) => f['id'] == updatedFood['id']);
                              if (foodIndex != -1) {
                                _updateFoodInCalendar(dateKey, updatedFood);
                                break;
                              }
                            }
                          },
                        )
                      : MonthViewWidget(
                          currentMonth: _currentDate,
                          monthMeals: _foodData,
                          onDateTap: _onDateTap,
                          onAddMeal: _onAddFood,
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: FloatingActionButton(
              onPressed: _showAddFoodBottomSheet,
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: AppTheme.onPrimaryLight,
              elevation: 6,
              child: Icon(
                Icons.add,
                color: AppTheme.onPrimaryLight,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }
}