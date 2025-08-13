import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../services/money_format.dart';
import '../services/food_data_service.dart';

class DailyBreakdownSectionWidget extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> unpaidFoodData;
  final String? selectedFoodFilter;
  final Function(String dateKey, int foodIndex, Map<String, dynamic> food)? onMarkMealAsPaid;
  final VoidCallback? onPayMonthly;
  final bool hasAnyFoodsInMonth; // New parameter to indicate if any foods exist

  const DailyBreakdownSectionWidget({
    super.key,
    required this.unpaidFoodData,
    this.selectedFoodFilter,
    this.onMarkMealAsPaid,
    this.onPayMonthly,
    required this.hasAnyFoodsInMonth, // Required parameter
  });

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Даваа',
      'Мягмар',
      'Лхагва',
      'Пүрэв',
      'Баасан',
      'Бямба',
      'Ням',
    ];
    return weekdays[weekday - 1];
  }

  Widget _buildFoodImage(Map<String, dynamic> food, {double size = 48}) {
    if (food['image'] != null && food['image'].isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(food['image']),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFoodPlaceholder(size),
          ),
        ),
      );
    } else {
      return _buildFoodPlaceholder(size);
    }
  }

  Widget _buildFoodPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedDates = unpaidFoodData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Calculate total monthly amount
    final totalMonthlyAmount = unpaidFoodData.values
        .expand((foods) => foods)
        .fold<int>(0, (sum, food) => sum + FoodDataService.getFoodPrice(food));
    
    final totalDays = unpaidFoodData.keys.length;
    final totalFoods = unpaidFoodData.values
        .fold<int>(0, (sum, foods) => sum + foods.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              selectedFoodFilter != null
                  ? 'Шүүсэн төлөгдөөгүй хоол'
                  : 'Төлөгдөөгүй хоолны жагсаалт',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Monthly payment summary card (only show if there are unpaid foods)
        if (sortedDates.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  blurRadius: 0.3,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Сарын нийт төлбөр',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  MoneyFormatService.formatWithSymbol(totalMonthlyAmount),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalDays өдөр • $totalFoods хоол',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPayMonthly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 209, 209, 209),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.credit_card, size: 20),
                    label: const Text(
                      'Сараар төлбөр төлөх',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Divider with "OR" text
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'эсвэл өдөр бүрээр төлөх',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (sortedDates.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: hasAnyFoodsInMonth ? Colors.green[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasAnyFoodsInMonth ? Colors.green[200]! : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    hasAnyFoodsInMonth 
                      ? Icons.check_circle_outline 
                      : Icons.no_meals_outlined,
                    size: 48,
                    color: hasAnyFoodsInMonth ? Colors.green[600] : Colors.grey[500],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasAnyFoodsInMonth
                      ? (selectedFoodFilter != null
                          ? 'Шүүсэн хоолны төлөгдөөгүй зүйл олдсонгүй'
                          : 'Бүх хоол төлөгдсөн байна! 🎉')
                      : 'Энэ сард хоол бүртгэгдээгүй байна',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: hasAnyFoodsInMonth ? Colors.green[700] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedDates.map((dateKey) {
            final foods = unpaidFoodData[dateKey]!;
            final date = DateTime.parse(dateKey);
            final dayTotal = foods.fold<int>(
              0,
              (sum, food) => sum + FoodDataService.getFoodPrice(food),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${date.month}/${date.day}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[800],
                              ),
                            ),
                            Text(
                              '${_getWeekdayName(date.weekday)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            MoneyFormatService.formatWithSymbol(dayTotal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Food items list
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ...foods.map((food) {
                          final foodName = FoodDataService.getFoodName(food);
                          final price = FoodDataService.getFoodPrice(food);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                // Food image
                                _buildFoodImage(food),
                                const SizedBox(width: 16),
                                // Food details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        foodName,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Price
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    MoneyFormatService.formatWithSymbol(price),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        // Single payment button for the day
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.payment, size: 20),
                            label: Text(
                              'Төлөх (${foods.length} хоол)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
