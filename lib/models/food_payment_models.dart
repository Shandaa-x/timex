import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an individual food item with payment tracking
class FoodItem {
  final String id; // Unique identifier for the food item
  final String name;
  final double price;
  final String? imageBase64; // Base64 encoded image
  final DateTime selectedDate;
  final double paidAmount;
  final double remainingBalance;
  final FoodPaymentStatus status;
  final List<FoodPaymentRecord> paymentHistory;

  FoodItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageBase64,
    required this.selectedDate,
    this.paidAmount = 0.0,
    double? remainingBalance,
    FoodPaymentStatus? status,
    this.paymentHistory = const [],
  }) : 
    remainingBalance = remainingBalance ?? (price - paidAmount),
    status = status ?? _determineStatus(paidAmount, price);

  static FoodPaymentStatus _determineStatus(double paidAmount, double price) {
    if (paidAmount >= price) {
      return FoodPaymentStatus.fullyPaid;
    } else if (paidAmount > 0) {
      return FoodPaymentStatus.partiallyPaid;
    } else {
      return FoodPaymentStatus.unpaid;
    }
  }

  /// Check if the food is fully paid
  bool get isFullyPaid => status == FoodPaymentStatus.fullyPaid;

  /// Check if the food has any payment
  bool get hasPayment => paidAmount > 0;

  /// Get payment progress as percentage (0.0 to 1.0)
  double get paymentProgress => price > 0 ? (paidAmount / price).clamp(0.0, 1.0) : 0.0;

  /// Create a copy with updated payment
  FoodItem copyWith({
    String? id,
    String? name,
    double? price,
    String? imageBase64,
    DateTime? selectedDate,
    double? paidAmount,
    double? remainingBalance,
    FoodPaymentStatus? status,
    List<FoodPaymentRecord>? paymentHistory,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageBase64: imageBase64 ?? this.imageBase64,
      selectedDate: selectedDate ?? this.selectedDate,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      status: status ?? this.status,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageBase64': imageBase64,
      'selectedDate': Timestamp.fromDate(selectedDate),
      'paidAmount': paidAmount,
      'remainingBalance': remainingBalance,
      'status': status.name,
      'paymentHistory': paymentHistory.map((p) => p.toMap()).toList(),
    };
  }

  /// Create from Firestore Map
  factory FoodItem.fromMap(Map<String, dynamic> map) {
    final paymentHistoryList = (map['paymentHistory'] as List<dynamic>? ?? [])
        .map((p) => FoodPaymentRecord.fromMap(p as Map<String, dynamic>))
        .toList();

    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      imageBase64: map['imageBase64'] as String?,
      selectedDate: (map['selectedDate'] as Timestamp).toDate(),
      paidAmount: (map['paidAmount'] as num? ?? 0).toDouble(),
      remainingBalance: (map['remainingBalance'] as num? ?? 0).toDouble(),
      status: FoodPaymentStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => FoodPaymentStatus.unpaid,
      ),
      paymentHistory: paymentHistoryList,
    );
  }
}

/// Represents the payment status of a food item
enum FoodPaymentStatus {
  unpaid,
  partiallyPaid,
  fullyPaid,
}

/// Represents a single payment record for a food item
class FoodPaymentRecord {
  final String id;
  final double amount;
  final DateTime paymentDate;
  final String method; // e.g., 'qpay', 'cash', etc.
  final String? invoiceId; // Reference to the invoice this payment belongs to
  final String? transactionId;

  FoodPaymentRecord({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.method,
    this.invoiceId,
    this.transactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'method': method,
      'invoiceId': invoiceId,
      'transactionId': transactionId,
    };
  }

  factory FoodPaymentRecord.fromMap(Map<String, dynamic> map) {
    return FoodPaymentRecord(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: (map['paymentDate'] as Timestamp).toDate(),
      method: map['method'] as String,
      invoiceId: map['invoiceId'] as String?,
      transactionId: map['transactionId'] as String?,
    );
  }
}

