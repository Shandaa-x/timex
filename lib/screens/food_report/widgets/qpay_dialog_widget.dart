import 'package:flutter/material.dart';
import '../../../services/money_format.dart';
import '../services/food_data_service.dart';

class QPayDialogWidget extends StatelessWidget {
  final String type;
  final int amount;
  final List<Map<String, dynamic>> todayFoodsList;
  final int totalFoodsCount;
  final int monthlyFoodDaysCount;
  final double averageDailySpending;
  final VoidCallback onPrint;

  const QPayDialogWidget({
    super.key,
    required this.type,
    required this.amount,
    required this.todayFoodsList,
    required this.totalFoodsCount,
    required this.monthlyFoodDaysCount,
    required this.averageDailySpending,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QPay logo placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'QPay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              'QPay төлбөр',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              type == 'daily' ? 'Өдрийн хоолны төлбөр' : 'Сарын хоолны төлбөр',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                MoneyFormatService.formatWithSymbol(amount),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Payment Information for Printing
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ТӨЛБӨРИЙН МЭДЭЭЛЭЛ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildPaymentInfoRow('Төрөл:', type == 'daily' ? 'Өдрийн төлбөр' : 'Сарын төлбөр', theme, colorScheme),
                  _buildPaymentInfoRow('Дүн:', MoneyFormatService.formatWithSymbol(amount), theme, colorScheme),
                  _buildPaymentInfoRow('Огноо:', '${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', theme, colorScheme),
                  _buildPaymentInfoRow('Цаг:', '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', theme, colorScheme),
                  _buildPaymentInfoRow('Гүйлгээний дугаар:', 'TXN${DateTime.now().millisecondsSinceEpoch}', theme, colorScheme),
                  _buildPaymentInfoRow('Төлбөрийн хэрэгсэл:', 'QPay', theme, colorScheme),
                  
                  if (type == 'daily') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Өнөөдрийн хоолны жагсаалт:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(todayFoodsList.map((food) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              FoodDataService.getFoodName(food),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                          Text(
                            MoneyFormatService.formatWithSymbol(FoodDataService.getFoodPrice(food)),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ))),
                  ],
                  
                  if (type == 'monthly') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Сарын статистик:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentInfoRow('Нийт хоол:', '$totalFoodsCount', theme, colorScheme),
                    _buildPaymentInfoRow('Хоолтой өдөр:', '$monthlyFoodDaysCount', theme, colorScheme),
                    _buildPaymentInfoRow('Өдрийн дундаж:', MoneyFormatService.formatWithSymbol(averageDailySpending.toInt()), theme, colorScheme),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Цуцлах',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.print, size: 18),
                        const SizedBox(width: 8),
                        const Text('Хэвлэх'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoRow(String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface, 
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
