import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class FoodFrequencySectionWidget extends StatelessWidget {
  final Map<String, int> foodStats;
  final String? selectedFoodFilter;

  const FoodFrequencySectionWidget({
    super.key,
    required this.foodStats,
    this.selectedFoodFilter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sortedFoods = foodStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedFoodFilter != null ? 'Шүүсэн төлөгдөөгүй хоол' : 'Төлөгдөөгүй хоолны давтамж',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (sortedFoods.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                selectedFoodFilter != null 
                  ? 'Шүүсэн төлөгдөөгүй хоол олдсонгүй'
                  : 'Төлөгдөөгүй хоол байхгүй байна 🎉',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          )
        else
          ...sortedFoods.take(5).map((entry) {
            final maxCount = sortedFoods.first.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} удаа',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value / maxCount,
                    backgroundColor: colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successLight),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
