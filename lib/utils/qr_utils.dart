/// QR Code utilities for QPay integration
library qr_utils;

import '../utils/logger.dart';

/// QR Code generation utilities
class QRUtils {
  /// Generate QR code data URL from QPay response
  static Future<String?> generateQRDataURL(String data) async {
    try {
      if (data.isEmpty) {
        throw Exception('QR code data cannot be empty');
      }

      AppLogger.info(
        'Processing QR code data: ${data.substring(0, data.length > 50 ? 50 : data.length)}...',
      );

      // QPay returns QR text that should be used directly with qr_flutter
      // The QR text contains the payment information that banking apps can scan
      AppLogger.success('QR code data processed successfully');
      return data; // Return the raw QR text for qr_flutter to use
    } catch (error) {
      AppLogger.error('Failed to process QR code data', error);
      return null;
    }
  }

  /// Validate QR code data
  static bool validateQRData(String data) {
    if (data.isEmpty) {
      return false;
    }

    // Basic validation - in a real app you might want more sophisticated validation
    return data.length <= 2953; // QR code capacity limit for alphanumeric data
  }

  /// Extract QPay payment URL from QR code data
  static String? extractPaymentURL(String qrData) {
    try {
      // QPay QR codes typically contain payment URLs
      if (qrData.startsWith('http')) {
        return qrData;
      }

      // If it's a different format, you might need to parse it
      AppLogger.info('Extracted payment URL from QR code');
      return qrData;
    } catch (error) {
      AppLogger.error('Failed to extract payment URL from QR code', error);
      return null;
    }
  }

  /// Get QR code display properties
  static Map<String, dynamic> getQRDisplayProperties({
    double size = 300,
    String backgroundColor = '#FFFFFF',
    String foregroundColor = '#000000',
    int margin = 2,
  }) {
    return {
      'size': size,
      'backgroundColor': backgroundColor,
      'foregroundColor': foregroundColor,
      'margin': margin,
      'errorCorrectionLevel': 'M',
      'version': 'auto',
    };
  }

  /// Validate QR code size constraints
  static bool validateQRSize(double size) {
    const double minSize = 100.0;
    const double maxSize = 1000.0;

    return size >= minSize && size <= maxSize;
  }

  /// Generate QR code text for display
  static String formatQRText(String data) {
    if (data.length <= 50) {
      return data;
    }
    return '${data.substring(0, 47)}...';
  }

  /// Check if data looks like a QPay QR code
  static bool isQPayQRCode(String data) {
    // QPay QR codes typically contain specific patterns
    return data.contains('qpay') ||
        data.contains('merchant') ||
        data.startsWith('https://qpay.mn/') ||
        data.contains('invoice_id');
  }

  /// Generate QPay deep links for mobile banking apps
  static Map<String, String> generateDeepLinks(String qrText, String? qpayShortUrl, String? invoiceId) {
    final deepLinks = <String, String>{};
    
    // QPay app deep link
    if (invoiceId != null && invoiceId.isNotEmpty) {
      deepLinks['qpay'] = 'qpay://invoice?id=$invoiceId';
    }
    
    // Social Pay deep link (Khan Bank)
    if (qpayShortUrl != null && qpayShortUrl.isNotEmpty) {
      deepLinks['socialpay'] = 'socialpay://qpay?url=${Uri.encodeComponent(qpayShortUrl)}';
    }
    
    // Khan Bank app deep link
    if (qrText.isNotEmpty) {
      deepLinks['khanbank'] = 'khanbank://qrpay?data=${Uri.encodeComponent(qrText)}';
    }
    
    // Always add generic banking options even if no URLs are available
    if (qpayShortUrl != null && qpayShortUrl.isNotEmpty) {
      deepLinks['banking'] = qpayShortUrl;
    } else if (qrText.isNotEmpty) {
      // Fallback to a generic QR code payment URL pattern
      deepLinks['banking'] = 'https://qpay.mn/pay?qr=${Uri.encodeComponent(qrText)}';
    }
    
    return deepLinks;
  }

  /// Get primary deep link for opening in mobile banking app
  static String? getPrimaryDeepLink(String qrText, String? qpayShortUrl, String? invoiceId) {
    final deepLinks = generateDeepLinks(qrText, qpayShortUrl, invoiceId);
    
    // Priority order: QPay app > Social Pay > Khan Bank > Generic banking
    if (deepLinks.containsKey('qpay')) {
      return deepLinks['qpay'];
    }
    if (deepLinks.containsKey('socialpay')) {
      return deepLinks['socialpay'];
    }
    if (deepLinks.containsKey('khanbank')) {
      return deepLinks['khanbank'];
    }
    if (deepLinks.containsKey('banking')) {
      return deepLinks['banking'];
    }
    
    return null;
  }

  /// Generate simple QR code info for debugging
  static Map<String, dynamic> getQRInfo(String data) {
    return {
      'length': data.length,
      'isValid': validateQRData(data),
      'isQPay': isQPayQRCode(data),
      'preview': formatQRText(data),
      'type': data.startsWith('http') ? 'URL' : 'DATA',
    };
  }
}
