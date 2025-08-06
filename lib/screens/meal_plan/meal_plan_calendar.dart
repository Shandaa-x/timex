import 'package:flutter/material.dart';
import 'package:timex/screens/meal_plan/widgets/custom_app_bar.dart';
import 'package:timex/screens/meal_plan/widgets/custom_bottom_bar.dart';
import 'package:timex/screens/meal_plan/widgets/custom_icon_widget.dart';
import './widgets/calendar_header_widget.dart';
import './widgets/meal_context_menu.dart';
import './widgets/meal_selection_bottom_sheet.dart';
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

  // Mock meal plan data
  final Map<String, List<Map<String, dynamic>>> _mealPlanData = {
    '2025-08-04': [
      {
        "id": 1,
        "name": "Avocado Toast with Poached Egg",
        "image":
            "https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?fm=jpg&q=60&w=3000",
        "cookingTime": 15,
        "calories": 320,
        "mealType": "breakfast",
        "rating": 4.8,
      },
      {
        "id": 2,
        "name": "Mediterranean Quinoa Bowl",
        "image":
            "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?fm=jpg&q=60&w=3000",
        "cookingTime": 25,
        "calories": 450,
        "mealType": "lunch",
        "rating": 4.6,
      },
    ],
    '2025-08-05': [
      {
        "id": 3,
        "name": "Greek Yogurt Parfait",
        "image":
            "https://images.unsplash.com/photo-1488477181946-6428a0291777?fm=jpg&q=60&w=3000",
        "cookingTime": 5,
        "calories": 280,
        "mealType": "breakfast",
        "rating": 4.7,
      },
      {
        "id": 4,
        "name": "Grilled Salmon with Asparagus",
        "image":
            "https://images.unsplash.com/photo-1467003909585-2f8a72700288?fm=jpg&q=60&w=3000",
        "cookingTime": 30,
        "calories": 380,
        "mealType": "dinner",
        "rating": 4.9,
      },
    ],
    '2025-08-06': [
      {
        "id": 5,
        "name": "Chicken Caesar Salad",
        "image":
            "https://images.unsplash.com/photo-1546793665-c74683f339c1?fm=jpg&q=60&w=3000",
        "cookingTime": 20,
        "calories": 420,
        "mealType": "lunch",
        "rating": 4.5,
      },
    ],
    '2025-08-07': [
      {
        "id": 6,
        "name": "Beef Stir Fry",
        "image":
            "https://images.unsplash.com/photo-1603133872878-684f208fb84b?fm=jpg&q=60&w=3000",
        "cookingTime": 25,
        "calories": 520,
        "mealType": "dinner",
        "rating": 4.4,
      },
    ],
  };

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
  }

  void _navigateNext() {
    setState(() {
      if (_isWeekView) {
        _currentDate = _currentDate.add(const Duration(days: 7));
      } else {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      }
    });
  }

  void _onMealTap(String date, String mealType, Map<String, dynamic> meal) {
    // Navigate to recipe detail
    Navigator.pushNamed(context, '/recipe-detail');
  }

  void _onAddMeal(String date, String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MealSelectionBottomSheet(
        selectedDate: date,
        selectedMealType: mealType,
        onRecipeSelected: (recipe) => _addMealToPlan(date, mealType, recipe),
      ),
    );
  }

  void _onMealLongPress(
      String date, String mealType, Map<String, dynamic> meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MealContextMenu(
        meal: meal,
        dateKey: date,
        mealType: mealType,
        onEdit: () => _editMeal(date, mealType, meal),
        onRemove: () => _removeMeal(date, mealType, meal),
        onDuplicate: () => _duplicateMeal(date, mealType, meal),
        onFindAlternative: () => _findAlternative(date, mealType, meal),
      ),
    );
  }

  void _onDateTap(DateTime date) {
    if (!_isWeekView) {
      setState(() {
        _currentDate = date;
        _isWeekView = true;
      });
    }
  }

  void _addMealToPlan(
      String date, String mealType, Map<String, dynamic> recipe) {
    setState(() {
      if (_mealPlanData[date] == null) {
        _mealPlanData[date] = [];
      }

      // Remove existing meal of same type
      _mealPlanData[date]!
          .removeWhere((meal) => (meal['mealType'] as String) == mealType);

      // Add new meal
      final newMeal = Map<String, dynamic>.from(recipe);
      newMeal['mealType'] = mealType;
      _mealPlanData[date]!.add(newMeal);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${recipe['name']} added to ${_getMealTypeLabel(mealType)}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _editMeal(String date, String mealType, Map<String, dynamic> meal) {
    // Navigate to recipe detail for editing
    Navigator.pushNamed(context, '/recipe-detail');
  }

  void _removeMeal(String date, String mealType, Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Meal'),
        content: Text(
            'Are you sure you want to remove "${meal['name']}" from your meal plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _mealPlanData[date]?.removeWhere((m) =>
                    (m['id'] as int) == (meal['id'] as int) &&
                    (m['mealType'] as String) == mealType);
                if (_mealPlanData[date]?.isEmpty == true) {
                  _mealPlanData.remove(date);
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${meal['name']} removed from meal plan'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _duplicateMeal(String date, String mealType, Map<String, dynamic> meal) {
    // Show date picker for duplication
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Duplicate meal feature - select dates to copy "${meal['name']}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _findAlternative(
      String date, String mealType, Map<String, dynamic> meal) {
    // Show alternative recipes
    _onAddMeal(date, mealType);
  }

  Future<void> _refreshMealPlan() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Meal plan synced successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showAddMealBottomSheet() {
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });

    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MealSelectionBottomSheet(
        selectedDate: todayKey,
        selectedMealType: 'breakfast',
        onRecipeSelected: (recipe) =>
            _addMealToPlan(todayKey, 'breakfast', recipe),
      ),
    );
  }

  String _getMealTypeLabel(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return 'Meal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Meal Plan',
        variant: CustomAppBarVariant.mealPlan,
      ),
      body: Column(
        children: [
          // Offline indicator
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 2),
              color:
                  Colors.amber,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'cloud_off',
                    color: Colors.red,
                    size: 16,
                  ),
                  SizedBox(width: 2),
                  Text(
                    'Offline - Showing cached meal plans',
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
              onRefresh: _refreshMealPlan,
              color: Colors.white10,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.blue,
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Syncing meal plans...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isWeekView
                      ? WeekViewWidget(
                          currentWeek: _currentDate,
                          weekMeals: _mealPlanData,
                          onMealTap: _onMealTap,
                          onAddMeal: _onAddMeal,
                          onMealLongPress: _onMealLongPress,
                        )
                      : MonthViewWidget(
                          currentMonth: _currentDate,
                          monthMeals: _mealPlanData,
                          onDateTap: _onDateTap,
                          onAddMeal: _onAddMeal,
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
              onPressed: _showAddMealBottomSheet,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.red,
              elevation: 6,
              child: CustomIconWidget(
                iconName: 'add',
                color: Colors.red,
                size: 24,
              ),
            ),
          );
        },
      ),
      // bottomNavigationBar: const CustomBottomBar(
      //   currentIndex: 2,
      //   variant: CustomBottomBarVariant.standard,
      // ),
    );
  }
}