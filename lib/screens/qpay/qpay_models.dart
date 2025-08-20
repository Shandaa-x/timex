/// QPay Models - Data classes for QPay integration
library qpay_models;

/// Result of creating a QPay invoice
class QPayInvoiceResult {
  final bool success;
  final String? invoiceId;
  final String? qrText;
  final String? qrDataURL;
  final String? qrImageURL;
  final List<String> bankUrls;
  final double amount;
  final List<Map<String, dynamic>> products;
  final String? orderId;
  final String? expiresAt;
  final String? accessToken;
  final int sessionDuration;
  final Map<String, dynamic> metadata;
  final String? error;

  const QPayInvoiceResult({
    required this.success,
    this.invoiceId,
    this.qrText,
    this.qrDataURL,
    this.qrImageURL,
    this.bankUrls = const [],
    this.amount = 0.0,
    this.products = const [],
    this.orderId,
    this.expiresAt,
    this.accessToken,
    this.sessionDuration = 0,
    this.metadata = const {},
    this.error,
  });

  factory QPayInvoiceResult.error(String error) {
    return QPayInvoiceResult(success: false, error: error);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'invoiceId': invoiceId,
      'qrText': qrText,
      'qrDataURL': qrDataURL,
      'qrImageURL': qrImageURL,
      'bankUrls': bankUrls,
      'amount': amount,
      'products': products,
      'orderId': orderId,
      'expiresAt': expiresAt,
      'accessToken': accessToken,
      'sessionDuration': sessionDuration,
      'metadata': metadata,
      'error': error,
    };
  }

  factory QPayInvoiceResult.fromJson(Map<String, dynamic> json) {
    return QPayInvoiceResult(
      success: json['success'] ?? false,
      invoiceId: json['invoiceId'],
      qrText: json['qrText'],
      qrDataURL: json['qrDataURL'],
      qrImageURL: json['qrImageURL'],
      bankUrls: List<String>.from(json['bankUrls'] ?? []),
      amount: json['amount']?.toDouble() ?? 0.0,
      products: List<Map<String, dynamic>>.from(json['products'] ?? []),
      orderId: json['orderId'],
      expiresAt: json['expiresAt'],
      accessToken: json['accessToken'],
      sessionDuration: json['sessionDuration'] ?? 0,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      error: json['error'],
    );
  }
}

/// Payment status result from QPay
class QPayPaymentStatus {
  final bool success;
  final bool isPaid;
  final bool isExpired;
  final Map<String, dynamic>? paymentData;
  final double totalPaid;
  final int paymentCount;
  final String sessionStatus;
  final String? error;

  const QPayPaymentStatus({
    required this.success,
    this.isPaid = false,
    this.isExpired = false,
    this.paymentData,
    this.totalPaid = 0.0,
    this.paymentCount = 0,
    this.sessionStatus = 'unknown',
    this.error,
  });

  factory QPayPaymentStatus.error(String error) {
    return QPayPaymentStatus(success: false, error: error);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'isPaid': isPaid,
      'isExpired': isExpired,
      'paymentData': paymentData,
      'totalPaid': totalPaid,
      'paymentCount': paymentCount,
      'sessionStatus': sessionStatus,
      'error': error,
    };
  }

  factory QPayPaymentStatus.fromJson(Map<String, dynamic> json) {
    return QPayPaymentStatus(
      success: json['success'] ?? false,
      isPaid: json['isPaid'] ?? false,
      isExpired: json['isExpired'] ?? false,
      paymentData: json['paymentData'] != null
          ? Map<String, dynamic>.from(json['paymentData'])
          : null,
      totalPaid: json['totalPaid']?.toDouble() ?? 0.0,
      paymentCount: json['paymentCount'] ?? 0,
      sessionStatus: json['sessionStatus'] ?? 'unknown',
      error: json['error'],
    );
  }
}

/// Session status result from QPay
class QPaySessionStatus {
  final bool success;
  final bool isActive;
  final bool isExpired;
  final int timeRemaining;
  final String? expiresAt;
  final String? createdAt;
  final String? error;

