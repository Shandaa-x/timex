import 'package:flutter/material.dart';
import '../widgets/eaten_food_display_widget.dart';

class DailyTabScreen extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> unpaidFoodData;
  final String? selectedFoodFilter;
  final Function(String, int, Map<String, dynamic>) onMarkMealAsPaid;
  final VoidCallback onPayMonthly;
  final bool hasAnyFoodsInMonth;

  const DailyTabScreen({
    super.key,
    required this.unpaidFoodData,
    required this.selectedFoodFilter,
    required this.onMarkMealAsPaid,
    required this.onPayMonthly,
    required this.hasAnyFoodsInMonth,
  });

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: EatenFoodDisplayWidget(),
    );
  }
}
