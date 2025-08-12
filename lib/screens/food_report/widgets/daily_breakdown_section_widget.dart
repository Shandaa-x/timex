import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/money_format.dart';
import '../services/food_data_service.dart';

class DailyBreakdownSectionWidget extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> unpaidFoodData;
  final String? selectedFoodFilter;
  final Function(String dateKey, int foodIndex, Map<String, dynamic> food) onMarkMealAsPaid;

  const DailyBreakdownSectionWidget({
    super.key,
    required this.unpaidFoodData,
    this.selectedFoodFilter,
    required this.onMarkMealAsPaid,
  });

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'
    ];
    return weekdays[weekday - 1];
  }

  List<Widget> _buildCommentsWidget(ThemeData theme, ColorScheme colorScheme, Map<String, dynamic> food) {
    final comments = FoodDataService.getFoodComments(food);
    if (comments.isNotEmpty) {
      return [
        const SizedBox(height: 4),
        Text(
          comments,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedDates = unpaidFoodData.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.payment_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              selectedFoodFilter != null ? 'Шүүсэн төлөгдөөгүй хоол' : 'Төлөгдөөгүй хоолны жагсаалт',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sortedDates.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedFoodFilter != null 
                      ? 'Шүүсэн хоолны төлөгдөөгүй зүйл олдсонгүй'
                      : 'Бүх хоол төлөгдсөн байна! 🎉',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedDates.map((dateKey) {
            final foods = unpaidFoodData[dateKey]!;
            final date = DateTime.parse(dateKey);
            final dayTotal = foods.fold<int>(0, (sum, food) => sum + FoodDataService.getFoodPrice(food));
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningLight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningLight.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header with unpaid amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.month}/${date.day}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${_getWeekdayName(date.weekday)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warningLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppTheme.warningLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              MoneyFormatService.formatWithSymbol(dayTotal),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warningLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Individual unpaid meals list
                  ...foods.map((food) {
                    final foodIndex = FoodDataService.getFoodIndex(food);
                    final price = FoodDataService.getFoodPrice(food);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.warningLight.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Meal info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: AppTheme.warningLight,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        FoodDataService.getFoodName(food),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ..._buildCommentsWidget(theme, colorScheme, food),
                              ],
                            ),
                          ),
                          
                          // Price and payment button
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                MoneyFormatService.formatWithSymbol(price),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.warningLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () => onMarkMealAsPaid(dateKey, foodIndex, food),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryLight,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(0, 32),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  icon: const Icon(Icons.payment, size: 14),
                                  label: const Text('Төлөх'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }),
      ],
    );
  }
}
