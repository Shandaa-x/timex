import 'package:flutter/material.dart';
import '../widgets/daily_breakdown_section_widget.dart';

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
    return SingleChildScrollView(
      child: DailyBreakdownSectionWidget(
        unpaidFoodData: unpaidFoodData,
        selectedFoodFilter: selectedFoodFilter,
        onMarkMealAsPaid: onMarkMealAsPaid,
        onPayMonthly: onPayMonthly,
        hasAnyFoodsInMonth: hasAnyFoodsInMonth,
      ),
    );
  }
}
