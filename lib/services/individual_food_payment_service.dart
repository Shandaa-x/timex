import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_payment_models.dart';

/// Service for handling payments per individual food item
class IndividualFoodPaymentService {
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
  
  static CollectionReference get _userFoodsCollection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('foods');
  
  static CollectionReference get _paymentTransactionsCollection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('paymentTransactions');

  /// Process payment across multiple food items
  /// Distributes payment amount to foods in order of selection
  static Future<PaymentResult> processPayment({
    required List<String> foodIds,
    required double paymentAmount,
    required String method,
    String? invoiceId,
    String? transactionId,
  }) async {
    try {
      // Get all food items
      final foodItems = await getFoodItemsByIds(foodIds);
      
      if (foodItems.isEmpty) {
        return PaymentResult(
          success: false,
          message: 'No food items found',
          updatedFoodItems: [],
          paymentTransaction: null,
        );
      }

      // Sort foods by selection date (order of selection)
      foodItems.sort((a, b) => a.selectedDate.compareTo(b.selectedDate));

      // Distribute payment across food items
      final paymentDistribution = _distributePayment(foodItems, paymentAmount);
      
      // Create payment transaction record with proper food details
      final paymentTransaction = PaymentTransaction(
        id: transactionId ?? 'txn_${DateTime.now().millisecondsSinceEpoch}',
        totalAmount: paymentAmount,
        paymentDate: DateTime.now(),
        method: method,
        invoiceId: invoiceId,
        foodIds: foodIds,
        foodPaymentDistribution: paymentDistribution,
      );

      // Create Firebase-compatible payment record with foodDetails and foodCount
      final firebasePaymentRecord = {
        'amount': paymentAmount,
        'method': method,
        'invoiceId': invoiceId ?? paymentTransaction.id,
        'transactionId': paymentTransaction.id,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'foodCount': foodItems.length,
        'foodDetails': foodItems.map((food) => {
          'id': food.id,
          'name': food.name,
          'price': food.price,
          'image': food.imageBase64 ?? '',
          'date': food.selectedDate.toIso8601String(),
          'paidAmount': paymentDistribution[food.id] ?? 0,
          'remainingBalance': (food.price - (food.paidAmount + (paymentDistribution[food.id] ?? 0))).clamp(0.0, food.price),
        }).toList(),
        'foodIds': foodIds,
        'paymentDistribution': paymentDistribution,
        // Determine if this is partial payment
        'totalFoodAmount': foodItems.fold<double>(0, (total, food) => total + food.price),
        'totalPaymentsMade': paymentAmount,
        'remainingBalance': foodItems.fold<double>(0, (total, food) => total + ((food.price - (food.paidAmount + (paymentDistribution[food.id] ?? 0))).clamp(0.0, food.price))),
        'originalFoodAmount': foodItems.fold<double>(0, (total, food) => total + food.price),
        'paymentIndex': 1, // This would need to be calculated based on previous payments
      };

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

          // Update food item
          final newPaidAmount = foodItem.paidAmount + paidAmountForThisFood;
          final newRemainingBalance = (foodItem.price - newPaidAmount).clamp(0.0, foodItem.price);
          final newStatus = newPaidAmount >= foodItem.price 
            ? FoodPaymentStatus.fullyPaid
            : (newPaidAmount > 0 ? FoodPaymentStatus.partiallyPaid : FoodPaymentStatus.unpaid);
          
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
        } else {
          updatedFoodItems.add(foodItem);
        }
      }

      // Save payment transaction with proper food details
      batch.set(_paymentTransactionsCollection.doc(paymentTransaction.id), 
               paymentTransaction.toMap());

      // Also save to the legacy payments collection for compatibility
      final legacyPaymentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('payments')
          .doc(paymentTransaction.id);
      
      batch.set(legacyPaymentRef, firebasePaymentRecord);

      // Commit all changes
      await batch.commit();

      return PaymentResult(
        success: true,
        message: 'Payment processed successfully',
        updatedFoodItems: updatedFoodItems,
        paymentTransaction: paymentTransaction,
      );

    } catch (e) {
      // Error processing payment
      return PaymentResult(
        success: false,
        message: 'Error processing payment: $e',
        updatedFoodItems: [],
        paymentTransaction: null,
      );
    }
  }

  /// Distribute payment amount across food items in order
  static Map<String, double> _distributePayment(
    List<FoodItem> foodItems, 
    double paymentAmount
  ) {
    final distribution = <String, double>{};
    double remainingAmount = paymentAmount;

    for (final foodItem in foodItems) {
      if (remainingAmount <= 0) break;

      final amountNeeded = foodItem.remainingBalance;
      if (amountNeeded > 0) {
        final amountToPay = remainingAmount >= amountNeeded ? amountNeeded : remainingAmount;
        distribution[foodItem.id] = amountToPay;
        remainingAmount -= amountToPay;
      }
    }

    return distribution;
  }

  /// Get food items by their IDs
  static Future<List<FoodItem>> getFoodItemsByIds(List<String> foodIds) async {
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
      // Error getting food items
      return [];
    }
  }

  /// Get all food items for the current user with pagination
  static Future<List<FoodItem>> getFoodItems({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    FoodPaymentStatus? statusFilter,
  }) async {
    try {
      Query query = _userFoodsCollection
          .orderBy('selectedDate', descending: true);

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
      // Error getting food items
      return [];
    }
  }

  /// Get food items stream for real-time updates
  static Stream<List<FoodItem>> getFoodItemsStream({
    int limit = 20,
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

  /// Add a new food item
  static Future<bool> addFoodItem(FoodItem foodItem) async {
    try {
      await _userFoodsCollection.doc(foodItem.id).set(foodItem.toMap());
      return true;
    } catch (e) {
      // Error adding food item
      return false;
    }
  }

  /// Update a food item
  static Future<bool> updateFoodItem(FoodItem foodItem) async {
    try {
      await _userFoodsCollection.doc(foodItem.id).set(
        foodItem.toMap(), 
        SetOptions(merge: true)
      );
      return true;
    } catch (e) {
      // Error updating food item
      return false;
    }
  }

  /// Get payment transactions for a date range
  static Future<List<PaymentTransaction>> getPaymentTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _paymentTransactionsCollection
          .orderBy('paymentDate', descending: true);

      if (startDate != null) {
        query = query.where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => PaymentTransaction.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Error getting payment transactions
      return [];
    }
  }

  /// Get summary statistics
  static Future<PaymentSummary> getPaymentSummary() async {
    try {
      final allFoods = await getFoodItems(limit: 1000); // Get all foods
      
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
      // Error getting payment summary
      return PaymentSummary.empty();
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

