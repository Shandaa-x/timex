import 'package:flutter/material.dart';
import '../screens/food_management_screen.dart';
import '../services/food_payment_service.dart';

/// Example usage of the food payment system components
class FoodPaymentSystemDemo extends StatelessWidget {
  const FoodPaymentSystemDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Payment System'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: const FoodManagementScreen(),
    );
  }
}

/// Quick payment stats widget for dashboard or home screen
class QuickPaymentStatsWidget extends StatelessWidget {
  const QuickPaymentStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaymentStatsWidget();
  }
}

/// Example of how to integrate the food payment system into your main app
class FoodPaymentSystemIntegration {
  /// Add this to your main app routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/food-management':
        return MaterialPageRoute(
          builder: (context) => const FoodManagementScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (context) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }

  /// Example of how to navigate to food management from your main app
  static void navigateToFoodManagement(BuildContext context) {
    Navigator.pushNamed(context, '/food-management');
  }

  /// Example of how to check if there are unpaid foods (for notifications)
  static Future<bool> hasUnpaidFoods() async {
    try {
      final foods = await FoodPaymentService.getAllFoodItems();
      return foods.any((food) => food.remainingBalance > 0);
    } catch (e) {
      print('❌ Error checking unpaid foods: $e');
      return false;
    }
  }

  /// Example of how to get total unpaid amount (for dashboard)
  static Future<double> getTotalUnpaidAmount() async {
    try {
      final foods = await FoodPaymentService.getAllFoodItems();
      return foods.fold<double>(
        0.0,
        (sum, food) => sum + food.remainingBalance,
      );
    } catch (e) {
      print('❌ Error getting total unpaid amount: $e');
      return 0.0;
    }
  }
}

/// Example usage in your main.dart or app.dart
/// 
/// Add to your MaterialApp:
/// ```dart
/// MaterialApp(
///   title: 'Your App',
///   onGenerateRoute: FoodPaymentSystemIntegration.generateRoute,
///   home: YourHomeScreen(),
/// )
/// ```
/// 
/// Add to your home screen or dashboard:
/// ```dart
/// // Quick stats widget
/// QuickPaymentStatsWidget(),
/// 
/// // Navigation button
/// ElevatedButton(
///   onPressed: () => FoodPaymentSystemIntegration.navigateToFoodManagement(context),
///   child: Text('Manage Food Payments'),
/// ),
/// ```
/// 
/// Check for unpaid foods in your notification system:
/// ```dart
/// final hasUnpaid = await FoodPaymentSystemIntegration.hasUnpaidFoods();
/// if (hasUnpaid) {
///   // Show notification or badge
/// }
/// ```
