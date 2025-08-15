import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_payment_models.dart';

/// Comprehensive service for handling individual food payments
class FoodPaymentService {
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  static CollectionReference get _userFoodsCollection => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_currentUserId)
      .collection('foods');

  static CollectionReference get _paymentTransactionsCollection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('paymentTransactions');

  /// Add a new food item to the user's collection
  static Future<bool> addFoodItem(FoodItem foodItem) async {
    try {
      await _userFoodsCollection.doc(foodItem.id).set(foodItem.toMap());
      print('✅ Food item added: ${foodItem.name} (${foodItem.id})');
      return true;
    } catch (e) {
      print('❌ Error adding food item: $e');
      return false;
    }
  }

  /// Add multiple food items in a batch
  static Future<bool> addMultipleFoodItems(List<FoodItem> foodItems) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final foodItem in foodItems) {
        final docRef = _userFoodsCollection.doc(foodItem.id);
        batch.set(docRef, foodItem.toMap());
      }

      await batch.commit();
      print('✅ Added ${foodItems.length} food items successfully');
      return true;
    } catch (e) {
      print('❌ Error adding multiple food items: $e');
      return false;
    }
  }

  /// Get all food items for the current user
  static Future<List<FoodItem>> getAllFoodItems() async {
    try {
      final snapshot = await _userFoodsCollection
          .orderBy('selectedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FoodItem.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting food items: $e');
      return [];
    }
  }

  /// Get food items with pagination
  static Future<List<FoodItem>> getFoodItems({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    FoodPaymentStatus? statusFilter,
  }) async {
    try {
      Query query = _userFoodsCollection.orderBy(
        'selectedDate',
        descending: true,
      );

      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FoodItem.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting paginated food items: $e');
      return [];
    }
  }

  /// Get real-time stream of food items
  static Stream<List<FoodItem>> getFoodItemsStream({
    int limit = 50,
    FoodPaymentStatus? statusFilter,
  }) {
    Query query = _userFoodsCollection
        .orderBy('selectedDate', descending: true)
        .limit(limit);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => FoodItem.fromMap(doc.data() as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Process payment for multiple food items
  static Future<PaymentResult> processPayment({
    required List<String> foodIds,
    required double paymentAmount,
    required String method,
    String? invoiceId,
    String? transactionId,
  }) async {
    try {
      print(
        '🔄 Processing payment: ₮$paymentAmount for ${foodIds.length} foods',
      );

      // Get all food items to be paid
      final foodItems = await _getFoodItemsByIds(foodIds);

      if (foodItems.isEmpty) {
        return PaymentResult(
          success: false,
          message: 'No food items found',
          updatedFoodItems: [],
          paymentTransaction: null,
        );
      }

      // Sort foods by selection date (oldest first for fair payment distribution)
      foodItems.sort((a, b) => a.selectedDate.compareTo(b.selectedDate));

      // Distribute payment across food items
      final paymentDistribution = _distributePaymentAcrossFoods(
        foodItems,
        paymentAmount,
      );

      // Create payment transaction record
      final paymentTransaction = PaymentTransaction(
        id: transactionId ?? 'txn_${DateTime.now().millisecondsSinceEpoch}',
        totalAmount: paymentAmount,
        paymentDate: DateTime.now(),
        method: method,
        invoiceId: invoiceId,
        foodIds: foodIds,
        foodPaymentDistribution: paymentDistribution,
      );

      // Update food items with new payment amounts
      final updatedFoodItems = <FoodItem>[];
      final batch = FirebaseFirestore.instance.batch();

      for (final foodItem in foodItems) {
        final paidAmountForThisFood = paymentDistribution[foodItem.id] ?? 0.0;

        if (paidAmountForThisFood > 0) {
          // Create payment record for this food
          final paymentRecord = FoodPaymentRecord(
            id: '${paymentTransaction.id}_${foodItem.id}',
            amount: paidAmountForThisFood,
            paymentDate: DateTime.now(),
            method: method,
            invoiceId: invoiceId,
            transactionId: paymentTransaction.id,
          );

          // Calculate new amounts
          final newPaidAmount = foodItem.paidAmount + paidAmountForThisFood;
          final newRemainingBalance = (foodItem.price - newPaidAmount).clamp(
            0.0,
            foodItem.price,
          );
          final newStatus = _determinePaymentStatus(
            newPaidAmount,
            foodItem.price,
          );

          // Update food item
          final updatedFoodItem = foodItem.copyWith(
            paidAmount: newPaidAmount,
            remainingBalance: newRemainingBalance,
            status: newStatus,
            paymentHistory: [...foodItem.paymentHistory, paymentRecord],
          );

          updatedFoodItems.add(updatedFoodItem);

          // Add to batch update
          final docRef = _userFoodsCollection.doc(foodItem.id);
          batch.set(docRef, updatedFoodItem.toMap(), SetOptions(merge: true));

          print(
            '💰 Paid ₮$paidAmountForThisFood for ${foodItem.name} (${foodItem.id})',
          );
        } else {
          // No payment for this food, keep as is
          updatedFoodItems.add(foodItem);
        }
      }

      // Save payment transaction
      batch.set(
        _paymentTransactionsCollection.doc(paymentTransaction.id),
        paymentTransaction.toMap(),
      );

      // Commit all changes atomically
      await batch.commit();

      print(
        '✅ Payment processed successfully: ${updatedFoodItems.length} foods updated',
      );

      return PaymentResult(
        success: true,
        message: 'Payment processed successfully',
        updatedFoodItems: updatedFoodItems,
        paymentTransaction: paymentTransaction,
      );
    } catch (e) {
      print('❌ Error processing payment: $e');
      return PaymentResult(
        success: false,
        message: 'Error processing payment: $e',
        updatedFoodItems: [],
        paymentTransaction: null,
      );
    }
  }

  /// Get food items by their IDs
  static Future<List<FoodItem>> _getFoodItemsByIds(List<String> foodIds) async {
    try {
      final foodItems = <FoodItem>[];

      for (final foodId in foodIds) {
        final doc = await _userFoodsCollection.doc(foodId).get();
        if (doc.exists && doc.data() != null) {
          final foodItem = FoodItem.fromMap(doc.data() as Map<String, dynamic>);
          foodItems.add(foodItem);
        }
      }

      return foodItems;
    } catch (e) {
      print('❌ Error getting food items by IDs: $e');
      return [];
    }
  }

  /// Distribute payment amount across food items fairly
  static Map<String, double> _distributePaymentAcrossFoods(
    List<FoodItem> foodItems,
    double paymentAmount,
  ) {
    final distribution = <String, double>{};
    double remainingAmount = paymentAmount;

    // Pay foods in order of selection (oldest first)
    for (final foodItem in foodItems) {
      if (remainingAmount <= 0) break;

      final amountNeeded = foodItem.remainingBalance;
      if (amountNeeded > 0) {
        final amountToPay = remainingAmount >= amountNeeded
            ? amountNeeded
            : remainingAmount;
        distribution[foodItem.id] = amountToPay;
        remainingAmount -= amountToPay;

        print(
          '📝 Distributing ₮$amountToPay to ${foodItem.name} (needed: ₮$amountNeeded)',
        );
      }
    }

    return distribution;
  }

  /// Determine payment status based on paid amount and price
  static FoodPaymentStatus _determinePaymentStatus(
    double paidAmount,
    double price,
  ) {
    if (paidAmount >= price) {
      return FoodPaymentStatus.fullyPaid;
    } else if (paidAmount > 0) {
      return FoodPaymentStatus.partiallyPaid;
    } else {
      return FoodPaymentStatus.unpaid;
    }
  }

  /// Get payment summary for all food items
  static Future<PaymentSummary> getPaymentSummary() async {
    try {
      final allFoods = await getAllFoodItems();

      double totalFoodValue = 0;
      double totalPaidAmount = 0;
      double totalRemainingBalance = 0;
      int unpaidCount = 0;
      int partiallyPaidCount = 0;
      int fullyPaidCount = 0;

      for (final food in allFoods) {
        totalFoodValue += food.price;
        totalPaidAmount += food.paidAmount;
        totalRemainingBalance += food.remainingBalance;

        switch (food.status) {
          case FoodPaymentStatus.unpaid:
            unpaidCount++;
            break;
          case FoodPaymentStatus.partiallyPaid:
            partiallyPaidCount++;
            break;
          case FoodPaymentStatus.fullyPaid:
            fullyPaidCount++;
            break;
        }
      }

      return PaymentSummary(
        totalFoodValue: totalFoodValue,
        totalPaidAmount: totalPaidAmount,
        totalRemainingBalance: totalRemainingBalance,
        unpaidCount: unpaidCount,
        partiallyPaidCount: partiallyPaidCount,
        fullyPaidCount: fullyPaidCount,
        totalFoodCount: allFoods.length,
      );
    } catch (e) {
      print('❌ Error getting payment summary: $e');
      return PaymentSummary.empty();
    }
  }

  /// Get payment transactions for date range
  static Future<List<PaymentTransaction>> getPaymentTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _paymentTransactionsCollection.orderBy(
        'paymentDate',
        descending: true,
      );

      if (startDate != null) {
        query = query.where(
          'paymentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'paymentDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) =>
                PaymentTransaction.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('❌ Error getting payment transactions: $e');
      return [];
    }
  }

  /// Update a food item
  static Future<bool> updateFoodItem(FoodItem foodItem) async {
    try {
      await _userFoodsCollection
          .doc(foodItem.id)
          .set(foodItem.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      print('❌ Error updating food item: $e');
      return false;
    }
  }

  /// Delete a food item
  static Future<bool> deleteFoodItem(String foodId) async {
    try {
      await _userFoodsCollection.doc(foodId).delete();
      print('🗑️ Food item deleted: $foodId');
      return true;
    } catch (e) {
      print('❌ Error deleting food item: $e');
      return false;
    }
  }
}

/// Result class for payment processing
class PaymentResult {
  final bool success;
  final String message;
  final List<FoodItem> updatedFoodItems;
  final PaymentTransaction? paymentTransaction;

  PaymentResult({
    required this.success,
    required this.message,
    required this.updatedFoodItems,
    this.paymentTransaction,
  });
}
