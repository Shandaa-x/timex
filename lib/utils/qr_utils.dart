/// QR Code utilities for QPay integration
library qr_utils;

import '../utils/logger.dart';

/// QR Code generation utilities
class QRUtils {
  /// Generate QR code data URL (placeholder implementation)
  /// In a real app, you would use a package like qr_flutter
  static Future<String?> generateQRDataURL(String data) async {
    try {
      if (data.isEmpty) {
        throw Exception('QR code data cannot be empty');
      }

      AppLogger.info(
        'Generating QR code data URL for: ${data.substring(0, data.length > 50 ? 50 : data.length)}...',
      );

      // This is a placeholder implementation
      // In a real app, you would:
      // 1. Use qr_flutter package to generate QR code
      // 2. Convert it to image bytes
      // 3. Encode to base64

      // For now, return a placeholder data URL
      const String placeholderQR =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

      AppLogger.success(
        'QR code data URL generated successfully (placeholder)',
      );
      return placeholderQR;
    } catch (error) {
      AppLogger.error('Failed to generate QR code data URL', error);
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
