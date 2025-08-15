import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_payment_models.dart';
import '../models/qpay_models.dart';
import '../services/qpay_service.dart';
import '../screens/food_report/services/food_data_service.dart';

/// Integrated service that connects individual food payment tracking with existing Firebase and QPay systems
class IntegratedFoodPaymentService {
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Convert existing Firebase food data to individual FoodItem objects
  static Future<List<FoodItem>> convertFirebaseFoodsToFoodItems(DateTime selectedMonth) async {
    try {
      // Load existing food data from Firebase
      final monthlyFoodData = await FoodDataService.loadFoodDataForMonth(selectedMonth);
      final List<FoodItem> foodItems = [];

      for (final entry in monthlyFoodData.entries) {
        final dateKey = entry.key;
        final dailyFoods = entry.value;
        final date = DateTime.parse('$dateKey 12:00:00'); // Parse date from key

        for (int i = 0; i < dailyFoods.length; i++) {
          final foodData = dailyFoods[i];
          
          // Generate unique ID for each food item
          final foodId = 'food_${dateKey}_${i}_${foodData.hashCode.abs()}';
          
          // Extract food details
          final name = FoodDataService.getFoodName(foodData);
          final price = FoodDataService.getFoodPrice(foodData).toDouble();
          
          // Create FoodItem with proper payment tracking
          final foodItem = FoodItem(
            id: foodId,
            name: name,
            price: price,
            selectedDate: date,
            imageBase64: foodData['image'] as String?, // If image exists in Firebase
            paidAmount: 0.0, // Will be calculated from payment history
            paymentHistory: [], // Will be populated separately
          );
          
          foodItems.add(foodItem);
        }
      }

      // Load payment history and update food items
      await _updateFoodItemsWithPaymentHistory(foodItems, selectedMonth);
      
      return foodItems;
    } catch (e) {
      // Error converting Firebase foods
      return [];
    }
  }

  /// Update food items with their payment history from Firebase
  static Future<void> _updateFoodItemsWithPaymentHistory(
    List<FoodItem> foodItems,
    DateTime selectedMonth,
  ) async {
    try {
      // Get payment history from existing payment service
      final monthKey = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
      
      // Check both old and new payment collections
      final futures = await Future.wait([
        // Old payment structure
        _firestore.collection('payments').doc('$_currentUserId-$monthKey').get(),
        // New individual payments structure
        _firestore.collection('users').doc(_currentUserId).collection('payments')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(selectedMonth.year, selectedMonth.month, 1)))
            .where('createdAt', isLessThan: Timestamp.fromDate(
              DateTime(selectedMonth.year, selectedMonth.month + 1, 1)))
            .get(),
      ]);

      final oldPaymentDoc = futures[0] as DocumentSnapshot;
      final newPaymentQuery = futures[1] as QuerySnapshot;

      // Process old payment structure
      if (oldPaymentDoc.exists) {
        final data = oldPaymentDoc.data() as Map<String, dynamic>;
        final payments = List<Map<String, dynamic>>.from(data['payments'] ?? []);
        
        for (final payment in payments) {
          if (payment['foodDetails'] != null) {
            final foodDetails = List<Map<String, dynamic>>.from(payment['foodDetails']);
            _applyPaymentToFoodItems(foodItems, payment, foodDetails);
          }
        }
      }

