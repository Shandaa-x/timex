/// QPay Helper Utilities
/// Dart implementation of QPay helper functions for Flutter
library qpay_helper;

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/qpay_config.dart';
import '../models/qpay_models.dart';
import '../utils/logger.dart';

/// QPay Helper class with core functionality
class QPayHelper {
  static String get _baseUrl => QPayConfig.baseUrl;
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Get access token from QPay API
  static Future<Map<String, dynamic>> getAccessToken() async {
    try {
      AppLogger.qpay('auth', 'Requesting access token from QPay');

      final String credentials = base64Encode(
        utf8.encode('${QPayConfig.username}:${QPayConfig.password}'),
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/token'),
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/json',
            },
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Cache token
        _accessToken = data['access_token'];
        final int expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: expiresIn - 300),
        ); // 5 min buffer

        AppLogger.success('QPay access token obtained successfully');
        return {'success': true, ...data};
      } else {
        throw Exception('Authentication failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('Failed to get QPay access token', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Refresh access token
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      AppLogger.qpay('auth', 'Refreshing access token');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refresh_token': refreshToken}),
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Cache new token
        _accessToken = data['access_token'];
        final int expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));

        AppLogger.success('QPay access token refreshed successfully');
        return {'success': true, ...data};
      } else {
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('Failed to refresh QPay token', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Ensure we have a valid access token
  static Future<String> ensureAuthenticated() async {
    // Check if token exists and is not expired
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final result = await getAccessToken();
    if (result['success'] == true) {
      return result['access_token'];
    } else {
      throw Exception(result['error']);
    }
  }

  /// Create invoice for multiple products
  static Future<Map<String, dynamic>> createInvoice(
    String token,
    List<QPayProduct> products,
    String orderId,
    String userId, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      // Validate products
      _validateProducts(products);

      // Calculate total amount
      double totalAmount;
      if (options['totalAmount'] != null && options['totalAmount'] is num) {
        totalAmount = (options['totalAmount'] as num).toDouble();
        AppLogger.info(
          'Using provided totalAmount: \$${totalAmount.toStringAsFixed(2)}',
        );
      } else {
        totalAmount = _calculateTotalAmount(products);
        AppLogger.info(
          'Calculated amount from products: \$${totalAmount.toStringAsFixed(2)}',
        );
      }

      // Build description and invoice number
      final String description = _buildProductDescription(products);
      final String invoiceNo = _generateInvoiceNumber(orderId);

      final Map<String, dynamic> payload = {
        'invoice_code': QPayConfig.template,
        'sender_invoice_no': invoiceNo,
        'invoice_receiver_code': userId.isEmpty ? 'terminal' : userId,
        'invoice_description': description,
        'amount': totalAmount.round(),
        'callback_url': QPayConfig.callbackUrl,
      };

      AppLogger.qpay('invoice', 'Creating QPay invoice', {
        'orderId': orderId,
        'products': products.length,
        'amount': totalAmount,
        'invoiceNo': invoiceNo,
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/invoice'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        AppLogger.success(
          'QPay invoice created successfully: ${data['invoice_id']}',
        );

        return {
          'success': true,
          ...data,
          'products': products.map((p) => p.toJson()).toList(),
          'total_amount': totalAmount.round(),
        };
      } else {
        throw Exception(
          'Invoice creation failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (error) {
      AppLogger.error('Failed to create QPay invoice', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get invoice details
  static Future<Map<String, dynamic>> getInvoice(
    String token,
    String invoiceId,
  ) async {
    try {
      AppLogger.qpay('invoice', 'Getting invoice details: $invoiceId');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/invoice/$invoiceId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        AppLogger.success('QPay invoice details retrieved: $invoiceId');
        return {'success': true, ...data};
      } else {
        throw Exception('Get invoice failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('Failed to get QPay invoice', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Cancel invoice
  static Future<Map<String, dynamic>> cancelInvoice(
    String token,
    String invoiceId,
  ) async {
    try {
      AppLogger.qpay('invoice', 'Cancelling invoice: $invoiceId');

      final response = await http
          .delete(
            Uri.parse('$_baseUrl/invoice/$invoiceId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        AppLogger.success('QPay invoice cancelled: $invoiceId');
        return {'success': true, ...data};
      } else {
        throw Exception('Cancel invoice failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('Failed to cancel QPay invoice', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Check payment status
  static Future<Map<String, dynamic>> checkPayment(
    String token,
    String invoiceId,
  ) async {
    try {
      AppLogger.qpay('payment', 'Checking payment status: $invoiceId');

      final Map<String, dynamic> payload = {
        'object_type': 'INVOICE',
        'object_id': invoiceId,
        'offset': {'page_number': 1, 'page_limit': 100},
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/payment/check'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        AppLogger.qpay('payment', 'Payment check completed: $invoiceId', {
          'count': data['count'],
          'paid_amount': data['paid_amount'],
        });
        return {'success': true, ...data};
      } else {
        throw Exception('Payment check failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('Failed to check QPay payment', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// List payments
  static Future<Map<String, dynamic>> listPayments(
    String token, {
    Map<String, dynamic> query = const {},
  }) async {
    try {
      AppLogger.qpay('payment', 'Listing payments');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/payment/list'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(query),
          )
          .timeout(QPayConfig.httpTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        AppLogger.success('QPay payments listed successfully');
        return {'success': true, ...data};
      } else {
        throw Exception('List payments failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('Failed to list QPay payments', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Create invoice with QR code (main function)
  static Future<QPayInvoiceResult> createInvoiceWithQR(
    List<QPayProduct> products,
    String orderId,
    String userId, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      // Validate products
      if (products.isEmpty) {
        throw Exception('Products array is required and must not be empty');
      }

      for (final product in products) {
        if (product.name.isEmpty ||
            product.amount <= 0 ||
            product.quantity <= 0) {
          throw Exception(
            'Each product must have valid name, amount, and quantity',
          );
        }
      }

      // 1. Get access token
      AppLogger.qpay('auth', 'Connecting to QPay...');
      final String token = await ensureAuthenticated();

      // 2. Create invoice
      AppLogger.qpay('invoice', 'Creating invoice...');
      final Map<String, dynamic> invoiceResult = await createInvoice(
        token,
        products,
        orderId,
        userId,
        options: options,
      );

      if (invoiceResult['success'] != true) {
        throw Exception('Invoice creation failed: ${invoiceResult['error']}');
      }

      // 3. Generate QR code data URL for frontend
      AppLogger.qpay('qr', 'Generating QR code...');
      final String? qrDataURL = await _generateQRDataURL(
        invoiceResult['qr_text'],
      );

      // 4. Return complete result
      return QPayInvoiceResult(
        success: true,
        invoiceId: invoiceResult['invoice_id'],
        qrText: invoiceResult['qr_text'],
        qrDataURL: qrDataURL,
        bankUrls: List<String>.from(invoiceResult['urls'] ?? []),
        amount: invoiceResult['total_amount']?.toDouble() ?? 0.0,
        products: List<Map<String, dynamic>>.from(
          products.map((p) => p.toJson()).toList(),
        ),
        orderId: orderId,
        expiresAt: DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        accessToken: token,
      );
    } catch (error) {
      AppLogger.error('Failed to create QPay invoice with QR', error);
      return QPayInvoiceResult.error(error.toString());
    }
  }

  // Helper methods

  /// Validate products array
  static void _validateProducts(List<QPayProduct> products) {
    if (products.isEmpty) {
      throw Exception('Products array cannot be empty');
    }

    for (final product in products) {
      if (product.name.trim().isEmpty) {
        throw Exception('Product name cannot be empty');
      }
      if (product.amount <= 0) {
        throw Exception('Product amount must be greater than 0');
      }
      if (product.quantity <= 0) {
        throw Exception('Product quantity must be greater than 0');
      }
    }
  }

  /// Calculate total amount from products
  static double _calculateTotalAmount(List<QPayProduct> products) {
    return products.fold(
      0.0,
      (sum, product) => sum + (product.amount * product.quantity),
    );
  }

  /// Build product description
  static String _buildProductDescription(List<QPayProduct> products) {
    if (products.length == 1) {
      final product = products.first;
      return '${product.name} x${product.quantity}';
    }

    final String summary = '${products.length} items: ';
    final String items = products
        .take(3)
        .map((p) => '${p.name} x${p.quantity}')
        .join(', ');

    String description = summary + items;

    if (products.length > 3) {
      description += '...';
    }

    // Ensure description doesn't exceed max length
    if (description.length > QPayConfig.maxDescriptionLength) {
      description =
          description.substring(0, QPayConfig.maxDescriptionLength - 3) + '...';
    }

    return description;
  }

  /// Generate invoice number
  static String _generateInvoiceNumber(String orderId, [String prefix = 'BX']) {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String randomSuffix = _generateRandomString(4);
    String invoiceNo = '${prefix}_${orderId}_${timestamp}_$randomSuffix';

    // Ensure it doesn't exceed max length
    if (invoiceNo.length > QPayConfig.maxInvoiceNoLength) {
      // Truncate order ID if necessary
      final int maxOrderIdLength =
          QPayConfig.maxInvoiceNoLength -
          prefix.length -
          timestamp.length -
          randomSuffix.length -
          3; // 3 underscores

      if (maxOrderIdLength > 0) {
        final String truncatedOrderId = orderId.length > maxOrderIdLength
            ? orderId.substring(0, maxOrderIdLength)
            : orderId;
        invoiceNo = '${prefix}_${truncatedOrderId}_${timestamp}_$randomSuffix';
      } else {
        // If still too long, use just timestamp and random
        invoiceNo = '${prefix}_${timestamp}_$randomSuffix';
      }
    }

    return invoiceNo;
  }

  /// Generate random string
  static String _generateRandomString(int length) {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Generate QR code data URL (placeholder implementation)
  static Future<String?> _generateQRDataURL(String? qrText) async {
    if (qrText == null || qrText.isEmpty) {
      return null;
    }

    // In a real implementation, you would use a QR code library like qr_flutter
    // For now, return a placeholder
    AppLogger.info('QR code generation completed (placeholder)');
    return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
  }

  /// Handle errors in a consistent way
  static Map<String, dynamic> handleError(String operation, dynamic error) {
    final String errorMessage = error.toString();
    AppLogger.error('QPay operation failed: $operation', error);

    return {
      'success': false,
      'error': errorMessage,
      'operation': operation,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Generate order ID
  static String generateOrderId([String prefix = 'ORDER']) {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String random = _generateRandomString(6);
    return '${prefix}_${timestamp}_$random';
  }

  /// Generate batch order ID
  static String generateBatchOrderId(
    int orderCount, [
    String prefix = 'BATCH',
  ]) {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String random = _generateRandomString(4);
    return '${prefix}_${orderCount}ORDERS_${timestamp}_$random';
  }
}
