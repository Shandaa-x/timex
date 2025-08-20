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

  /// Calculate and update the total food amount based on the eatens collection
  static Future<void> _updateTotalFoodAmount(
    String userId,
    QuerySnapshot snapshot,
  ) async {
    try {
      // Calculate gross total amount from all documents in the eatens collection
      int grossTotalFoodAmount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final price = data['totalPrice'] as int? ?? 0;
          grossTotalFoodAmount += price;
        }
      }

      // Get current user data to check for payments
      final userDoc = await _firestore.collection('users').doc(userId).get();
      double totalPaymentsMade = 0.0;

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final paymentAmounts =
            userData['paymentAmounts'] as List<dynamic>? ?? [];

        // Calculate total payments made
        totalPaymentsMade = paymentAmounts.fold(0.0, (sum, payment) {
          if (payment is num) {
            return sum + payment.toDouble();
          } else if (payment is String) {
            return sum + (double.tryParse(payment) ?? 0.0);
          }
          return sum;
        });
      }

      // Calculate remaining balance (gross total - payments made)
      final double remainingBalance =
          (grossTotalFoodAmount.toDouble() - totalPaymentsMade).clamp(
            0.0,
            double.infinity,
          );

      // Update the totalFoodAmount in the users collection
      // Note: totalFoodAmount represents the remaining amount owed (after payments)
      await _firestore.collection('users').doc(userId).update({
        'totalFoodAmount': remainingBalance,
        'originalFoodAmount': grossTotalFoodAmount
            .toDouble(), // Store gross total for reference
        'lastFoodUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '✅ Real-time updated totalFoodAmount: $remainingBalance (gross: $grossTotalFoodAmount, payments: $totalPaymentsMade, from ${snapshot.docs.length} eaten records)',
      );
    } catch (e) {
      debugPrint('❌ Error updating totalFoodAmount in real-time: $e');
    }
  }

  /// Manually trigger a one-time calculation and update (fallback method)
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

      // Calculate gross total amount from all eatens
      int grossTotalFoodAmount = 0;
      for (final doc in eatensSnapshot.docs) {
        final data = doc.data();
        final price = data['totalPrice'] as int? ?? 0;
        grossTotalFoodAmount += price;
      }

      // Get current user data to check for payments
      final userDoc = await _firestore.collection('users').doc(userId).get();
      double totalPaymentsMade = 0.0;

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final paymentAmounts =
            userData['paymentAmounts'] as List<dynamic>? ?? [];

        // Calculate total payments made
        totalPaymentsMade = paymentAmounts.fold(0.0, (sum, payment) {
          if (payment is num) {
            return sum + payment.toDouble();
          } else if (payment is String) {
            return sum + (double.tryParse(payment) ?? 0.0);
          }
          return sum;
        });
      }

      // Calculate remaining balance (gross total - payments made)
      final double remainingBalance =
          (grossTotalFoodAmount.toDouble() - totalPaymentsMade).clamp(
            0.0,
            double.infinity,
          );

      // Update the totalFoodAmount in users collection
      await _firestore.collection('users').doc(userId).update({
        'totalFoodAmount': remainingBalance,
        'originalFoodAmount': grossTotalFoodAmount
            .toDouble(), // Store gross total for reference
        'lastFoodUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '✅ Force updated totalFoodAmount: $remainingBalance (gross: $grossTotalFoodAmount, payments: $totalPaymentsMade)',
      );
    } catch (e) {
      debugPrint('❌ Error force updating totalFoodAmount: $e');
      rethrow;
    }
  }

  /// Get the current total food amount from the users collection
  static Future<int> getCurrentTotalFoodAmount() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ No user logged in, cannot get current food total');
      return 0;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['totalFoodAmount'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting current totalFoodAmount: $e');
      return 0;
    }
  }
}