/// Represents a payment transaction that can cover multiple food items
class PaymentTransaction {
  final String id;
  final double totalAmount;
  final DateTime paymentDate;
  final String method;
  final String? invoiceId;
  final List<String> foodIds; // List of food IDs covered by this payment
  final Map<String, double> foodPaymentDistribution; // foodId -> amount paid

  PaymentTransaction({
    required this.id,
    required this.totalAmount,
    required this.paymentDate,
    required this.method,
    this.invoiceId,
    required this.foodIds,
    required this.foodPaymentDistribution,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'method': method,
      'invoiceId': invoiceId,
      'foodIds': foodIds,
      'foodPaymentDistribution': foodPaymentDistribution,
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      paymentDate: (map['paymentDate'] as Timestamp).toDate(),
      method: map['method'] as String,
      invoiceId: map['invoiceId'] as String?,
      foodIds: List<String>.from(map['foodIds'] as List),
      foodPaymentDistribution: Map<String, double>.from(
        (map['foodPaymentDistribution'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
      ),
    );
  }
}

/// Extension to help with payment status display
extension FoodPaymentStatusExtension on FoodPaymentStatus {
  String get displayName {
    switch (this) {
      case FoodPaymentStatus.unpaid:
        return 'Unpaid';
      case FoodPaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case FoodPaymentStatus.fullyPaid:
        return 'Fully Paid';
    }
  }

  String get statusBadge {
    switch (this) {
      case FoodPaymentStatus.unpaid:
        return 'UNPAID';
      case FoodPaymentStatus.partiallyPaid:
        return 'PARTIAL';
      case FoodPaymentStatus.fullyPaid:
        return 'PAID';
    }
  }
}

/// Payment summary for a collection of food items
class PaymentSummary {
  final double totalFoodValue;
  final double totalPaidAmount;
  final double totalRemainingBalance;
  final int unpaidCount;
  final int partiallyPaidCount;
  final int fullyPaidCount;
  final int totalFoodCount;

  PaymentSummary({
    required this.totalFoodValue,
    required this.totalPaidAmount,
    required this.totalRemainingBalance,
    required this.unpaidCount,
    required this.partiallyPaidCount,
    required this.fullyPaidCount,
    required this.totalFoodCount,
  });

  double get paymentProgress {
    if (totalFoodValue <= 0) return 0.0;
    return (totalPaidAmount / totalFoodValue).clamp(0.0, 1.0);
  }

  factory PaymentSummary.empty() {
    return PaymentSummary(
      totalFoodValue: 0.0,
      totalPaidAmount: 0.0,
      totalRemainingBalance: 0.0,
      unpaidCount: 0,
      partiallyPaidCount: 0,
      fullyPaidCount: 0,
      totalFoodCount: 0,
    );
  }

  factory PaymentSummary.fromMap(Map<String, dynamic> map) {
    return PaymentSummary(
      totalFoodValue: (map['totalFoodValue'] as num?)?.toDouble() ?? 0.0,
      totalPaidAmount: (map['totalPaidAmount'] as num?)?.toDouble() ?? 0.0,
      totalRemainingBalance: (map['totalRemainingBalance'] as num?)?.toDouble() ?? 0.0,
      unpaidCount: map['unpaidCount'] as int? ?? 0,
      partiallyPaidCount: map['partiallyPaidCount'] as int? ?? 0,
      fullyPaidCount: map['fullyPaidCount'] as int? ?? 0,
      totalFoodCount: map['totalFoodCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalFoodValue': totalFoodValue,
      'totalPaidAmount': totalPaidAmount,
      'totalRemainingBalance': totalRemainingBalance,
      'unpaidCount': unpaidCount,
      'partiallyPaidCount': partiallyPaidCount,
      'fullyPaidCount': fullyPaidCount,
      'totalFoodCount': totalFoodCount,
      'paymentProgress': paymentProgress,
    };
  }
}