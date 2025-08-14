import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/screens/home/widgets/custom_sliver_appbar.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_drawer.dart';
import './widgets/calendar_header_widget.dart';
import './widgets/add_food_bottom_sheet.dart';
import './widgets/food_detail_dialog.dart';
import './widgets/month_view_widget.dart';
import './widgets/week_view_widget.dart';

class MealPlanCalendar extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const MealPlanCalendar({super.key, this.onNavigateToTab});

  @override
  State<MealPlanCalendar> createState() => _MealPlanCalendarState();
}

class _MealPlanCalendarState extends State<MealPlanCalendar>
    with TickerProviderStateMixin {
  bool _isWeekView = true;
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  bool _isOffline = false;

  // Filtering state
  bool _isFilterMode = false;
  String? _selectedFilter;
  final List<String> _filterOptions = [
    'All',
    'High Price',
    'Popular',
    'Recent',
    'With Comments',
  ];

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  // Food data - map of date string to list of foods
  final Map<String, List<Map<String, dynamic>>> _foodData = {};
  Map<String, List<Map<String, dynamic>>> _filteredFoodData = {};

  // Helper to get current user ID
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Initialize filtered data with all data
    _filteredFoodData = Map.from(_foodData);

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
      final startDocId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01-foods';
      final endDocId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}-foods';

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
            final dateKey =
                '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';

            // Extract foods array from the document
            if (data['foods'] != null && data['foods'] is List) {
              final foods = List<Map<String, dynamic>>.from(data['foods']);

              // Add backward compatibility for existing foods without new fields
              final processedFoods = foods.map((food) {
                return {
                  'id':
                      food['id'] ??
                      'food_${DateTime.now().millisecondsSinceEpoch}_${foods.indexOf(food)}', // Ensure unique ID
                  'name': food['name'] ?? 'Unknown Food',
                  'description': food['description'] ?? '',
                  'price': food['price'] ?? 0,
                  'image': food['image'] ?? '',
                  'createdAt':
                      food['createdAt'] ??
                      DateTime.now().millisecondsSinceEpoch,
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

        print(
          '✅ Loaded ${querySnapshot.docs.length} food documents in a single query',
        );
      } catch (e) {
        print('❌ Error loading food data with range query: $e');
        // Fallback to individual queries if range query fails
        await _loadFoodDataFallback(now);
      }

      setState(() {
        // Update UI after loading all data
        // Update filtered data after loading
        if (_isFilterMode) {
          _applyFilter();
        } else {
          _filteredFoodData = Map.from(_foodData);
        }
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
      final documentId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}-foods';

      futures.add(_loadSingleDayFood(documentId));
    }

    // Wait for all queries to complete
    await Future.wait(futures);
    print('✅ Fallback loading completed');
  }

  Future<void> _loadSingleDayFood(String documentId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('foods')
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final dateKey =
            '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';

        // Extract foods array from the document
        if (data['foods'] != null && data['foods'] is List) {
          final foods = List<Map<String, dynamic>>.from(data['foods']);

          // Add backward compatibility for existing foods without new fields
          final processedFoods = foods.map((food) {
            return {
              'id':
                  food['id'] ??
                  'food_${DateTime.now().millisecondsSinceEpoch}_${foods.indexOf(food)}', // Ensure unique ID
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
      if (_isFilterMode) {
        // If in filter mode, cycle through filter options
        _cycleFilter();
      } else {
        // Toggle between week and month view
        _isWeekView = !_isWeekView;
      }
    });
  }

  void _cycleFilter() {
    if (_selectedFilter == null) {
      _selectedFilter = _filterOptions[1]; // Start with 'High Price'
    } else {
      final currentIndex = _filterOptions.indexOf(_selectedFilter!);
      final nextIndex = (currentIndex + 1) % _filterOptions.length;
      _selectedFilter = _filterOptions[nextIndex];

      if (_selectedFilter == 'All') {
        _selectedFilter = null; // Reset to show all
      }
    }
    _applyFilter();
  }

  void _applyFilter() {
    _filteredFoodData.clear();

    if (_selectedFilter == null) {
      // Show all foods
      _filteredFoodData = Map.from(_foodData);
      return;
    }

    for (final entry in _foodData.entries) {
      final filteredFoods = entry.value.where((food) {
        switch (_selectedFilter) {
          case 'High Price':
            return (food['price'] as int? ?? 0) >=
                8000; // Foods 8000₮ and above
          case 'Popular':
            return (food['likesCount'] as int? ?? 0) >=
                3; // Foods with 3+ likes
          case 'Recent':
            final createdAt = food['createdAt'] as int? ?? 0;
            final foodDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
            final daysDiff = DateTime.now().difference(foodDate).inDays;
            return daysDiff <= 7; // Foods added in last 7 days
          case 'With Comments':
            return (food['commentsCount'] as int? ?? 0) >
                0; // Foods with comments
          default:
            return true;
        }
      }).toList();

      if (filteredFoods.isNotEmpty) {
        _filteredFoodData[entry.key] = filteredFoods;
      }
    }
  }

  void _toggleFilterMode() {
    setState(() {
      _isFilterMode = !_isFilterMode;
      if (!_isFilterMode) {
        _selectedFilter = null;
        _filteredFoodData = Map.from(_foodData);
      } else {
        _applyFilter();
      }
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
        onFoodUpdated: (updatedFood) =>
            _updateFoodInCalendar(date, updatedFood),
      ),
    );
  }

  void _updateFoodInCalendar(String date, Map<String, dynamic> updatedFood) {
    setState(() {
      if (_foodData[date] != null) {
        final foodIndex = _foodData[date]!.indexWhere(
          (f) => f['id'] == updatedFood['id'],
        );
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

      // Update filtered data if in filter mode
      if (_isFilterMode) {
        _applyFilter();
      } else {
        _filteredFoodData = Map.from(_foodData);
      }
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

    _onAddFood(
      todayKey,
      '',
    ); // Pass empty string for mealType since we don't use it
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentScreen: DrawerScreenType.mealPlan,
        onNavigateToTab: widget.onNavigateToTab,
      ),
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(title: 'Хоолны хуваарь'),
          
          // Offline indicator
          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.amber,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.red, size: 16),
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
            ),
          
          // Calendar header
          SliverToBoxAdapter(
            child: CalendarHeaderWidget(
              currentDate: _currentDate,
              isWeekView: _isWeekView,
              onPreviousPressed: _navigatePrevious,
              onNextPressed: _navigateNext,
              onViewToggle: _toggleView,
              onFilterModeToggle: _toggleFilterMode,
              isFilterMode: _isFilterMode,
              selectedFilter: _selectedFilter,
            ),
          ),
          
          // Loading state
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
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
              ),
            ),
          
          // Calendar content using original widgets
          if (!_isLoading)
            SliverToBoxAdapter(
              child: Container(
                height: MediaQuery.of(context).size.height - 200, // Set a proper height
                child: RefreshIndicator(
                  onRefresh: _refreshFoodData,
                  color: colorScheme.primary,
                  child: _isWeekView
                      ? WeekViewWidget(
                          currentWeek: _currentDate,
                          weekMeals: _isFilterMode
                              ? _filteredFoodData
                              : _foodData,
                          onMealTap: _onFoodTap,
                          onAddMeal: _onAddFood,
                          onMealLongPress:
                              (
                                date,
                                mealType,
                                food,
                              ) {}, // Remove long press functionality
                          onFoodUpdated: (updatedFood) {
                            // Find which date this food belongs to and update it
                            for (final dateKey in _foodData.keys) {
                              final foodIndex = _foodData[dateKey]!.indexWhere(
                                (f) => f['id'] == updatedFood['id'],
                              );
                              if (foodIndex != -1) {
                                _updateFoodInCalendar(dateKey, updatedFood);
                                break;
                              }
                            }
                          },
                        )
                      : MonthViewWidget(
                          currentMonth: _currentDate,
                          monthMeals: _isFilterMode
                              ? _filteredFoodData
                              : _foodData,
                          onDateTap: _onDateTap,
                          onAddMeal: _onAddFood,
                        ),
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
              child: Icon(Icons.add, color: AppTheme.onPrimaryLight, size: 24),
            ),
          );
        },
      ),
    );
  }
}
