import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class RealtimeFoodTotalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot>? _eatensSubscription;

  /// Start listening to changes in the eatens collection for the current user
  /// and automatically update the totalFoodAmount in the users collection
  static void startListening() {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ No user logged in, cannot start food total listener');
      return;
    }

    debugPrint('🎧 Starting real-time food total listener for user: $userId');

    // Cancel any existing subscription
    stopListening();

    // Listen to all changes in the eatens subcollection
    _eatensSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('eatens')
        .snapshots()
        .listen(
          (snapshot) async {
            await _updateTotalFoodAmount(userId, snapshot);
          },
          onError: (error) {
            debugPrint('❌ Error in food total listener: $error');
          },
        );
  }

  /// Stop listening to changes in the eatens collection
  static void stopListening() {
    _eatensSubscription?.cancel();
    _eatensSubscription = null;
    debugPrint('🔇 Stopped food total listener');
  }

  /// Calculate and update the original food amount based on ALL records in the eatens collection
  /// Updates originalFoodAmount while preserving the payment tracking system
  static Future<void> _updateTotalFoodAmount(
    String userId,
    QuerySnapshot snapshot,
  ) async {
    try {
      // Calculate total amount from ALL documents in the eatens collection
      int totalFoodConsumed = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final price = data['totalPrice'] as int? ?? 0;
          // Count all records regardless of payment status
          if (price > 0) {
            totalFoodConsumed += price;
          }
        }
      }

      // Get current user data to preserve payment tracking
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        // Get current payment amounts array
        final List<dynamic> paymentAmountsList = userData['paymentAmounts'] ?? [];
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

        // Calculate remaining balance: totalFoodAmount = max(originalFoodAmount - sum(paymentAmounts), 0)
        final double remainingBalance = 
            totalPaymentsMade >= totalFoodConsumed.toDouble()
                ? 0.0
                : totalFoodConsumed.toDouble() - totalPaymentsMade;

        // Determine payment status
        String qpayStatus;
        bool paymentStatus;
        if (totalPaymentsMade >= totalFoodConsumed.toDouble()) {
          qpayStatus = 'paid';
          paymentStatus = true;
        } else if (totalPaymentsMade > 0) {
          qpayStatus = 'partial';
          paymentStatus = false;
        } else {
          qpayStatus = 'none';
          paymentStatus = false;
        }

        // Update user document with new originalFoodAmount and recomputed values
        await _firestore.collection('users').doc(userId).update({
          'originalFoodAmount': totalFoodConsumed.toDouble(), // Total consumed food
          'totalFoodAmount': remainingBalance, // Remaining balance after payments
          'qpayStatus': qpayStatus,
          'paymentStatus': paymentStatus,
          'lastFoodUpdate': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '✅ Real-time updated: originalFoodAmount=$totalFoodConsumed, '
          'totalPaymentsMade=$totalPaymentsMade, remainingBalance=$remainingBalance, '
          'status=$qpayStatus (from ${snapshot.docs.length} total records)',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating food amounts in real-time: $e');
    }
  }

  /// Manually trigger a one-time calculation and update (fallback method)
  /// Recomputes originalFoodAmount and remaining balance with payment tracking
  static Future<void> forceUpdateTotalFoodAmount() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ No user logged in, cannot force update food total');
      return;
    }

    try {
      // Get all eaten records for this user
      final eatensSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('eatens')
          .get();

      // Calculate total amount from ALL eatens records
      int totalFoodConsumed = 0;
      for (final doc in eatensSnapshot.docs) {
        final data = doc.data();
        final price = data['totalPrice'] as int? ?? 0;
        // Count all records regardless of payment status
        if (price > 0) {
          totalFoodConsumed += price;
        }
      }

      // Get current user data to preserve payment tracking
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        // Get current payment amounts array
        final List<dynamic> paymentAmountsList = userData['paymentAmounts'] ?? [];
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

        // Calculate remaining balance: totalFoodAmount = max(originalFoodAmount - sum(paymentAmounts), 0)
        final double remainingBalance = 
            totalPaymentsMade >= totalFoodConsumed.toDouble()
                ? 0.0
                : totalFoodConsumed.toDouble() - totalPaymentsMade;

        // Determine payment status
        String qpayStatus;
        bool paymentStatus;
        if (totalPaymentsMade >= totalFoodConsumed.toDouble()) {
          qpayStatus = 'paid';
          paymentStatus = true;
        } else if (totalPaymentsMade > 0) {
          qpayStatus = 'partial';
          paymentStatus = false;
        } else {
          qpayStatus = 'none';
          paymentStatus = false;
        }

        // Update user document with recomputed values
        await _firestore.collection('users').doc(userId).update({
          'originalFoodAmount': totalFoodConsumed.toDouble(), // Total consumed food
          'totalFoodAmount': remainingBalance, // Remaining balance after payments
          'qpayStatus': qpayStatus,
          'paymentStatus': paymentStatus,
          'lastFoodUpdate': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '✅ Force updated: originalFoodAmount=$totalFoodConsumed, '
          'totalPaymentsMade=$totalPaymentsMade, remainingBalance=$remainingBalance, '
          'status=$qpayStatus',
        );
      }
    } catch (e) {
      debugPrint('❌ Error force updating food amounts: $e');
      rethrow;
    }
  }

  /// Get the current remaining balance (totalFoodAmount) from the users collection
  /// This represents the remaining amount to be paid after all payments
  static Future<double> getCurrentRemainingBalance() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ No user logged in, cannot get current remaining balance');
      return 0.0;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final dynamic rawTotalFoodAmount = userData?['totalFoodAmount'] ?? 0.0;
        return rawTotalFoodAmount is String
            ? double.tryParse(rawTotalFoodAmount) ?? 0.0
            : (rawTotalFoodAmount as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      debugPrint('❌ Error getting current remaining balance: $e');
      return 0.0;
    }
  }

  /// Get the original total food amount (before any payments)
  static Future<double> getOriginalFoodAmount() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ No user logged in, cannot get original food amount');
      return 0.0;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final dynamic rawOriginalFoodAmount = userData?['originalFoodAmount'] ?? 0.0;
        return rawOriginalFoodAmount is String
            ? double.tryParse(rawOriginalFoodAmount) ?? 0.0
            : (rawOriginalFoodAmount as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      debugPrint('❌ Error getting original food amount: $e');
      return 0.0;
    }
  }
}