      // Process new individual payment structure
      for (final paymentDoc in newPaymentQuery.docs) {
        final paymentData = paymentDoc.data() as Map<String, dynamic>;
        if (paymentData['foodDetails'] != null) {
          final foodDetails = List<Map<String, dynamic>>.from(paymentData['foodDetails'] as List);
          _applyPaymentToFoodItems(foodItems, paymentData, foodDetails);
        }
      }

    } catch (e) {
      // Error updating payment history
    }
  }

  /// Apply payment to specific food items
  static void _applyPaymentToFoodItems(
    List<FoodItem> foodItems,
    Map<String, dynamic> payment,
    List<Map<String, dynamic>> foodDetails,
  ) {
    final paymentDate = payment['createdAt'] is Timestamp 
        ? (payment['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    
    final method = payment['method'] as String? ?? 'qpay';
    final invoiceId = payment['invoiceId'] as String? ?? '';
    final transactionId = payment['transactionId'] as String? ?? payment['id'] as String? ?? '';

    for (final foodDetail in foodDetails) {
      final foodId = foodDetail['id'] as String?;
      final paidAmount = (foodDetail['paidAmount'] as num?)?.toDouble() ?? 0.0;
      
      if (foodId != null && paidAmount > 0) {
        // Find matching food item
        final foodItem = foodItems.firstWhere(
          (item) => item.id == foodId,
          orElse: () => foodItems.firstWhere(
            (item) => item.name == foodDetail['name'] && 
                     item.price == (foodDetail['price'] as num?)?.toDouble(),
            orElse: () => foodItems.first, // Fallback
          ),
        );

        // Create payment record
        final paymentRecord = FoodPaymentRecord(
          id: '${transactionId}_${foodItem.id}',
          amount: paidAmount,
          paymentDate: paymentDate,
          method: method,
          invoiceId: invoiceId,
          transactionId: transactionId,
        );

        // Update food item (need to create new instance since FoodItem is immutable)
        final index = foodItems.indexOf(foodItem);
        if (index >= 0) {
          final updatedHistory = [...foodItem.paymentHistory, paymentRecord];
          final totalPaid = updatedHistory.fold<double>(0, (sum, record) => sum + record.amount);
          
          foodItems[index] = foodItem.copyWith(
            paidAmount: totalPaid,
            paymentHistory: updatedHistory,
          );
        }
      }
    }
  }

  /// Create QPay invoice for selected food items
  static Future<QPayInvoiceResult> createFoodPaymentInvoice(
    List<FoodItem> selectedFoods,
    Map<String, dynamic>? user,
  ) async {
    try {
      // Convert food items to QPay order format
      final orderItems = selectedFoods.map((food) => {
        'productName': food.name,
        'numericPrice': food.remainingBalance, // Only charge remaining balance
        'quantity': 1,
        'name': food.name,
        'price': food.remainingBalance,
        'amount': food.remainingBalance,
      }).toList();

      final order = {
        'orderNumber': 'FOOD_${DateTime.now().millisecondsSinceEpoch}',
        'items': orderItems,
        'totalAmount': selectedFoods.fold<double>(0, (sum, food) => sum + food.remainingBalance),
        'foodIds': selectedFoods.map((f) => f.id).toList(),
        'foodCount': selectedFoods.length,
        'foodDetails': selectedFoods.map((food) => {
          'id': food.id,
          'name': food.name,
          'price': food.price,
          'remainingBalance': food.remainingBalance,
          'image': food.imageBase64 ?? '',
          'date': food.selectedDate.toIso8601String(),
        }).toList(),
      };

      // Create QPay invoice
      final result = await QPayService.createInvoice(order, user);
      
      return result;
    } catch (e) {
      return QPayInvoiceResult(
        success: false,
        error: 'Error creating invoice: $e',
      );
    }
  }

  /// Process payment completion and update individual food items
  static Future<bool> processPaymentCompletion(
    String invoiceId,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      // Get original order data from the payment
      final foodIds = List<String>.from(paymentData['foodIds'] ?? []);
      final foodDetails = List<Map<String, dynamic>>.from(paymentData['foodDetails'] ?? []);
      final totalAmount = (paymentData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final method = paymentData['method'] as String? ?? 'qpay';

      if (foodIds.isEmpty || foodDetails.isEmpty) {
        return false;
      }

      // Create payment record with proper food distribution
      final paymentRecord = {
        'id': invoiceId,
        'amount': totalAmount,
        'method': method,
        'invoiceId': invoiceId,
        'transactionId': paymentData['transactionId'] ?? invoiceId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'foodCount': foodIds.length,
        'foodDetails': foodDetails,
        'foodIds': foodIds,
        'paymentDistribution': _calculatePaymentDistribution(foodDetails, totalAmount),
        'totalFoodAmount': foodDetails.fold<double>(0, (sum, food) => sum + ((food['price'] as num?)?.toDouble() ?? 0)),
        'originalFoodAmount': foodDetails.fold<double>(0, (sum, food) => sum + ((food['price'] as num?)?.toDouble() ?? 0)),
      };

      // Save to both old and new payment structures for compatibility
      final batch = _firestore.batch();

      // Save to new individual payment collection
      final newPaymentRef = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('payments')
          .doc(invoiceId);
      batch.set(newPaymentRef, paymentRecord);

      // Update old payment collection for compatibility
      final monthKey = DateTime.now().month.toString().padLeft(2, '0');
      final yearMonth = '${DateTime.now().year}-$monthKey';
      final oldPaymentRef = _firestore
          .collection('payments')
          .doc('$_currentUserId-$yearMonth');
      
      batch.set(oldPaymentRef, {
        'userId': _currentUserId,
        'year': DateTime.now().year,
        'month': DateTime.now().month,
        'payments': FieldValue.arrayUnion([paymentRecord]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update individual food items in the foods collection
      for (final foodDetail in foodDetails) {
        final foodId = foodDetail['id'] as String?;
        final paidAmount = (foodDetail['remainingBalance'] as num?)?.toDouble() ?? 0.0;
        
        if (foodId != null) {
          final foodItemRef = _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('foods')
              .doc(foodId);
          
          batch.set(foodItemRef, {
            'id': foodId,
            'name': foodDetail['name'],
            'price': foodDetail['price'],
            'paidAmount': FieldValue.increment(paidAmount),
            'lastPaymentDate': FieldValue.serverTimestamp(),
            'lastPaymentAmount': paidAmount,
            'lastInvoiceId': invoiceId,
            'paymentHistory': FieldValue.arrayUnion([{
              'id': '${invoiceId}_${foodId}',
              'amount': paidAmount,
              'paymentDate': FieldValue.serverTimestamp(),
              'method': method,
              'invoiceId': invoiceId,
              'transactionId': paymentData['transactionId'] ?? invoiceId,
            }]),
          }, SetOptions(merge: true));
        }
      }

      // Update user's totalFoodAmount and payment status
      final userRef = _firestore.collection('users').doc(_currentUserId);
      batch.update(userRef, {
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'lastPaymentAmount': totalAmount,
        'totalPaymentsMade': FieldValue.increment(totalAmount),
        'qpayStatus': 'completed',
      });

      // Commit all changes atomically
      await batch.commit();
      
      return true;
    } catch (e) {
      // Error processing payment completion
      return false;
    }
  }

  /// Calculate payment distribution across food items
  static Map<String, double> _calculatePaymentDistribution(
    List<Map<String, dynamic>> foodDetails,
    double totalAmount,
  ) {
    final distribution = <String, double>{};
    double remainingAmount = totalAmount;

    // Sort by selection order (if available) or by remaining balance
    foodDetails.sort((a, b) {
      final aBalance = (a['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      final bBalance = (b['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      return aBalance.compareTo(bBalance); // Pay smaller amounts first
    });

    for (final food in foodDetails) {
      final foodId = food['id'] as String?;
      final remainingBalance = (food['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      
      if (foodId != null && remainingAmount > 0 && remainingBalance > 0) {
        final amountToPay = remainingAmount >= remainingBalance ? remainingBalance : remainingAmount;
        distribution[foodId] = amountToPay;
        remainingAmount -= amountToPay;
      }
    }

    return distribution;
  }

  /// Get real-time stream of food items with payment updates
  static Stream<List<FoodItem>> getFoodItemsStream(DateTime selectedMonth) {
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('foods')
        .where('selectedDate', isGreaterThanOrEqualTo: 
          Timestamp.fromDate(DateTime(selectedMonth.year, selectedMonth.month, 1)))
        .where('selectedDate', isLessThan: 
          Timestamp.fromDate(DateTime(selectedMonth.year, selectedMonth.month + 1, 1)))
        .orderBy('selectedDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FoodItem.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
        });
  }

  /// Sync existing Firebase food data to the new individual food system
  static Future<void> syncExistingFoodData(DateTime selectedMonth) async {
    try {
      final foodItems = await convertFirebaseFoodsToFoodItems(selectedMonth);
      
      // Save each food item to the new structure
      final batch = _firestore.batch();
      
      for (final foodItem in foodItems) {
        final ref = _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('foods')
            .doc(foodItem.id);
        
        batch.set(ref, foodItem.toMap(), SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      // Error syncing food data
    }
  }

  /// Get payment summary for the current user
  static Future<PaymentSummary> getPaymentSummary(DateTime selectedMonth) async {
    try {
      final foodItems = await convertFirebaseFoodsToFoodItems(selectedMonth);
      
      double totalFoodValue = 0;
      double totalPaidAmount = 0;
      double totalRemainingBalance = 0;
      int unpaidCount = 0;
      int partiallyPaidCount = 0;
      int fullyPaidCount = 0;

      for (final food in foodItems) {
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
        totalFoodCount: foodItems.length,
      );
    } catch (e) {
      return PaymentSummary.empty();
    }
  }
}