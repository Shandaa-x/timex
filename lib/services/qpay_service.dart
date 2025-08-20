import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/qpay/qpay_models.dart';
import '../utils/logger.dart';

/// QPay Service - Flutter wrapper for QPay functionality
/// Communicates with backend QPay server for payment processing
class QPayService {
  static const String _baseUrl = 'http://localhost:3000/api';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create invoice for an order with Firebase integration and session management
  ///
  /// [order] - Order object from Firebase
  /// [user] - Current user object
  /// [expirationMinutes] - Session expiration time (default: 5 minutes)
  ///
  /// Returns [QPayInvoiceResult] with invoice details
  static Future<QPayInvoiceResult> createInvoice(
    Map<String, dynamic> order,
    Map<String, dynamic>? user, {
    int expirationMinutes = 5,
  }) async {
    try {
      AppLogger.info(
        'QPayService.createInvoice called with order: ${order['orderNumber']}',
      );
      AppLogger.info('Session will expire in $expirationMinutes minutes');

      // Validate order data
      if (order['items'] == null || !(order['items'] is List)) {
        throw Exception('Invalid order data: missing items array');
      }

      final List items = order['items'];
      if (items.isEmpty) {
        throw Exception('Order must have at least one item');
      }

      // Convert order items to QPay server format
      final List<Map<String, dynamic>> products = items.map((item) {
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

        return {
          'name': name,
          'amount': price, // Server expects 'amount' not 'numericPrice'
          'qty': quantity, // Server expects 'qty' not 'quantity'
        };
      }).toList();

      // Validate products
      for (final product in products) {
        if ((product['amount'] as double) <= 0) {
          throw Exception('Invalid price for product: ${product['name']}');
        }
        if ((product['qty'] as int) <= 0) {
          throw Exception('Invalid quantity for product: ${product['name']}');
        }
      }

      AppLogger.info('Converted products for QPay server: $products');

      // Calculate total amount
      final double totalAmount =
          order['totalAmount']?.toDouble() ??
          products.fold<double>(
            0.0,
            (sum, p) => sum + ((p['amount'] as double) * (p['qty'] as int)),
          );

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'products': products,
        'customerCode': user?['uid'] ?? 'terminal',
        'orderId': order['orderNumber'] ?? _generateOrderId(),
        'totalAmount': totalAmount,
        'userId': user?['uid'],
        'cartData': order,
        'sessionDuration': expirationMinutes * 60,
        'metadata': {
          'orderNumber': order['orderNumber'],
          'userId': user?['uid'],
          'createdAt': DateTime.now().toIso8601String(),
          'expiresAt': DateTime.now()
              .add(Duration(minutes: expirationMinutes))
              .toIso8601String(),
        },
      };

      // Make HTTP request
      final response = await http.post(
        Uri.parse('$_baseUrl/create-invoice'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'QPay service error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to create QPay invoice');
      }

      AppLogger.success(
        'QPay invoice created successfully: ${result['invoice_id']}',
      );

      // Save order data to Firestore if provided by server
      if (result['orderData'] != null) {
        try {
          final String orderId = result['orderData']['orderId'];
          final DocumentReference orderRef = _firestore
              .collection('orders')
              .doc(orderId);

          // Convert server timestamp placeholders to actual timestamps
          final Map<String, dynamic> orderDataForFirestore =
              Map<String, dynamic>.from(result['orderData']);
          orderDataForFirestore['createdAt'] = FieldValue.serverTimestamp();
          orderDataForFirestore['updatedAt'] = FieldValue.serverTimestamp();

          await orderRef.set(orderDataForFirestore);
          AppLogger.success(
            'Order saved to Firestore orders collection: $orderId',
          );
        } catch (firestoreError) {
          AppLogger.error('Failed to save order to Firestore: $firestoreError');
          // Don't fail the entire operation if Firestore save fails
        }
      }

      // Return with consistent property names for frontend
      return QPayInvoiceResult(
        success: true,
        invoiceId: result['invoice_id'],
        qrText: result['qr_text'],
        qrDataURL: result['qr_data_url'],
        qrImageURL: result['qr_image_url'],
        bankUrls: List<String>.from(result['bank_urls'] ?? []),
        amount: result['amount']?.toDouble() ?? 0.0,
        products: List<Map<String, dynamic>>.from(result['products'] ?? []),
        orderId: result['order_id'],
        expiresAt:
            result['expires_at'] ??
            DateTime.now()
                .add(Duration(minutes: expirationMinutes))
                .toIso8601String(),
        accessToken: result['access_token'],
        sessionDuration: expirationMinutes * 60,
        metadata: Map<String, dynamic>.from(result['metadata'] ?? {}),
      );
    } catch (error) {
      AppLogger.error('QPayService.createInvoice error: $error');
      rethrow;
    }
  }

  /// Check payment status for an invoice with session validation
  ///
  /// [invoiceId] - QPay invoice ID
  /// [accessToken] - QPay access token (optional, handled by backend)
  ///
  /// Returns [QPayPaymentStatus] with payment status details
  static Future<QPayPaymentStatus> checkPaymentStatus(
    String invoiceId, [
    String? accessToken,
  ]) async {
    try {
      AppLogger.info('Checking payment status for invoice: $invoiceId');

      final response = await http.get(
        Uri.parse('$_baseUrl/payment-status/$invoiceId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'QPay service error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to check payment status');
      }

      // Check if payment was made
      final bool isPaid =
          (result['count'] ?? 0) > 0 && (result['paid_amount'] ?? 0) > 0;

      // Check session expiration
      final bool isExpired = result['is_expired'] ?? false;

      AppLogger.info(
        'Payment status for $invoiceId: isPaid=$isPaid, isExpired=$isExpired, count=${result['count']}, paidAmount=${result['paid_amount']}',
      );

      // If payment is confirmed, update order status in Firestore
      if (isPaid &&
          result['rows'] != null &&
          (result['rows'] as List).isNotEmpty) {
        try {
          final Map<String, dynamic> paymentData = result['rows'][0];
          await _updateOrderStatusByInvoiceId(invoiceId, 'paid', paymentData);
        } catch (updateError) {
          AppLogger.error(
            'Failed to update order status in Firestore: $updateError',
          );
          // Don't fail the payment check if Firestore update fails
        }
      }

      return QPayPaymentStatus(
        success: true,
        isPaid: isPaid,
        isExpired: isExpired,
        paymentData:
            result['rows'] != null && (result['rows'] as List).isNotEmpty
            ? Map<String, dynamic>.from(result['rows'][0])
            : null,
        totalPaid: result['paid_amount']?.toDouble() ?? 0.0,
        paymentCount: result['count'] ?? 0,
        sessionStatus: result['session_status'] ?? 'unknown',
      );
    } catch (error) {
      AppLogger.error('QPayService.checkPaymentStatus error: $error');
      rethrow;
    }
  }

  /// Check invoice session status (expiration, validity)
  ///
  /// [invoiceId] - QPay invoice ID
  ///
  /// Returns [QPaySessionStatus] with session status details
  static Future<QPaySessionStatus> checkSessionStatus(String invoiceId) async {
    try {
      AppLogger.info('Checking session status for invoice: $invoiceId');

      final response = await http.get(
        Uri.parse('$_baseUrl/session-status/$invoiceId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'QPay service error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to check session status');
      }

      AppLogger.info('Session status for $invoiceId: $result');

      return QPaySessionStatus(
        success: true,
        isActive: result['is_active'] ?? false,
        isExpired: result['is_expired'] ?? false,
        timeRemaining: result['time_remaining'] ?? 0,
        expiresAt: result['expires_at'],
        createdAt: result['created_at'],
      );
    } catch (error) {
      AppLogger.error('QPayService.checkSessionStatus error: $error');
      rethrow;
    }
  }

  /// Get QPay access token (handled by backend automatically)
  static Future<Map<String, dynamic>> getAccessToken() async {
    // This is handled automatically by the backend server
    AppLogger.success('Access token is handled by QPay server');
    return {'success': true, 'message': 'Token handled by backend'};
  }

  /// Generate QR code data URL (handled by backend during invoice creation)
  static Future<Map<String, dynamic>> generateQRCode(String qrText) async {
    // QR codes are generated automatically during invoice creation
    AppLogger.success('QR code generation is handled during invoice creation');
    return {'success': true, 'message': 'QR generated during invoice creation'};
  }

  /// Update invoice status in Firebase
  ///
  /// [invoiceId] - QPay invoice ID
  /// [status] - New status
  /// [paymentData] - Payment data
  ///
  /// Returns update result
  static Future<Map<String, dynamic>> updateInvoiceStatus(
    String invoiceId,
    String status,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      AppLogger.info(
        'Updating invoice status: invoiceId=$invoiceId, status=$status',
      );

      // For simulation purposes, we'll mark the status as updated
      AppLogger.success('Invoice status updated successfully (simulated)');

      return {
        'success': true,
        'invoiceId': invoiceId,
        'status': status,
        'paymentData': paymentData,
      };
    } catch (error) {
      AppLogger.error('QPayService.updateInvoiceStatus error: $error');
      rethrow;
    }
  }

  /// Update order status by QPay invoice ID
  ///
  /// [invoiceId] - QPay invoice ID
  /// [status] - New status ('paid', 'pending', etc.)
  /// [paymentData] - Payment data from QPay
  ///
  /// Returns update result
  static Future<Map<String, dynamic>> _updateOrderStatusByInvoiceId(
    String invoiceId,
    String status,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      AppLogger.info(
        'Updating order status by invoice ID: invoiceId=$invoiceId, status=$status',
      );

      // Find order by QPay invoice ID
      final Query ordersQuery = _firestore
          .collection('orders')
          .where('qpayInvoiceId', isEqualTo: invoiceId);

      final QuerySnapshot querySnapshot = await ordersQuery.get();

      if (querySnapshot.docs.isEmpty) {
        AppLogger.warning('No order found with QPay invoice ID: $invoiceId');
        return {'success': false, 'error': 'Order not found'};
      }

      // Process each matching order (should be only one)
      final List<Future<void>> updatePromises = [];

      for (final QueryDocumentSnapshot orderDoc in querySnapshot.docs) {
        final Map<String, dynamic> updateData = {
          'status': status,
          'paymentStatus': status == 'paid' ? 'PAID' : 'PENDING',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add payment data if provided
        if (paymentData != null) {
          updateData['paymentDate'] = paymentData['payment_date'];
          updateData['transactionId'] = paymentData['transaction_id'];
          updateData['paidAmount'] = paymentData['payment_amount'];
        }

        updatePromises.add(orderDoc.reference.update(updateData));

        // Just mark as paid, inventory will be handled separately
        if (status == 'paid') {
          AppLogger.success('Order marked as paid');
        }
      }

      // Wait for all order updates to complete
      await Future.wait(updatePromises);

      AppLogger.success(
        'Order status updated to "$status" for invoice: $invoiceId',
      );
      return {'success': true, 'invoiceId': invoiceId, 'status': status};
    } catch (error) {
      AppLogger.error(
        'QPayService._updateOrderStatusByInvoiceId error: $error',
      );
      rethrow;
    }
  }

  /// Update order in Firebase after payment
  ///
  /// [orderId] - Firebase order document ID
  /// [paymentData] - Payment data from QPay
  ///
  /// Returns update result
  static Future<Map<String, dynamic>> updateOrderAfterPayment(
    String orderId,
    Map<String, dynamic>? paymentData,
  ) async {
    try {
      AppLogger.info(
        'Updating order after payment: orderId=$orderId, paymentData=$paymentData',
      );

      if (orderId.isEmpty) {
        throw Exception('Order ID is required');
      }

      final DocumentReference orderRef = _firestore
          .collection('carts')
          .doc(orderId);

      // Check if order exists
      final DocumentSnapshot orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        throw Exception('Order not found: $orderId');
      }

      // Update order with payment information
      final Map<String, dynamic> updateData = {
        'status': 'paid',
        'paymentStatus': 'completed',
        'paymentMethod': 'QPay',
        'paidAt': FieldValue.serverTimestamp(),
        'transactionId':
            paymentData?['payment_id'] ??
            'QPAY_${DateTime.now().millisecondsSinceEpoch}',
        'qpayPaymentData': paymentData ?? {},
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await orderRef.update(updateData);

      AppLogger.success('Order updated successfully after QPay payment');

      return {'success': true, 'orderId': orderId, 'updateData': updateData};
    } catch (error) {
      AppLogger.error('QPayService.updateOrderAfterPayment error: $error');
      rethrow;
    }
  }

  /// Monitor QPay payment status with session awareness
  ///
  /// [invoiceId] - QPay invoice ID
  /// [callbacks] - Callback functions for payment events
  ///
  /// Returns monitoring result
  static Future<QPayMonitoringResult> monitorPayment(
    String invoiceId, {
    Function(Map<String, dynamic>)? onPaymentComplete,
    Function()? onSessionExpired,
    Function()? onTimeout,
    Function(dynamic)? onError,
  }) async {
    try {
      AppLogger.info('Starting payment monitoring for invoice: $invoiceId');

      const int maxAttempts = 30; // 5 minutes with 10-second intervals
      int attempts = 0;

      final Stream<void> checkInterval = Stream.periodic(
        const Duration(minutes: 3), // Check every 3 minutes
        (count) => count,
      ).take(maxAttempts);

      await for (final _ in checkInterval) {
        try {
          attempts++;
          AppLogger.info(
            'Payment check attempt $attempts/$maxAttempts for invoice: $invoiceId',
          );

          final QPayPaymentStatus paymentStatus = await checkPaymentStatus(
            invoiceId,
          );

          // Check if session expired
          if (paymentStatus.isExpired) {
            AppLogger.warning('Session expired during monitoring');
            onSessionExpired?.call();
            break;
          }

          // Check if payment completed
          if (paymentStatus.isPaid) {
            AppLogger.success('Payment completed! Invoking callback...');
            onPaymentComplete?.call(paymentStatus.paymentData ?? {});
            break;
          }

          if (attempts >= maxAttempts) {
            AppLogger.warning('Payment monitoring timeout reached');
            onTimeout?.call();
            break;
          }
        } catch (error) {
          AppLogger.error('Error during payment monitoring: $error');
          onError?.call(error);

          if (attempts >= maxAttempts) {
            break;
          }
        }
      }

      return QPayMonitoringResult(
        success: true,
        invoiceId: invoiceId,
        monitoringStarted: true,
      );
    } catch (error) {
      AppLogger.error('QPayService.monitorPayment error: $error');
      rethrow;
    }
  }

  /// Simulate payment for development/testing with session awareness
  ///
  /// [invoiceId] - QPay invoice ID
  /// [amount] - Payment amount
  /// [options] - Additional simulation options
  ///
  /// Returns simulation result
  static Future<Map<String, dynamic>> simulatePayment(
    String invoiceId,
    double amount, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      AppLogger.info('Simulating payment for invoice: $invoiceId');

      final Map<String, dynamic> requestBody = {
        'invoiceId': invoiceId,
        'amount': amount,
        'skipSessionCheck': options['skipSessionCheck'] ?? false,
        'simulateDelay': options['simulateDelay'] ?? 0,
        'metadata': {
          'simulatedAt': DateTime.now().toIso8601String(),
          ...?options['metadata'],
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/simulate-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'QPay service error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to simulate payment');
      }

      AppLogger.success('Payment simulation completed successfully');
      return result;
    } catch (error) {
      AppLogger.error('QPayService.simulatePayment error: $error');
      rethrow;
    }
  }

  /// Get order data from Firestore
  ///
  /// [orderId] - Order ID
  ///
  /// Returns order data result
  static Future<Map<String, dynamic>> getOrderFromFirestore(
    String orderId,
  ) async {
    try {
      AppLogger.info('Getting order from Firestore: $orderId');

      final response = await http.get(
        Uri.parse('$_baseUrl/order/$orderId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'QPay service error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['success'] != true) {
        throw Exception(
          result['error'] ?? 'Failed to get order from Firestore',
        );
      }

      AppLogger.success('Order retrieved from Firestore successfully');
      return result;
    } catch (error) {
      AppLogger.error('QPayService.getOrderFromFirestore error: $error');
      rethrow;
    }
  }

  /// Cancel/expire an active invoice session
  ///
  /// [invoiceId] - QPay invoice ID
  ///
  /// Returns cancellation result
  static Future<Map<String, dynamic>> cancelSession(String invoiceId) async {
    try {
      AppLogger.info('Cancelling session for invoice: $invoiceId');

      final Map<String, dynamic> requestBody = {
        'invoiceId': invoiceId,
        'cancelledAt': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/cancel-session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'QPay service error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to cancel session');
      }

      AppLogger.success('Session cancelled successfully');
      return result;
    } catch (error) {
      AppLogger.error('QPayService.cancelSession error: $error');
      rethrow;
    }
  }

  // Helper methods

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

  static String _generateOrderId() {
    return 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
  }
}
