import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class MonthViewWidget extends StatelessWidget {
  final DateTime currentMonth;
  final Map<String, List<Map<String, dynamic>>> monthMeals;
  final Map<String, bool> eatenForDayData; // Add eaten data
  final Function(DateTime date) onDateTap;
  final Function(String date, String mealType) onAddMeal;
  final Function(String date, String mealType, Map<String, dynamic> food)? onFoodTap;
  final Function(Map<String, dynamic> food)? onFoodDelete;
  final Function(Map<String, dynamic> food)? onFoodEdit;

  const MonthViewWidget({
    super.key,
    required this.currentMonth,
    required this.monthMeals,
    required this.eatenForDayData,
    required this.onDateTap,
    required this.onAddMeal,
    this.onFoodTap,
    this.onFoodDelete,
    this.onFoodEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                childAspectRatio: 0.7, // Increased from 0.8 to give more height
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: calendarDays.length,
              itemBuilder: (context, index) {
                final date = calendarDays[index];
                final isCurrentMonth = date.month == currentMonth.month;
                final isToday = _isToday(date);
                final dateKey = _formatDateKey(date);
                final hasEatenFood = eatenForDayData[dateKey] ?? false; // Check if user ate food
                final dayMeals = monthMeals[dateKey] ?? [];

                return GestureDetector(
                  onTap: () {
                    if (dayMeals.isNotEmpty) {
                      _showFoodListDialog(context, date, dayMeals, dateKey);
                    } else {
                      onDateTap(date);
                    }
                  },
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
                          padding: const EdgeInsets.symmetric(vertical: 4), // Reduced from 8
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
                              fontSize: 12, // Reduced font size
                            ),
                          ),
                        ),

                        // Food indicators - now based on eaten data
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Reduced padding
                            child: hasEatenFood
                                ? _buildEatenFoodIndicator(context)
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

  Widget _buildEatenFoodIndicator(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show checkmark for eaten food
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.successLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.check,
            color: Colors.white,
            size: 10,
          ),
        ),
        
        const SizedBox(height: 2),
        
        // Food icon
        Icon(
          Icons.restaurant,
          color: AppTheme.successLight,
          size: 12,
        ),
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

  void _showFoodListDialog(BuildContext context, DateTime date, List<Map<String, dynamic>> dayMeals, String dateKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    '${date.day}/${date.month}/${date.year} - Хоол',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Food list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: dayMeals.length,
                itemBuilder: (context, index) {
                  final food = dayMeals[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryLight,
                        child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        food['name'] ?? 'Unknown Food',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${food['price'] ?? 0}₮'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          Navigator.of(context).pop();
                          if (value == 'edit') {
                            onFoodEdit?.call(food);
                          } else if (value == 'delete') {
                            _showDeleteConfirmDialog(context, food);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Засах'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Устгах'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onFoodEdit?.call(food);
                      },
                    ),
                  );
                },
              ),
            ),
            
            // Add food button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAddMeal(dateKey, '');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Хоол нэмэх'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Map<String, dynamic> food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Хоол устгах'),
        content: Text('Та "${food['name'] ?? 'Unknown Food'}" хоолыг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болих'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onFoodDelete?.call(food);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
  }
}
