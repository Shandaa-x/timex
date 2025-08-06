import 'package:flutter/material.dart';

class WeekViewWidget extends StatelessWidget {
  final DateTime currentWeek;
  final Map<String, List<Map<String, dynamic>>> weekMeals;
  final Function(String date, String mealType, Map<String, dynamic> meal)
      onMealTap;
  final Function(String date, String mealType) onAddMeal;
  final Function(String date, String mealType, Map<String, dynamic> meal)
      onMealLongPress;

  const WeekViewWidget({
    super.key,
    required this.currentWeek,
    required this.weekMeals,
    required this.onMealTap,
    required this.onAddMeal,
    required this.onMealLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final weekStart =
        currentWeek.subtract(Duration(days: currentWeek.weekday - 1));
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
                          ? colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getDayName(day.weekday),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isToday
                                ? colorScheme.primary
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
                                ? colorScheme.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isToday
                                    ? colorScheme.onPrimary
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

          // Meals grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: weekDays.map((day) {
                  final dateKey = _formatDateKey(day);
                  final dayMeals = weekMeals[dateKey] ?? [];

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
                                ? colorScheme.primary.withOpacity(0.05)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${_getDayName(day.weekday)}, ${_getMonthName(day.month)} ${day.day}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _isToday(day)
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              if (_isToday(day))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Today',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Meal slots
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _buildMealSlot(context, dateKey, 'breakfast',
                                  dayMeals, 'Breakfast'),
                              const SizedBox(height: 16),
                              _buildMealSlot(
                                  context, dateKey, 'lunch', dayMeals, 'Lunch'),
                              const SizedBox(height: 16),
                              _buildMealSlot(context, dateKey, 'dinner',
                                  dayMeals, 'Dinner'),
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

  Widget _buildMealSlot(BuildContext context, String dateKey, String mealType,
      List<Map<String, dynamic>> dayMeals, String mealLabel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final meal =
        dayMeals.where((m) => (m['mealType'] as String) == mealType).isNotEmpty
            ? dayMeals.firstWhere((m) => (m['mealType'] as String) == mealType)
            : null;

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: meal != null
            ? colorScheme.primary.withOpacity(0.05)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: meal != null
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: meal != null
          ? _buildMealCard(context, dateKey, mealType, meal)
          : _buildEmptySlot(context, dateKey, mealType, mealLabel),
    );
  }

  Widget _buildMealCard(BuildContext context, String dateKey, String mealType,
      Map<String, dynamic> meal) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () => onMealTap(dateKey, mealType, meal),
      onLongPress: () => onMealLongPress(dateKey, mealType, meal),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Recipe image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                meal['image'] as String? ??
                    'https://images.unsplash.com/photo-1546554137-f86b9593a222?fm=jpg&q=60&w=3000',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // Recipe details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    meal['name'] as String? ?? 'Unknown Recipe',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meal['cookingTime'] ?? 30} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.local_fire_department,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meal['calories'] ?? 250} cal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action button
            GestureDetector(
              onTap: () => onMealLongPress(dateKey, mealType, meal),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  color: colorScheme.primary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot(
      BuildContext context, String dateKey, String mealType, String mealLabel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () => onAddMeal(dateKey, mealType),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add $mealLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
}
