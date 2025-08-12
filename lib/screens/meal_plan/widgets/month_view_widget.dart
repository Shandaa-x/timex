import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

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
    final colorScheme = Colors.white;
    
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
                        color: Colors.black.withOpacity(0.6),
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
                          ? Colors.white
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? AppTheme.primaryLight
                            : Colors.black.withOpacity(0.2),
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
                                      ? AppTheme.primaryLight
                                      : Colors.black)
                                  : Colors.black.withOpacity(0.4),
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),

                        // Food indicators
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: dayMeals.isNotEmpty
                                ? _buildFoodIndicators(context, dayMeals)
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

  Widget _buildFoodIndicators(BuildContext context, List<Map<String, dynamic>> dayFoods) {
    final theme = Theme.of(context);
    
    // Calculate total likes and comments
    final totalLikes = dayFoods.fold<int>(0, (sum, food) => sum + ((food['likesCount'] as int?) ?? 0));
    final totalComments = dayFoods.fold<int>(0, (sum, food) => sum + ((food['commentsCount'] as int?) ?? 0));
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Show food count as a badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.successLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${dayFoods.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.onPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        const SizedBox(height: 2),
        
        // Food icon
        Icon(
          Icons.restaurant,
          color: AppTheme.successLight,
          size: 12,
        ),
        
        // Show interaction counts if any
        if (totalLikes > 0 || totalComments > 0) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (totalLikes > 0) ...[
                Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 8,
                ),
                Text(
                  '$totalLikes',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (totalLikes > 0 && totalComments > 0) const SizedBox(width: 2),
              if (totalComments > 0) ...[
                Icon(
                  Icons.chat_bubble,
                  color: AppTheme.primaryLight,
                  size: 8,
                ),
                Text(
                  '$totalComments',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyIndicator(
      BuildContext context, String dateKey, bool isCurrentMonth) {
    if (!isCurrentMonth) return const SizedBox.shrink();

    // Check if the date is in the past
    final selectedDate = DateTime.parse(dateKey);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isPastDate = selectedDateOnly.isBefore(todayDate);

    return GestureDetector(
      onTap: isPastDate ? null : () => onAddMeal(dateKey, ''), // Disable tap for past dates
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isPastDate ? Icons.block : Icons.add_circle_outline,
          color: isPastDate 
              ? AppTheme.primaryLight.withOpacity(0.2)
              : AppTheme.primaryLight.withOpacity(0.4),
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
