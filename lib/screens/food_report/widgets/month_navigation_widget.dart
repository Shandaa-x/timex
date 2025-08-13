import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class MonthNavigationWidget extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MonthNavigationWidget({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  String _getMonthName(int month) {
    const months = [
      '1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар',
      '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPreviousMonth,
            icon: Icon(
              Icons.chevron_left,
              color: AppTheme.primaryLight,
              size: 32,
            ),
          ),
          Text(
            '${_getMonthName(selectedMonth.month)} ${selectedMonth.year}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: onNextMonth,
            icon: Icon(
              Icons.chevron_right,
              color: AppTheme.primaryLight,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
