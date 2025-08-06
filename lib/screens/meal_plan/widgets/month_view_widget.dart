import 'package:flutter/material.dart';

class MonthViewWidget extends StatelessWidget {
  final DateTime currentMonth;
  final Map<String, List<Map<String, dynamic>>> monthMeals;
  final Function(DateTime date) onDateTap;
  final Function(String date, String mealType) onAddMeal;

  const MonthViewWidget({
    super.key,
    required this.currentMonth,
    required this.monthMeals,
    required this.onDateTap,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // Calculate calendar grid
    final startDate =
        firstDayOfMonth.subtract(Duration(days: firstDayWeekday - 1));
    final totalDays = ((daysInMonth + firstDayWeekday - 1) / 7).ceil() * 7;
    final calendarDays = List.generate(
        totalDays, (index) => startDate.add(Duration(days: index)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Days of week header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children:
                  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.8,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: calendarDays.length,
              itemBuilder: (context, index) {
                final date = calendarDays[index];
                final isCurrentMonth = date.month == currentMonth.month;
                final isToday = _isToday(date);
                final dateKey = _formatDateKey(date);
                final dayMeals = monthMeals[dateKey] ?? [];

                return GestureDetector(
                  onTap: () => onDateTap(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isCurrentMonth
                          ? colorScheme.surface
                          : colorScheme.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.outline.withOpacity(0.2),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Date number
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${date.day}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isCurrentMonth
                                  ? (isToday
                                      ? colorScheme.primary
                                      : colorScheme.onSurface)
                                  : colorScheme.onSurface.withOpacity(0.4),
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),

                        // Meal indicators
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: dayMeals.isNotEmpty
                                ? _buildMealIndicators(dayMeals)
                                : _buildEmptyIndicator(
                                    context, dateKey, isCurrentMonth),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealIndicators(List<Map<String, dynamic>> dayMeals) {
    final mealTypes = ['breakfast', 'lunch', 'dinner'];
    final mealColors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Show up to 3 meal dots
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: mealTypes.asMap().entries.map((entry) {
            final index = entry.key;
            final mealType = entry.value;
            final hasMeal = dayMeals
                .any((meal) => (meal['mealType'] as String) == mealType);

            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hasMeal
                    ? mealColors[index]
                    : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            );
          }).toList(),
        ),

        // Meal count if more than 3
        if (dayMeals.length > 3) ...[
          const SizedBox(height: 4),
          Text(
            '+${dayMeals.length - 3}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyIndicator(
      BuildContext context, String dateKey, bool isCurrentMonth) {
    if (!isCurrentMonth) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onAddMeal(dateKey, 'breakfast'),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.add_circle_outline,
          color: Colors.blue.withOpacity(0.4),
          size: 16,
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
}
