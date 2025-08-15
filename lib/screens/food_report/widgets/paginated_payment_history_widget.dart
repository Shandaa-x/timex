import 'package:flutter/material.dart';
import '../../../widgets/individual_food_payment_history.dart';

/// Main payment history widget that displays individual food items with their payment status
/// This replaces the old generic payment card approach with per-food tracking
class PaginatedPaymentHistoryWidget extends StatelessWidget {
  const PaginatedPaymentHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the individual food payment history widget
    // This shows each food item with its unique ID, payment status, and remaining balance
    return const IndividualFoodPaymentHistory();
  }
}