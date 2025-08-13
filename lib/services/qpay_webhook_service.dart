import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// QPay Webhook Service - Handles payment callbacks and Firebase updates
class QPayWebhookService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Process QPay webhook callback
  ///
  /// [webhookData] - Data received from QPay webhook
  ///
  /// Returns processing result
  static Future<Map<String, dynamic>> processWebhook(
    Map<String, dynamic> webhookData,
  ) async {
    try {
      AppLogger.info('Processing QPay webhook: $webhookData');

      // Extract payment information
      final String? paymentStatus = webhookData['payment_status'];
      final double? paidAmount = _parseDouble(webhookData['paid_amount']);
      final String? userId = webhookData['user_id'];
      // Note: invoice_id available if needed for tracking

      if (paymentStatus == null) {
        throw Exception('Missing payment_status in webhook data');
      }

      if (userId == null) {
        throw Exception('Missing user_id in webhook data');
      }

      AppLogger.info(
        'Payment Status: $paymentStatus, Amount: $paidAmount, User: $userId',
      );

      // Only process if payment was successful
      if (paymentStatus == "PAID") {
        if (paidAmount == null || paidAmount <= 0) {
          throw Exception('Invalid paid_amount: $paidAmount');
        }

        // Update user's totalAmountFood in Firebase
        await _updateUserFoodAmount(userId, paidAmount);

        // Log the payment
        await _logPayment(userId, paidAmount, webhookData);

        AppLogger.success(
          'Payment processed successfully: ₮$paidAmount for user $userId',
        );

        return {
          'success': true,
          'message': 'Payment processed successfully',
          'userId': userId,
          'paidAmount': paidAmount,
          'status': paymentStatus,
        };
      } else if (paymentStatus == "FAILED" || paymentStatus == "CANCELLED") {
        AppLogger.warning(
          'Payment $paymentStatus for user $userId, no changes made',
        );

        return {
          'success': true,
          'message': 'Payment $paymentStatus, no changes made',
          'userId': userId,
          'status': paymentStatus,
        };
      } else {
        AppLogger.warning('Unhandled payment status: $paymentStatus');

        return {
          'success': false,
          'message': 'Unhandled payment status: $paymentStatus',
          'status': paymentStatus,
        };
      }
    } catch (error) {
      AppLogger.error('QPayWebhookService.processWebhook error: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Update user's totalAmountFood in Firebase users collection
  ///
  /// [userId] - User's Firebase UID
  /// [paidAmount] - Amount paid by user
  ///
  /// Returns update result
  static Future<void> _updateUserFoodAmount(
    String userId,
    double paidAmount,
  ) async {
    try {
      final DocumentReference userDoc = _firestore
          .collection('users')
          .doc(userId);

      // Get current user data
      final DocumentSnapshot userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        throw Exception('User document not found: $userId');
      }

      final Map<String, dynamic>? userData =
          userSnapshot.data() as Map<String, dynamic>?;
      final double currentTotalAmountFood =
          _parseDouble(userData?['totalAmountFood']) ?? 0.0;

      // Subtract paid amount from current total
      final double newTotalAmountFood = currentTotalAmountFood - paidAmount;

      // Update user document
      await userDoc.update({
        'totalAmountFood': newTotalAmountFood,
        'lastPayment': paidAmount,
        'paymentStatus': true, // boolean field: true = paid, false = pending
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success(
        'Updated user $userId: totalAmountFood $currentTotalAmountFood -> $newTotalAmountFood (paid: ₮$paidAmount)',
      );
    } catch (error) {
      AppLogger.error('Error updating user food amount: $error');
      rethrow;
    }
  }

  /// Log payment to user's payment history
  ///
  /// [userId] - User's Firebase UID
  /// [paidAmount] - Amount paid
  /// [webhookData] - Original webhook data
  ///
  /// Returns logging result
  static Future<void> _logPayment(
    String userId,
    double paidAmount,
    Map<String, dynamic> webhookData,
  ) async {
    try {
      final CollectionReference paymentHistory = _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentHistory');

      final Map<String, dynamic> paymentRecord = {
        'amount': paidAmount,
        'type': 'food_payment',
        'description': 'QPay food payment',
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'transactionId':
            webhookData['transaction_id'] ??
            'QPAY_${DateTime.now().millisecondsSinceEpoch}',
        'invoiceId': webhookData['invoice_id'],
        'paymentMethod': 'QPay',
        'status': 'completed',
        'webhookData': webhookData,
      };

      await paymentHistory.add(paymentRecord);

      AppLogger.success('Payment logged to history for user $userId');
    } catch (error) {
      AppLogger.error('Error logging payment: $error');
      // Don't rethrow - logging failure shouldn't prevent payment processing
    }
  }

  /// Verify webhook authenticity (implement based on QPay documentation)
  ///
  /// [webhookData] - Data received from webhook
  /// [signature] - QPay signature (if provided)
  ///
  /// Returns verification result
  static bool verifyWebhook(
    Map<String, dynamic> webhookData,
    String? signature,
  ) {
    try {
      // TODO: Implement QPay webhook signature verification
      // This would typically involve:
      // 1. Creating expected signature using QPay secret key
      // 2. Comparing with received signature
      // 3. Returning true if they match

      AppLogger.info(
        'Webhook verification (placeholder) - always returns true',
      );
      return true;
    } catch (error) {
      AppLogger.error('Error verifying webhook: $error');
      return false;
    }
  }

  /// Set user payment status to pending
  ///
  /// [userId] - User's Firebase UID
  ///
  /// Returns update result
  static Future<void> setPaymentStatusPending(String userId) async {
    try {
      final DocumentReference userDoc = _firestore
          .collection('users')
          .doc(userId);

      await userDoc.update({
        'paymentStatus': false, // boolean field: false = pending
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Set payment status to pending for user: $userId');
    } catch (error) {
      AppLogger.error('Error setting payment status to pending: $error');
      // Don't rethrow - this is not critical
    }
  }

  /// Get user's current food amount
  ///
  /// [userId] - User's Firebase UID
  ///
  /// Returns current food amount
  static Future<double> getUserFoodAmount(String userId) async {
    try {
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return 0.0;
      }

      final Map<String, dynamic>? userData =
          userDoc.data() as Map<String, dynamic>?;

      return _parseDouble(userData?['totalAmountFood']) ?? 0.0;
    } catch (error) {
      AppLogger.error('Error getting user food amount: $error');
      return 0.0;
    }
  }

  /// Helper method to parse double values
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
