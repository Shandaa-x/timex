import '../models/food_payment_models.dart';
import '../services/individual_food_payment_service.dart';

/// Service for processing payments across multiple food items
class FoodPaymentProcessor {
  
  /// Process a payment for selected food items
  /// Distributes the payment amount to foods in order of selection
  /// Returns detailed information about how the payment was applied
  static Future<DetailedPaymentResult> processPaymentForFoods({
    required List<String> selectedFoodIds,
    required double paymentAmount,
    required String paymentMethod,
    String? invoiceId,
    String? transactionId,
  }) async {
    
    // Validate input
    if (selectedFoodIds.isEmpty) {
      return DetailedPaymentResult(
        success: false,
        message: 'No food items selected',
        totalAmount: paymentAmount,
        distributedAmount: 0,
        remainingAmount: paymentAmount,
        foodPaymentDetails: [],
        paymentTransaction: null,
      );
    }

    if (paymentAmount <= 0) {
      return DetailedPaymentResult(
        success: false,
        message: 'Payment amount must be greater than 0',
        totalAmount: paymentAmount,
        distributedAmount: 0,
        remainingAmount: paymentAmount,
        foodPaymentDetails: [],
        paymentTransaction: null,
      );
    }

    try {
      // Process the payment using the service
      final result = await IndividualFoodPaymentService.processPayment(
        foodIds: selectedFoodIds,
        paymentAmount: paymentAmount,
        method: paymentMethod,
        invoiceId: invoiceId,
        transactionId: transactionId,
      );

      if (!result.success) {
        return DetailedPaymentResult(
          success: false,
          message: result.message,
          totalAmount: paymentAmount,
          distributedAmount: 0,
          remainingAmount: paymentAmount,
          foodPaymentDetails: [],
          paymentTransaction: null,
        );
      }

      // Calculate distribution details
      double distributedAmount = 0;
      final foodPaymentDetails = <FoodPaymentDetail>[];

      if (result.paymentTransaction != null) {
        for (final updatedFood in result.updatedFoodItems) {
          final amountPaid = result.paymentTransaction!.foodPaymentDistribution[updatedFood.id] ?? 0.0;
          distributedAmount += amountPaid;

          foodPaymentDetails.add(FoodPaymentDetail(
            foodId: updatedFood.id,
            foodName: updatedFood.name,
            foodPrice: updatedFood.price,
            amountPaidThisTransaction: amountPaid,
            totalAmountPaid: updatedFood.paidAmount,
            remainingBalance: updatedFood.remainingBalance,
            statusBefore: _getPreviousStatus(updatedFood, amountPaid),
            statusAfter: updatedFood.status,
            isFullyPaidNow: updatedFood.isFullyPaid,
          ));
        }
      }

      final remainingAmount = paymentAmount - distributedAmount;

      return DetailedPaymentResult(
        success: true,
        message: 'Payment processed successfully',
        totalAmount: paymentAmount,
        distributedAmount: distributedAmount,
        remainingAmount: remainingAmount,
        foodPaymentDetails: foodPaymentDetails,
        paymentTransaction: result.paymentTransaction,
      );

    } catch (e) {
      return DetailedPaymentResult(
        success: false,
        message: 'Error processing payment: $e',
        totalAmount: paymentAmount,
        distributedAmount: 0,
        remainingAmount: paymentAmount,
        foodPaymentDetails: [],
        paymentTransaction: null,
      );
    }
  }

