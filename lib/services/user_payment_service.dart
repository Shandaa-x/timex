import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Service for handling user payment status and food amount updates in Firestore
class UserPaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Process payment and update user's balance with array-based payment tracking
  static Future<Map<String, dynamic>> processPayment({
    required String userId,
    required double paidAmount,
    required String paymentMethod,
    required String invoiceId,
    String? orderId,
  }) async {
    try {
      AppLogger.info(
        'Processing payment for user: $userId, amount: ₮$paidAmount',
      );

      final userDocRef = _firestore.collection('users').doc(userId);
      final paymentsRef = userDocRef.collection('payments');

      return await _firestore.runTransaction((transaction) async {
        // Get current user document
        final userDoc = await transaction.get(userDocRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        final userData = userDoc.data()!;

        // Get original total food amount (the baseline amount from food consumption)
        final dynamic rawOriginalFoodAmount =
            userData['originalFoodAmount'] ?? 0.0;
        final double originalFoodAmount = rawOriginalFoodAmount is String
            ? double.tryParse(rawOriginalFoodAmount) ?? 0.0
            : (rawOriginalFoodAmount as num).toDouble();

        // Get current payment amounts array
        final List<dynamic> currentPayments = userData['paymentAmounts'] ?? [];
        final List<double> paymentAmounts = currentPayments
            .map(
              (payment) => payment is String
                  ? double.tryParse(payment) ?? 0.0
                  : (payment as num).toDouble(),
            )
            .toList();

        // Add new payment to the array
        paymentAmounts.add(paidAmount);

        // Calculate total payments made (sum of all payments in array)
        final double totalPaymentsMade = paymentAmounts.fold(
          0.0,
          (sum, amount) => sum + amount,
        );

        // Calculate remaining food amount
        final double newTotalFoodAmount =
            (originalFoodAmount - totalPaymentsMade).clamp(
              0.0,
              double.infinity,
            );

        // Determine payment status based on remaining balance
        String paymentStatus;
        bool isFullyPaid = false;
        if (newTotalFoodAmount == 0.0 ||
            totalPaymentsMade >= originalFoodAmount) {
          paymentStatus = 'paid'; // Fully paid
          isFullyPaid = true;
        } else if (totalPaymentsMade > 0) {
          paymentStatus = 'partial'; // Partial payment made
        } else {
          paymentStatus = 'pending'; // No effective payment (edge case)
        }

        // Create payment record with enhanced details
        final paymentDocRef = paymentsRef.doc();
        final paymentRecord = {
          'amount': paidAmount,
          'status': 'completed',
          'date': FieldValue.serverTimestamp(),
          'method': paymentMethod,
          'invoiceId': invoiceId,
          'orderId': orderId,
          'originalFoodAmount': originalFoodAmount,
          'totalPaymentsMade': totalPaymentsMade,
          'remainingBalance': newTotalFoodAmount,
          'paymentIndex':
              paymentAmounts.length - 1, // Index of this payment in the array
          'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(paymentDocRef, paymentRecord);

        // Update user document with array-based payment tracking
        Map<String, dynamic> updateData = {
          'totalFoodAmount': newTotalFoodAmount,
          'paymentAmounts':
              paymentAmounts, // Store all payment amounts in array
          'qpayStatus': paymentStatus,
          'paymentStatus': isFullyPaid, // Boolean field for easier querying
          'lastPaymentAmount': paidAmount,
          'lastPaymentInvoiceId':
              invoiceId, // Track the invoice ID for this payment
          'lastPaymentDate': FieldValue.serverTimestamp(),
          'lastPaymentStatusUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Set originalFoodAmount if it doesn't exist (for first payment)
        if (!userData.containsKey('originalFoodAmount')) {
          final dynamic rawCurrentTotal = userData['totalFoodAmount'] ?? 0.0;
          final double currentTotal = rawCurrentTotal is String
              ? double.tryParse(rawCurrentTotal) ?? 0.0
              : (rawCurrentTotal as num).toDouble();
          updateData['originalFoodAmount'] = currentTotal + paidAmount;
        }

        transaction.update(userDocRef, updateData);

        AppLogger.success(
          'Payment processed: ₮$paidAmount added to payment array. '
          'Total payments: ₮$totalPaymentsMade, Remaining: ₮$newTotalFoodAmount, Status: $paymentStatus',
        );

        return {
          'success': true,
          'originalAmount': originalFoodAmount,
          'totalPaymentsMade': totalPaymentsMade,
          'newAmount': newTotalFoodAmount,
          'paidAmount': paidAmount,
          'status': paymentStatus,
          'paymentId': paymentDocRef.id,
          'paymentIndex': paymentAmounts.length - 1,
        };
      });
    } catch (error) {
      AppLogger.error('Error processing payment: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Update payment status (for pending payments)
  static Future<Map<String, dynamic>> updatePaymentStatus({
    required String userId,
    required String status, // 'pending'
  }) async {
    try {
      AppLogger.info('Updating payment status for user: $userId to $status');

      final userDocRef = _firestore.collection('users').doc(userId);

      await userDocRef.update({
        'qpayStatus': status,
        'lastPaymentStatusUpdate': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'status': status};
    } catch (error) {
      AppLogger.error('Error updating payment status: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get current user's payment status and food amount with dynamic calculation
  static Future<Map<String, dynamic>> getUserPaymentInfo([
    String? userId,
  ]) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }

      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final data = userDoc.data()!;

      // Safe parsing for potentially string values from Firebase
      final dynamic rawTotalFoodAmount = data['totalFoodAmount'] ?? 0.0;
      final dynamic rawLastPaymentAmount = data['lastPaymentAmount'] ?? 0.0;
      final dynamic rawOriginalFoodAmount = data['originalFoodAmount'] ?? 0.0;

      // Get payment amounts array and calculate total dynamically
      final List<dynamic> paymentAmountsList = data['paymentAmounts'] ?? [];
      final List<double> paymentAmounts = paymentAmountsList
          .map(
            (payment) => payment is String
                ? double.tryParse(payment) ?? 0.0
                : (payment as num).toDouble(),
          )
          .toList();

      final double totalPaymentsMade = paymentAmounts.fold(
        0.0,
        (sum, amount) => sum + amount,
      );

      final double totalFoodAmount = rawTotalFoodAmount is String
          ? double.tryParse(rawTotalFoodAmount) ?? 0.0
          : (rawTotalFoodAmount as num).toDouble();

      // Get the stored qpayStatus from Firebase
      final String storedQpayStatus = data['qpayStatus'] ?? 'none';

      // Override payment status logic: if totalFoodAmount > 0, user has balance to pay
      // regardless of what's stored in the database
      final String actualQpayStatus = totalFoodAmount > 0
          ? 'pending'
          : storedQpayStatus;

      return {
        'success': true,
        'totalFoodAmount': totalFoodAmount,
        'originalFoodAmount': rawOriginalFoodAmount is String
            ? double.tryParse(rawOriginalFoodAmount) ?? 0.0
            : (rawOriginalFoodAmount as num).toDouble(),
        'totalPaymentsMade':
            totalPaymentsMade, // Calculated dynamically from array
        'paymentAmounts':
            paymentAmounts, // Return the array for detailed tracking
        'paymentCount': paymentAmounts.length, // Number of payments made
        'qpayStatus': actualQpayStatus, // Use the calculated status
        'paymentStatus': data['paymentStatus'] ?? false, // Boolean status
        'lastPaymentAmount': rawLastPaymentAmount is String
            ? double.tryParse(rawLastPaymentAmount) ?? 0.0
            : (rawLastPaymentAmount as num).toDouble(),
        'lastPaymentDate': data['lastPaymentDate'],
        'lastPaymentStatusUpdate': data['lastPaymentStatusUpdate'],
      };
    } catch (error) {
      AppLogger.error('Error getting user payment info: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get payment history for a user
  static Future<List<Map<String, dynamic>>> getPaymentHistory(
    String userId,
  ) async {
    try {
      final paymentsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      return paymentsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'status': data['status'] ?? 'unknown',
          'date': data['date'],
          'method': data['method'] ?? 'unknown',
          'invoiceId': data['invoiceId'],
          'orderId': data['orderId'],
          'previousBalance': data['previousBalance'] ?? 0.0,
          'newBalance': data['newBalance'] ?? 0.0,
        };
      }).toList();
    } catch (error) {
      AppLogger.error('Error getting payment history: $error');
      return [];
    }
  }

  /// Initialize or ensure user document exists with array-based payment tracking
  static Future<void> ensureUserDocument([String? userId]) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }

      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        await userDocRef.set({
          'totalFoodAmount': 0.0,
          'originalFoodAmount': 0.0,
          'paymentAmounts': [], // Array to store individual payment amounts
          'qpayStatus': 'none',
          'paymentStatus': false, // Boolean for easier querying
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        AppLogger.info(
          'User document created with array-based payment tracking',
        );
      } else {
        // Migration: If user exists but doesn't have array structure, migrate
        final userData = userDoc.data()!;
        if (!userData.containsKey('paymentAmounts')) {
          Map<String, dynamic> migrationData = {
            'paymentAmounts': [], // Initialize empty array
            'originalFoodAmount': userData['totalFoodAmount'] ?? 0.0,
            'paymentStatus': false,
          };

          // If totalPaymentsMade exists, convert it to array (basic migration)
          final dynamic existingPayments = userData['totalPaymentsMade'];
          if (existingPayments != null && existingPayments > 0) {
            final double totalPaid = existingPayments is String
                ? double.tryParse(existingPayments) ?? 0.0
                : (existingPayments as num).toDouble();
            migrationData['paymentAmounts'] = [
              totalPaid,
            ]; // Store as single payment
            migrationData['paymentStatus'] =
                totalPaid >= (userData['totalFoodAmount'] ?? 0.0);
          }

          await userDocRef.update(migrationData);
          AppLogger.info(
            'User document migrated to array-based payment tracking',
          );
        }
      }
    } catch (error) {
      AppLogger.error('Error ensuring user document: $error');
    }
  }

  /// Get detailed payment breakdown including individual payments
  static Future<Map<String, dynamic>> getPaymentBreakdown([
    String? userId,
  ]) async {
    try {
      final paymentInfo = await getUserPaymentInfo(userId);
      if (paymentInfo['success'] != true) {
        return paymentInfo;
      }

      final List<double> paymentAmounts = paymentInfo['paymentAmounts'] ?? [];
      final double totalPaymentsMade = paymentInfo['totalPaymentsMade'] ?? 0.0;
      final double originalFoodAmount =
          paymentInfo['originalFoodAmount'] ?? 0.0;
      final double remainingBalance = paymentInfo['totalFoodAmount'] ?? 0.0;

      return {
        'success': true,
        'breakdown': {
          'originalAmount': originalFoodAmount,
          'totalPaid': totalPaymentsMade,
          'remainingBalance': remainingBalance,
          'paymentCount': paymentAmounts.length,
          'individualPayments': paymentAmounts
              .asMap()
              .entries
              .map(
                (entry) => {
                  'index': entry.key,
                  'amount': entry.value,
                  'isLast': entry.key == paymentAmounts.length - 1,
                },
              )
              .toList(),
          'paymentProgress': originalFoodAmount > 0
              ? (totalPaymentsMade / originalFoodAmount * 100).clamp(0.0, 100.0)
              : 0.0,
        },
      };
    } catch (error) {
      AppLogger.error('Error getting payment breakdown: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Remove a specific payment from the array (for refunds or corrections)
  static Future<Map<String, dynamic>> removePayment({
    required String userId,
    required int paymentIndex,
    String? reason,
  }) async {
    try {
      AppLogger.info(
        'Removing payment at index $paymentIndex for user: $userId',
      );

      final userDocRef = _firestore.collection('users').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userDocRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        final userData = userDoc.data()!;
        final List<dynamic> currentPayments = userData['paymentAmounts'] ?? [];

        if (paymentIndex < 0 || paymentIndex >= currentPayments.length) {
          throw Exception('Invalid payment index: $paymentIndex');
        }

        final List<double> paymentAmounts = currentPayments
            .map(
              (payment) => payment is String
                  ? double.tryParse(payment) ?? 0.0
                  : (payment as num).toDouble(),
            )
            .toList();

        final double removedAmount = paymentAmounts[paymentIndex];
        paymentAmounts.removeAt(paymentIndex);

        // Recalculate totals
        final double totalPaymentsMade = paymentAmounts.fold(
          0.0,
          (sum, amount) => sum + amount,
        );
        final double originalFoodAmount = userData['originalFoodAmount'] ?? 0.0;
        final double newTotalFoodAmount =
            (originalFoodAmount - totalPaymentsMade).clamp(
              0.0,
              double.infinity,
            );

        // Update payment status
        String paymentStatus;
        bool isFullyPaid = false;
        if (newTotalFoodAmount == 0.0 ||
            totalPaymentsMade >= originalFoodAmount) {
          paymentStatus = 'paid';
          isFullyPaid = true;
        } else if (totalPaymentsMade > 0) {
          paymentStatus = 'partial';
        } else {
          paymentStatus = 'pending';
        }

        // Update user document
        transaction.update(userDocRef, {
          'totalFoodAmount': newTotalFoodAmount,
          'paymentAmounts': paymentAmounts,
          'qpayStatus': paymentStatus,
          'paymentStatus': isFullyPaid,
          'lastPaymentAmount': paymentAmounts.isNotEmpty
              ? paymentAmounts.last
              : 0.0,
          'lastPaymentStatusUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.success(
          'Payment removed: ₮$removedAmount at index $paymentIndex. '
          'Total payments: ₮$totalPaymentsMade, Remaining: ₮$newTotalFoodAmount',
        );

        return {
          'success': true,
          'removedAmount': removedAmount,
          'removedIndex': paymentIndex,
          'totalPaymentsMade': totalPaymentsMade,
          'newAmount': newTotalFoodAmount,
          'status': paymentStatus,
          'reason': reason,
        };
      });
    } catch (error) {
      AppLogger.error('Error removing payment: $error');
      return {'success': false, 'error': error.toString()};
    }
  }
}
