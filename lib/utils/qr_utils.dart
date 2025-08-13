/// QR Code utilities for QPay integration
library qr_utils;

import '../utils/logger.dart';

/// Banking app information model
class BankingApp {
  final String name;
  final String description;
  final String deepLink;

  const BankingApp({
    required this.name,
    required this.description,
    required this.deepLink,
  });

  @override
  String toString() =>
      'BankingApp(name: $name, description: $description, deepLink: $deepLink)';
}

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

  /// Extract banking app deep links from QPay response
  static Map<String, BankingApp> extractBankingApps(
    Map<String, dynamic> qpayResult,
  ) {
    final bankingApps = <String, BankingApp>{};

    try {
      AppLogger.info('Extracting banking apps from QPay result');

      // Extract deep links from QPay URLs array
      if (qpayResult['urls'] != null) {
        final urls = qpayResult['urls'];
        AppLogger.info('Found URLs field: ${urls.runtimeType}');

        if (urls is List) {
          AppLogger.info('Processing ${urls.length} URLs from QPay response');
          for (int i = 0; i < urls.length; i++) {
            final url = urls[i];
            AppLogger.info('Processing URL $i: ${url.runtimeType}');

            if (url is Map<String, dynamic>) {
              final name = url['name']?.toString() ?? '';
              final description = url['description']?.toString() ?? '';
              final link = url['link']?.toString() ?? '';

              AppLogger.info(
                'URL $i - Name: $name, Description: $description, Link: ${link.length > 50 ? '${link.substring(0, 50)}...' : link}',
              );

              if (name.isNotEmpty && link.isNotEmpty) {
                // Clean the link to ensure it's valid
                final cleanLink = _cleanDeepLink(link);
                if (cleanLink != null) {
                  final key = name
                      .toLowerCase()
                      .replaceAll(' ', '')
                      .replaceAll('bank', '');
                  bankingApps[key] = BankingApp(
                    name: name,
                    description: description,
                    deepLink: cleanLink,
                  );
                  AppLogger.success('Added banking app: $name -> $key');
                } else {
                  AppLogger.warning('Skipped invalid link for $name: $link');
                }
              }
            }
          }
        }
      } else {
        AppLogger.warning('No URLs field found in QPay result');
      }

      // Add QPay app if invoice ID is available
      final invoiceId = qpayResult['invoice_id']?.toString();
      if (invoiceId != null && invoiceId.isNotEmpty) {
        bankingApps['qpay'] = BankingApp(
          name: 'QPay Wallet',
          description: 'QPay хэтэвч',
          deepLink: 'qpay://invoice?id=$invoiceId',
        );
        AppLogger.success('Added QPay wallet app');
      }

      AppLogger.success('Extracted ${bankingApps.length} banking apps total');
    } catch (error) {
      AppLogger.error('Error extracting banking apps', error);
    }

    return bankingApps;
  }

  /// Clean and validate deep link URL
  static String? _cleanDeepLink(String link) {
    try {
      // Remove any malformed JSON or extra characters
      String cleanedLink = link.trim();

      // Check if the link starts with a JSON object (common issue)
      if (cleanedLink.startsWith('{')) {
        AppLogger.warning(
          'Link starts with JSON, attempting to parse: ${cleanedLink.substring(0, 100)}...',
        );
        // Try to extract the actual link from JSON
        try {
          // This could be a JSON object containing the actual link
          // For now, we'll skip it but log the issue
          AppLogger.error('Cannot parse JSON-formatted link: $cleanedLink');
          return null;
        } catch (e) {
          AppLogger.error('Failed to parse JSON link: $e');
          return null;
        }
      }

      // Check if it looks like a valid scheme
      if (cleanedLink.contains('://')) {
        final schemePart = cleanedLink.split('://')[0];
        // Ensure scheme starts with alphabetic character
        if (schemePart.isNotEmpty &&
            RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*$').hasMatch(schemePart)) {
          AppLogger.success('Valid deep link: $schemePart://...');
          return cleanedLink;
        } else {
          AppLogger.warning('Invalid scheme in deep link: $schemePart');
          return null;
        }
      } else {
        AppLogger.warning('No scheme found in link: $cleanedLink');
        return null;
      }
    } catch (error) {
      AppLogger.error('Error cleaning deep link: $link', error);
      return null;
    }
  }

  /// Generate QPay deep links for mobile banking apps (legacy method)
  static Map<String, String> generateDeepLinks(
    String qrText,
    String? qpayShortUrl,
    String? invoiceId,
  ) {
    final deepLinks = <String, String>{};

    // QPay app deep link
    if (invoiceId != null && invoiceId.isNotEmpty) {
      deepLinks['qpay'] = 'qpay://invoice?id=$invoiceId';
    }

    // Social Pay deep link (Khan Bank) - use the correct payment scheme
    if (qrText.isNotEmpty) {
      // Use the actual scheme that Social Pay app expects
      deepLinks['socialpay'] =
          'socialpay-payment://q?qPay_QRcode=${Uri.encodeComponent(qrText)}';
    }

    // Khan Bank app deep link - use QR code format from QPay docs
    if (qrText.isNotEmpty) {
      deepLinks['khanbank'] =
          'khanbank://q?qPay_QRcode=${Uri.encodeComponent(qrText)}';
    }

    // Generic banking URL (web fallback)
    if (qpayShortUrl != null && qpayShortUrl.isNotEmpty) {
      deepLinks['banking'] = qpayShortUrl;
    } else if (qrText.isNotEmpty) {
      // Fallback to a generic QR code payment URL pattern
      deepLinks['banking'] =
          'https://qpay.mn/pay?qr=${Uri.encodeComponent(qrText)}';
    }

    return deepLinks;
  }

  /// Get primary deep link for opening in mobile banking app
  static String? getPrimaryDeepLink(
    String qrText,
    String? qpayShortUrl,
    String? invoiceId,
  ) {
    final deepLinks = generateDeepLinks(qrText, qpayShortUrl, invoiceId);

    // Priority order with fallback schemes
    final priorityOrder = [
      'qpay',
      'socialpay',
      'khanbank',
      'khanbankalt',
      'statebank',
      'statebankalt',
      'tdbbank',
      'tdb',
      'xacbank',
      'xac',
      'most',
      'mostmoney',
      'nibank',
      'ulaanbaatarbank',
      'ckbank',
      'chinggisnbank',
      'capitronbank',
      'capitron',
      'bogdbank',
      'bogd',
      'candypay',
      'candy',
      'banking',
    ];

    for (final scheme in priorityOrder) {
      if (deepLinks.containsKey(scheme)) {
        return deepLinks[scheme];
      }
    }

    return null;
  }

  /// Get primary banking app from QPay response
  static BankingApp? getPrimaryBankingApp(Map<String, dynamic> qpayResult) {
    final bankingApps = extractBankingApps(qpayResult);

    // Priority order: QPay app > Khan Bank > any other bank
    if (bankingApps.containsKey('qpay')) {
      return bankingApps['qpay'];
    }
    if (bankingApps.containsKey('khanbank') ||
        bankingApps.containsKey('khan')) {
      return bankingApps['khanbank'] ?? bankingApps['khan'];
    }

    // Return first available banking app
    if (bankingApps.isNotEmpty) {
      return bankingApps.values.first;
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