  /// Calculate payment distribution without actually processing it
  /// Useful for showing users how their payment will be distributed
  static Future<PaymentDistributionPreview> previewPaymentDistribution({
    required List<String> selectedFoodIds,
    required double paymentAmount,
  }) async {
    try {
      // Get food items
      final foodItems = await IndividualFoodPaymentService.getFoodItemsByIds(selectedFoodIds);
      
      if (foodItems.isEmpty) {
        return PaymentDistributionPreview(
          success: false,
          message: 'No food items found',
          totalPaymentAmount: paymentAmount,
          totalDistributableAmount: 0,
          excessAmount: paymentAmount,
          distributionItems: [],
        );
      }

      // Sort by selection date (order of selection)
      foodItems.sort((a, b) => a.selectedDate.compareTo(b.selectedDate));

      // Calculate distribution
      double remainingAmount = paymentAmount;
      double totalDistributableAmount = 0;
      final distributionItems = <DistributionItem>[];

      for (final foodItem in foodItems) {
        if (remainingAmount <= 0) {
          // No more payment to distribute
          distributionItems.add(DistributionItem(
            foodId: foodItem.id,
            foodName: foodItem.name,
            foodPrice: foodItem.price,
            currentPaidAmount: foodItem.paidAmount,
            remainingBalance: foodItem.remainingBalance,
            amountToBeApplied: 0,
            newPaidAmount: foodItem.paidAmount,
            newRemainingBalance: foodItem.remainingBalance,
            willBeFullyPaid: foodItem.isFullyPaid,
            currentStatus: foodItem.status,
            newStatus: foodItem.status,
          ));
          continue;
        }

        final amountNeeded = foodItem.remainingBalance;
        final amountToApply = remainingAmount >= amountNeeded ? amountNeeded : remainingAmount;
        
        final newPaidAmount = foodItem.paidAmount + amountToApply;
        final newRemainingBalance = (foodItem.price - newPaidAmount).clamp(0.0, foodItem.price);
        final willBeFullyPaid = newPaidAmount >= foodItem.price;
        final newStatus = willBeFullyPaid 
          ? FoodPaymentStatus.fullyPaid
          : (newPaidAmount > 0 ? FoodPaymentStatus.partiallyPaid : FoodPaymentStatus.unpaid);

        distributionItems.add(DistributionItem(
          foodId: foodItem.id,
          foodName: foodItem.name,
          foodPrice: foodItem.price,
          currentPaidAmount: foodItem.paidAmount,
          remainingBalance: foodItem.remainingBalance,
          amountToBeApplied: amountToApply,
          newPaidAmount: newPaidAmount,
          newRemainingBalance: newRemainingBalance,
          willBeFullyPaid: willBeFullyPaid,
          currentStatus: foodItem.status,
          newStatus: newStatus,
        ));

        remainingAmount -= amountToApply;
        totalDistributableAmount += amountToApply;
      }

      return PaymentDistributionPreview(
        success: true,
        message: 'Payment distribution calculated',
        totalPaymentAmount: paymentAmount,
        totalDistributableAmount: totalDistributableAmount,
        excessAmount: remainingAmount,
        distributionItems: distributionItems,
      );

    } catch (e) {
      return PaymentDistributionPreview(
        success: false,
        message: 'Error calculating distribution: $e',
        totalPaymentAmount: paymentAmount,
        totalDistributableAmount: 0,
        excessAmount: paymentAmount,
        distributionItems: [],
      );
    }
  }

  /// Get statistics about food payment status
  static Future<FoodPaymentStats> getFoodPaymentStats({
    List<String>? specificFoodIds,
  }) async {
    try {
      final summary = await IndividualFoodPaymentService.getPaymentSummary();
      
      return FoodPaymentStats(
        totalFoods: summary.totalFoodCount,
        unpaidFoods: summary.unpaidCount,
        partiallyPaidFoods: summary.partiallyPaidCount,
        fullyPaidFoods: summary.fullyPaidCount,
        totalFoodValue: summary.totalFoodValue,
        totalAmountPaid: summary.totalPaidAmount,
        totalAmountRemaining: summary.totalRemainingBalance,
        paymentCompletionRate: summary.paymentProgress,
      );
    } catch (e) {
      return FoodPaymentStats.empty();
    }
  }

  /// Helper method to determine the previous status of a food item
  static FoodPaymentStatus _getPreviousStatus(FoodItem currentFood, double amountPaidThisTransaction) {
    final previousPaidAmount = currentFood.paidAmount - amountPaidThisTransaction;
    
    if (previousPaidAmount >= currentFood.price) {
      return FoodPaymentStatus.fullyPaid;
    } else if (previousPaidAmount > 0) {
      return FoodPaymentStatus.partiallyPaid;
    } else {
      return FoodPaymentStatus.unpaid;
    }
  }
}

/// Detailed result of payment processing
class DetailedPaymentResult {
  final bool success;
  final String message;
  final double totalAmount;
  final double distributedAmount;
  final double remainingAmount;
  final List<FoodPaymentDetail> foodPaymentDetails;
  final PaymentTransaction? paymentTransaction;

