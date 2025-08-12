import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/money_format.dart';

class SummarySectionWidget extends StatelessWidget {
  final int unpaidCount;
  final int paidTotal;
  final int totalCost;
  final double paymentBalance;
  final String? selectedFoodFilter;
  final VoidCallback onFilterPressed;

  const SummarySectionWidget({
    super.key,
    required this.unpaidCount,
    required this.paidTotal,
    required this.totalCost,
    required this.paymentBalance,
    this.selectedFoodFilter,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Төлбөрийн тойм',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            // Filter button
            // TextButton.icon(
            //   onPressed: onFilterPressed,
            //   icon: Icon(
            //     selectedFoodFilter != null ? Icons.filter_alt : Icons.filter_alt_outlined,
            //     size: 18,
            //     color: AppTheme.primaryLight,
            //   ),
            //   label: Text(
            //     selectedFoodFilter ?? 'Бүгд',
            //     style: TextStyle(
            //       color: AppTheme.primaryLight,
            //       fontWeight: FontWeight.w500,
            //     ),
            //   ),
            // ),
          ],
        ),
        const SizedBox(height: 12),

        // First row: Unpaid meals count and paid amount
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                selectedFoodFilter != null ? 'Шүүсэн төлөгдөөгүй' : 'Нийт хоол',
                '$unpaidCount',
                Icons.schedule,
                AppTheme.warningLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Төлсөн дүн',
                MoneyFormatService.formatWithSymbol(paidTotal),
                Icons.check_circle,
                AppTheme.successLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Second row: Total food cost and payment balance
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Нийт хоолны зардал',
                MoneyFormatService.formatWithSymbol(totalCost),
                Icons.restaurant,
                colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Төлбөрийн үлдэгдэл',
                MoneyFormatService.formatBalance(paymentBalance),
                Icons.savings,
                paymentBalance >= 0 ? AppTheme.successLight : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            'wrgwergregerggrge',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