  const QPaySessionStatus({
    required this.success,
    this.isActive = false,
    this.isExpired = false,
    this.timeRemaining = 0,
    this.expiresAt,
    this.createdAt,
    this.error,
  });

  factory QPaySessionStatus.error(String error) {
    return QPaySessionStatus(success: false, error: error);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'isActive': isActive,
      'isExpired': isExpired,
      'timeRemaining': timeRemaining,
      'expiresAt': expiresAt,
      'createdAt': createdAt,
      'error': error,
    };
  }

  factory QPaySessionStatus.fromJson(Map<String, dynamic> json) {
    return QPaySessionStatus(
      success: json['success'] ?? false,
      isActive: json['isActive'] ?? false,
      isExpired: json['isExpired'] ?? false,
      timeRemaining: json['timeRemaining'] ?? 0,
      expiresAt: json['expiresAt'],
      createdAt: json['createdAt'],
      error: json['error'],
    );
  }
}

/// Payment monitoring result
class QPayMonitoringResult {
  final bool success;
  final String invoiceId;
  final bool monitoringStarted;
  final String? error;

  const QPayMonitoringResult({
    required this.success,
    required this.invoiceId,
    this.monitoringStarted = false,
    this.error,
  });

  factory QPayMonitoringResult.error(String invoiceId, String error) {
    return QPayMonitoringResult(
      success: false,
      invoiceId: invoiceId,
      error: error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'invoiceId': invoiceId,
      'monitoringStarted': monitoringStarted,
      'error': error,
    };
  }

  factory QPayMonitoringResult.fromJson(Map<String, dynamic> json) {
    return QPayMonitoringResult(
      success: json['success'] ?? false,
      invoiceId: json['invoiceId'] ?? '',
      monitoringStarted: json['monitoringStarted'] ?? false,
      error: json['error'],
    );
  }
}

/// QPay product for invoice creation
class QPayProduct {
  final String name;
  final double amount;
  final int quantity;

  const QPayProduct({
    required this.name,
    required this.amount,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount, 'qty': quantity};
  }

  factory QPayProduct.fromJson(Map<String, dynamic> json) {
    return QPayProduct(
      name: json['name'] ?? '',
      amount: json['amount']?.toDouble() ?? 0.0,
      quantity: json['qty'] ?? 1,
    );
  }

  factory QPayProduct.fromCartItem(Map<String, dynamic> item) {
    final double price =
        _parseDouble(item['numericPrice']) ??
        _parseDouble(item['price']) ??
        _parseDouble(item['amount']) ??
        _parseDouble(item['cost']) ??
        _parseDouble(item['unitPrice']) ??
        0.0;

    final int quantity =
        _parseInt(item['quantity']) ??
        _parseInt(item['qty']) ??
        _parseInt(item['count']) ??
        1;

    final String name =
        item['productName']?.toString() ??
        item['name']?.toString() ??
        item['title']?.toString() ??
        'Unknown Item';

    return QPayProduct(name: name, amount: price, quantity: quantity);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// QPay order for processing
class QPayOrder {
  final String id;
  final String? customerCode;
  final List<QPayProduct> products;
  final double? totalAmount;
  final String? userId;
  final Map<String, dynamic> metadata;

  const QPayOrder({
    required this.id,
    this.customerCode,
    this.products = const [],
    this.totalAmount,
    this.userId,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerCode': customerCode,
      'products': products.map((p) => p.toJson()).toList(),
      'totalAmount': totalAmount,
      'userId': userId,
      'metadata': metadata,
    };
  }

  factory QPayOrder.fromJson(Map<String, dynamic> json) {
    return QPayOrder(
      id: json['id'] ?? '',
      customerCode: json['customerCode'],
      products:
          (json['products'] as List<dynamic>?)
              ?.map((p) => QPayProduct.fromJson(p))
              .toList() ??
          [],
      totalAmount: json['totalAmount']?.toDouble(),
      userId: json['userId'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  double get calculatedTotal {
    return products.fold(
      0.0,
      (sum, product) => sum + (product.amount * product.quantity),
    );
  }

  double get finalAmount => totalAmount ?? calculatedTotal;
}
