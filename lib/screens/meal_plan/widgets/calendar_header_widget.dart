import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CalendarHeaderWidget extends StatelessWidget {
  final DateTime currentDate;
  final bool isWeekView;
  final VoidCallback onPreviousPressed;
  final VoidCallback onNextPressed;
  final VoidCallback onViewToggle;

  const CalendarHeaderWidget({
    super.key,
    required this.currentDate,
    required this.isWeekView,
    required this.onPreviousPressed,
    required this.onNextPressed,
    required this.onViewToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Navigation arrows and date
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: onPreviousPressed,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getHeaderTitle(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubtitle(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onNextPressed,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // View toggle button
          GestureDetector(
            onTap: onViewToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWeekView
                        ? Icons.calendar_view_month
                        : Icons.calendar_view_week,
                    color: AppTheme.primaryLight,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isWeekView ? 'Month' : 'Week',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    if (isWeekView) {
      final weekStart =
          currentDate.subtract(Duration(days: currentDate.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      if (weekStart.month == weekEnd.month) {
        return '${_getMonthName(weekStart.month)} ${weekStart.day}-${weekEnd.day}';
      } else {
        return '${_getMonthName(weekStart.month)} ${weekStart.day} - ${_getMonthName(weekEnd.month)} ${weekEnd.day}';
      }
    } else {
      return '${_getMonthName(currentDate.month)} ${currentDate.year}';
    }
  }

  String _getSubtitle() {
    if (isWeekView) {
      return 'Week View';
    } else {
      final today = DateTime.now();
      final isCurrentMonth =
          currentDate.year == today.year && currentDate.month == today.month;
      return isCurrentMonth ? 'This Month' : 'Month View';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
