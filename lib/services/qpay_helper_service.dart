import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// QPay Helper Service - Based on helper functions from CLAUDE.md
class QPayHelperService {
  static const String _baseUrl = 'https://merchant.qpay.mn/v2';
  static const String _username = 'GRAND_IT';
  static const String _password = 'gY8ljnov';
  static const String _template = 'GRAND_IT_INVOICE';

  /// Get QPay access token
  static Future<Map<String, dynamic>> getAccessToken() async {
    try {
      AppLogger.info('Getting QPay access token...');

      // Create Basic Auth header
      final String basicAuth =
          'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/token'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
      );

      AppLogger.info('QPay auth response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('QPay access token obtained successfully');
        return {'success': true, ...data};
      } else {
        final error =
            'QPay auth failed: ${response.statusCode} ${response.body}';
        AppLogger.error(error);
        return {'success': false, 'error': error};
      }
    } catch (error) {
      AppLogger.error('Error getting QPay access token: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Create QPay invoice with dynamic amount
  static Future<Map<String, dynamic>> createInvoice({
    required String token,
    required double amount,
    required String orderId,
    required String userId,
    required String invoiceDescription,
    String? callbackUrl,
  }) async {
    final payload = {
      // Required fields by QPay API
      'invoice_code': _template,
      'sender_invoice_no': orderId,
      'invoice_receiver_code': userId.isEmpty ? 'terminal' : userId,
      'invoice_description': invoiceDescription,
      'amount': amount.round(),
      'callback_url': callbackUrl ?? 'http://localhost:3000/qpay/webhook',
      
      // Optional but recommended fields
      'allow_partial': true,  // Allow partial payments
      'minimum_amount': 100,  // Minimum 100 MNT
      'allow_exceed': true,   // Allow paying more than invoice amount
      'maximum_amount': (amount * 10).round(), // Up to 10x the invoice amount
    };

    try {
      AppLogger.info(
        'Creating QPay invoice with payload: ${json.encode(payload)}',
      );

      final response = await http.post(
        Uri.parse('$_baseUrl/invoice'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      AppLogger.info('QPay invoice response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success(
          'QPay invoice created successfully: ${data['invoice_id']}',
        );
        return {'success': true, ...data};
      } else {
        final error =
            'QPay invoice creation failed: ${response.statusCode} ${response.body}';
        AppLogger.error(error);
        return {'success': false, 'error': error};
      }
    } catch (error) {
      AppLogger.error('Error creating QPay invoice: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get invoice information
  static Future<Map<String, dynamic>> getInvoice(
    String token,
    String invoiceId,
  ) async {
    try {
      AppLogger.info('Getting QPay invoice: $invoiceId');

      final response = await http.get(
        Uri.parse('$_baseUrl/invoice/$invoiceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('QPay invoice retrieved successfully');
        return {'success': true, ...data};
      } else {
        final error =
            'Failed to get QPay invoice: ${response.statusCode} ${response.body}';
        AppLogger.error(error);
        return {'success': false, 'error': error};
      }
    } catch (error) {
      AppLogger.error('Error getting QPay invoice: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Check payment status
  static Future<Map<String, dynamic>> checkPayment(
    String token,
    String invoiceId,
  ) async {
    try {
      AppLogger.info('Checking QPay payment status for: $invoiceId');

      final response = await http.post(
        Uri.parse('$_baseUrl/payment/check'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'object_type': 'INVOICE',
          'object_id': invoiceId,
          'offset': {'page_number': 1, 'page_limit': 100},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('QPay payment check completed');
        return {'success': true, ...data};
      } else {
        final error =
            'Failed to check QPay payment: ${response.statusCode} ${response.body}';
        AppLogger.error(error);
        return {'success': false, 'error': error};
      }
    } catch (error) {
      AppLogger.error('Error checking QPay payment: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Create invoice with QR code (complete flow)
  static Future<Map<String, dynamic>> createInvoiceWithQR({
    required double amount,
    required String orderId,
    required String userId,
    required String invoiceDescription,
    String? callbackUrl,
  }) async {
    try {
      AppLogger.info('Creating QPay invoice with QR for order: $orderId');

      // Step 1: Get access token
      final authResult = await getAccessToken();
      if (authResult['success'] != true) {
        return {
          'success': false,
          'error': 'Authentication failed: ${authResult['error']}',
        };
      }

      // Step 2: Create invoice
      final invoiceResult = await createInvoice(
        token: authResult['access_token'],
        amount: amount,
        orderId: orderId,
        userId: userId,
        invoiceDescription: invoiceDescription,
        callbackUrl: callbackUrl,
      );

      if (invoiceResult['success'] != true) {
        return {
          'success': false,
          'error': 'Invoice creation failed: ${invoiceResult['error']}',
        };
      }

      AppLogger.success('QPay invoice with QR created successfully');

      // Return complete result
      return {
        'success': true,
        'invoice': invoiceResult,
        'access_token': authResult['access_token'],
      };
    } catch (error) {
      AppLogger.error('Error in createInvoiceWithQR: $error');
      return {'success': false, 'error': error.toString()};
    }
  }
}