  DetailedPaymentResult({
    required this.success,
    required this.message,
    required this.totalAmount,
    required this.distributedAmount,
    required this.remainingAmount,
    required this.foodPaymentDetails,
    this.paymentTransaction,
  });

  bool get hasExcessAmount => remainingAmount > 0;
  int get foodsFullyPaidInThisTransaction => 
    foodPaymentDetails.where((f) => f.isFullyPaidNow && f.amountPaidThisTransaction > 0).length;
  int get foodsPartiallyPaidInThisTransaction => 
    foodPaymentDetails.where((f) => !f.isFullyPaidNow && f.amountPaidThisTransaction > 0).length;
}

/// Details of payment applied to a specific food item
class FoodPaymentDetail {
  final String foodId;
  final String foodName;
  final double foodPrice;
  final double amountPaidThisTransaction;
  final double totalAmountPaid;
  final double remainingBalance;
  final FoodPaymentStatus statusBefore;
  final FoodPaymentStatus statusAfter;
  final bool isFullyPaidNow;

  FoodPaymentDetail({
    required this.foodId,
    required this.foodName,
    required this.foodPrice,
    required this.amountPaidThisTransaction,
    required this.totalAmountPaid,
    required this.remainingBalance,
    required this.statusBefore,
    required this.statusAfter,
    required this.isFullyPaidNow,
  });

  bool get statusChanged => statusBefore != statusAfter;
  bool get receivedPayment => amountPaidThisTransaction > 0;
}

/// Preview of how payment will be distributed
class PaymentDistributionPreview {
  final bool success;
  final String message;
  final double totalPaymentAmount;
  final double totalDistributableAmount;
  final double excessAmount;
  final List<DistributionItem> distributionItems;

  PaymentDistributionPreview({
    required this.success,
    required this.message,
    required this.totalPaymentAmount,
    required this.totalDistributableAmount,
    required this.excessAmount,
    required this.distributionItems,
  });

  bool get hasExcess => excessAmount > 0;
  int get foodsToBeFullyPaid => distributionItems.where((item) => item.willBeFullyPaid).length;
  int get foodsToBePartiallyPaid => distributionItems.where((item) => 
    !item.willBeFullyPaid && item.amountToBeApplied > 0).length;
  int get foodsReceivingPayment => distributionItems.where((item) => 
    item.amountToBeApplied > 0).length;
}

/// Item in payment distribution preview
class DistributionItem {
  final String foodId;
  final String foodName;
  final double foodPrice;
  final double currentPaidAmount;
  final double remainingBalance;
  final double amountToBeApplied;
  final double newPaidAmount;
  final double newRemainingBalance;
  final bool willBeFullyPaid;
  final FoodPaymentStatus currentStatus;
  final FoodPaymentStatus newStatus;

  DistributionItem({
    required this.foodId,
    required this.foodName,
    required this.foodPrice,
    required this.currentPaidAmount,
    required this.remainingBalance,
    required this.amountToBeApplied,
    required this.newPaidAmount,
    required this.newRemainingBalance,
    required this.willBeFullyPaid,
    required this.currentStatus,
    required this.newStatus,
  });

  bool get willReceivePayment => amountToBeApplied > 0;
  bool get statusWillChange => currentStatus != newStatus;
}

/// Statistics about food payments
class FoodPaymentStats {
  final int totalFoods;
  final int unpaidFoods;
  final int partiallyPaidFoods;
  final int fullyPaidFoods;
  final double totalFoodValue;
  final double totalAmountPaid;
  final double totalAmountRemaining;
  final double paymentCompletionRate;

  FoodPaymentStats({
    required this.totalFoods,
    required this.unpaidFoods,
    required this.partiallyPaidFoods,
    required this.fullyPaidFoods,
    required this.totalFoodValue,
    required this.totalAmountPaid,
    required this.totalAmountRemaining,
    required this.paymentCompletionRate,
  });

  factory FoodPaymentStats.empty() {
    return FoodPaymentStats(
      totalFoods: 0,
      unpaidFoods: 0,
      partiallyPaidFoods: 0,
      fullyPaidFoods: 0,
      totalFoodValue: 0,
      totalAmountPaid: 0,
      totalAmountRemaining: 0,
      paymentCompletionRate: 0,
    );
  }
}