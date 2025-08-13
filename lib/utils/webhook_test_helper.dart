import 'package:firebase_auth/firebase_auth.dart';
import '../services/qpay_webhook_service.dart';

/// Test helper for simulating QPay webhooks
class WebhookTestHelper {
  
  /// Simulate a successful payment webhook
  static Future<Map<String, dynamic>> simulateSuccessfulPayment({
    double amount = 10000.0, // Default 10,000 MNT
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No authenticated user',
        };
      }

      // Create mock webhook data
      final webhookData = {
        'payment_status': 'PAID',
        'paid_amount': amount,
        'user_id': user.uid,
        'invoice_id': 'MOCK_INVOICE_${DateTime.now().millisecondsSinceEpoch}',
        'transaction_id': 'MOCK_TXN_${DateTime.now().millisecondsSinceEpoch}',
        'payment_date': DateTime.now().toIso8601String(),
        'payment_method': 'bank_app',
      };

      print('🧪 Simulating webhook with data: $webhookData');

      // Process the webhook
      final result = await QPayWebhookService.processWebhook(webhookData);

      print('✅ Webhook simulation result: $result');
      
      return result;
      
    } catch (error) {
      print('❌ Webhook simulation error: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  /// Simulate a failed payment webhook
  static Future<Map<String, dynamic>> simulateFailedPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No authenticated user',
        };
      }

      // Create mock webhook data for failed payment
      final webhookData = {
        'payment_status': 'FAILED',
        'user_id': user.uid,
        'invoice_id': 'MOCK_INVOICE_${DateTime.now().millisecondsSinceEpoch}',
        'failure_reason': 'Insufficient funds',
      };

      print('🧪 Simulating failed payment webhook: $webhookData');

      // Process the webhook
      final result = await QPayWebhookService.processWebhook(webhookData);

      print('✅ Failed payment simulation result: $result');
      
      return result;
      
    } catch (error) {
      print('❌ Failed payment simulation error: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  /// Simulate a cancelled payment webhook
  static Future<Map<String, dynamic>> simulateCancelledPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No authenticated user',
        };
      }

      // Create mock webhook data for cancelled payment
      final webhookData = {
        'payment_status': 'CANCELLED',
        'user_id': user.uid,
        'invoice_id': 'MOCK_INVOICE_${DateTime.now().millisecondsSinceEpoch}',
        'cancellation_reason': 'User cancelled',
      };

      print('🧪 Simulating cancelled payment webhook: $webhookData');

      // Process the webhook
      final result = await QPayWebhookService.processWebhook(webhookData);

      print('✅ Cancelled payment simulation result: $result');
      
      return result;
      
    } catch (error) {
      print('❌ Cancelled payment simulation error: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  /// Test the complete flow: check balance → simulate payment → check new balance
  static Future<void> testCompleteFlow({double paymentAmount = 5000.0}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user for complete flow test');
        return;
      }

      print('🧪 Starting complete payment flow test...');

      // Step 1: Check initial balance
      print('\n📊 Step 1: Checking initial balance...');
      final initialBalance = await QPayWebhookService.getUserFoodAmount(user.uid);
      print('Initial balance: ₮${initialBalance.toStringAsFixed(0)}');

      // Step 2: Simulate payment
      print('\n💳 Step 2: Simulating payment of ₮${paymentAmount.toStringAsFixed(0)}...');
      final result = await simulateSuccessfulPayment(amount: paymentAmount);
      
      if (result['success'] == true) {
        print('✅ Payment processed successfully');
        
        // Step 3: Check new balance
        print('\n📊 Step 3: Checking new balance...');
        final newBalance = await QPayWebhookService.getUserFoodAmount(user.uid);
        final expectedBalance = initialBalance - paymentAmount;
        
        print('New balance: ₮${newBalance.toStringAsFixed(0)}');
        print('Expected balance: ₮${expectedBalance.toStringAsFixed(0)}');
        
        if ((newBalance - expectedBalance).abs() < 0.01) {
          print('✅ Balance correctly updated!');
        } else {
          print('❌ Balance mismatch!');
        }
        
      } else {
        print('❌ Payment processing failed: ${result['error']}');
      }

      print('\n🏁 Complete flow test finished');
      
    } catch (error) {
      print('❌ Complete flow test error: $error');
    }
  }
}