import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Service for handling user payment status and food amount updates in Firestore
class UserPaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Process payment and update user's balance with array-based payment tracking
  /// Also clears daily subcollection totalPrice values to prevent double counting
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
      final eatensRef = userDocRef.collection('eatens');

      return await _firestore.runTransaction((transaction) async {
        // Get current user document
        final userDoc = await transaction.get(userDocRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        final userData = userDoc.data()!;

        // Get current payment amounts array
        final List<dynamic> currentPayments = userData['paymentAmounts'] ?? [];
        final List<double> paymentAmounts = currentPayments
            .map(
              (payment) => payment is String
                  ? double.tryParse(payment) ?? 0.0
                  : (payment as num).toDouble(),
            )
            .toList();

        // Get current unpaid food amount
        final dynamic rawTotalFoodAmount = userData['totalFoodAmount'] ?? 0.0;
        final double currentTotalFoodAmount = rawTotalFoodAmount is String
            ? double.tryParse(rawTotalFoodAmount) ?? 0.0
            : (rawTotalFoodAmount as num).toDouble();

        // Get or calculate original food amount (total before any payments)
        final dynamic rawOriginalFoodAmount = userData['originalFoodAmount'];
        final double originalFoodAmount = rawOriginalFoodAmount != null
            ? (rawOriginalFoodAmount is String
                  ? double.tryParse(rawOriginalFoodAmount) ?? 0.0
                  : (rawOriginalFoodAmount as num).toDouble())
            : currentTotalFoodAmount +
                  paymentAmounts.fold(0.0, (sum, amount) => sum + amount);

        // Add new payment to the array
        paymentAmounts.add(paidAmount);

        // Calculate total payments made (sum of all payments in array)
        final double totalPaymentsMade = paymentAmounts.fold(
          0.0,
          (sum, amount) => sum + amount,
        );

        // Calculate remaining food amount: totalFoodAmount = originalFoodAmount - sum(paymentAmounts)
        final double newTotalFoodAmount =
            totalPaymentsMade >= originalFoodAmount
            ? 0.0
            : originalFoodAmount - totalPaymentsMade;

        // Determine payment status based on remaining balance
        String paymentStatus;
        bool isFullyPaid = false;
        if (totalPaymentsMade >= originalFoodAmount) {
          paymentStatus = 'paid'; // Fully paid
          isFullyPaid = true;
        } else if (totalPaymentsMade > 0) {
          paymentStatus = 'partial'; // Partial payment made
        } else {
          paymentStatus = 'pending'; // No effective payment (edge case)
        }

        // Get unpaid daily records to clear their totalPrice
        final eatensSnapshot = await eatensRef.get();
        final List<String> dailyRecordsToClear = [];
        double amountToClear = paidAmount;

        // Collect daily records that should be marked as paid
        for (final doc in eatensSnapshot.docs) {
          if (amountToClear <= 0) break;

          final data = doc.data();
          final dailyPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
          final isPaidOff = data['isPaidOff'] as bool? ?? false;

          // Only include unpaid records
          if (!isPaidOff && dailyPrice > 0) {
            dailyRecordsToClear.add(doc.id);
            amountToClear -= dailyPrice;
          }
        }

        // Clear totalPrice for paid daily records
        for (final dailyRecordId in dailyRecordsToClear) {
          transaction.update(eatensRef.doc(dailyRecordId), {
            'isPaidOff': true,
            'paidOffAt': FieldValue.serverTimestamp(),
            'paymentIndex':
                paymentAmounts.length - 1, // Reference to payment in array
          });
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
          'dailyRecordsCleared':
              dailyRecordsToClear, // Track which daily records were paid
          'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(paymentDocRef, paymentRecord);

        // Update user document with array-based payment tracking
        Map<String, dynamic> updateData = {
          'totalFoodAmount': newTotalFoodAmount,
          'originalFoodAmount': originalFoodAmount,
          'paymentAmounts':
              paymentAmounts, // Store all payment amounts in array
          'qpayStatus': paymentStatus,
          'paymentStatus': isFullyPaid, // Boolean field for easier querying
          'lastPaymentAmount': paidAmount,
          'lastPaymentDate': FieldValue.serverTimestamp(),
          'lastPaymentStatusUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.update(userDocRef, updateData);

        AppLogger.success(
          'Payment processed: ₮$paidAmount added to payment array. '
          'Total payments: ₮$totalPaymentsMade, Remaining: ₮$newTotalFoodAmount, '
          'Cleared ${dailyRecordsToClear.length} daily records, Status: $paymentStatus',
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
          'dailyRecordsCleared': dailyRecordsToClear,
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
  /// Always recomputes totalFoodAmount to ensure accuracy after refresh
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
      final dynamic rawOriginalFoodAmount = data['originalFoodAmount'] ?? 0.0;
      final dynamic rawLastPaymentAmount = data['lastPaymentAmount'] ?? 0.0;

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
        (total, amount) => total + amount,
      );

      // Get or calculate original food amount
      final double originalFoodAmount = rawOriginalFoodAmount is String
          ? double.tryParse(rawOriginalFoodAmount) ?? 0.0
          : (rawOriginalFoodAmount as num).toDouble();

      // ALWAYS recompute totalFoodAmount dynamically: max(originalFoodAmount - sum(paymentAmounts), 0)
      final double recomputedTotalFoodAmount = 
          totalPaymentsMade >= originalFoodAmount
              ? 0.0
              : originalFoodAmount - totalPaymentsMade;

      // Determine payment status based on recomputed balance
      String qpayStatus;
      bool paymentStatus;
      if (totalPaymentsMade >= originalFoodAmount) {
        qpayStatus = 'paid';
        paymentStatus = true;
      } else if (totalPaymentsMade > 0) {
        qpayStatus = 'partial';
        paymentStatus = false;
      } else {
        qpayStatus = 'none';
        paymentStatus = false;
      }

      return {
        'success': true,
        'totalFoodAmount': recomputedTotalFoodAmount, // Always dynamically calculated
        'originalFoodAmount': originalFoodAmount,
        'totalPaymentsMade': totalPaymentsMade, // Calculated dynamically from array
        'paymentAmounts': paymentAmounts, // Return the array for detailed tracking
        'paymentCount': paymentAmounts.length, // Number of payments made
        'qpayStatus': qpayStatus, // Recomputed status
        'paymentStatus': paymentStatus, // Recomputed boolean status
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

  /// Remove a specific payment from the array and restore corresponding daily records
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
      final eatensRef = userDocRef.collection('eatens');
      final paymentsRef = userDocRef.collection('payments');

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

        // Find payment record to get which daily records were cleared
        final paymentQuery = await paymentsRef
            .where('paymentIndex', isEqualTo: paymentIndex)
            .limit(1)
            .get();

        List<String> dailyRecordsToRestore = [];
        if (paymentQuery.docs.isNotEmpty) {
          final paymentData = paymentQuery.docs.first.data();
          dailyRecordsToRestore = List<String>.from(
            paymentData['dailyRecordsCleared'] ?? [],
          );
        }

        // Restore daily records that were marked as paid
        for (final dailyRecordId in dailyRecordsToRestore) {
          transaction.update(eatensRef.doc(dailyRecordId), {
            'isPaidOff': false,
            'paidOffAt': FieldValue.delete(),
            'paymentIndex': FieldValue.delete(),
            'restoredAt': FieldValue.serverTimestamp(),
          });
        }

        // Recalculate totals: totalFoodAmount = originalFoodAmount - sum(paymentAmounts)
        final double totalPaymentsMade = paymentAmounts.fold(
          0.0,
          (sum, amount) => sum + amount,
        );
        final double originalFoodAmount = userData['originalFoodAmount'] ?? 0.0;
        final double newTotalFoodAmount =
            totalPaymentsMade >= originalFoodAmount
            ? 0.0
            : originalFoodAmount - totalPaymentsMade;

        // Update payment status
        String paymentStatus;
        bool isFullyPaid = false;
        if (totalPaymentsMade >= originalFoodAmount) {
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
          'Total payments: ₮$totalPaymentsMade, Remaining: ₮$newTotalFoodAmount, '
          'Restored ${dailyRecordsToRestore.length} daily records',
        );

        return {
          'success': true,
          'removedAmount': removedAmount,
          'removedIndex': paymentIndex,
          'totalPaymentsMade': totalPaymentsMade,
          'newAmount': newTotalFoodAmount,
          'status': paymentStatus,
          'reason': reason,
          'dailyRecordsRestored': dailyRecordsToRestore,
        };
      });
    } catch (error) {
      AppLogger.error('Error removing payment: $error');
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
}
