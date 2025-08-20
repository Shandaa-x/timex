/// Banking app availability checker for deep links
library banking_app_checker;

import 'package:url_launcher/url_launcher.dart';
import 'logger.dart';

/// Class to check what banking apps are available on the device
class BankingAppChecker {
  /// Common Mongolian banking app schemes based on QPay documentation
  static const Map<String, String> bankingAppSchemes = {
    'Khan Bank': 'khanbank://',
    'Khan Bank Alt': 'khanbankapp://',
    'Social Pay': 'socialpay://',
    'Social Pay Payment': 'socialpay-payment://',
    'State Bank': 'statebank://',
    'State Bank Alt': 'statebankapp://',
    'TDB Bank': 'tdbbank://',
    'TDB Alt': 'tdb://',
    'Xac Bank': 'xacbank://',
    'Xac Alt': 'xac://',
    'Most Money': 'most://',
    'Most Money Alt': 'mostmoney://',
    'NIB Bank': 'nibank://',
    'UB Bank': 'ulaanbaatarbank://',
    'UB Bank Alt': 'ubbank://',
    'Chinggis Khaan Bank': 'ckbank://',
    'Chinggis Alt': 'chinggisnbank://',
    'Capitron Bank': 'capitronbank://',
    'Capitron Alt': 'capitron://',
    'Bogd Bank': 'bogdbank://',
    'Bogd Alt': 'bogd://',
    'Arig Bank': 'arigbank://',
    'Trans Bank': 'transbank://',
    'M Bank': 'mbank://',
    'Golomt Bank': 'golomtbank://',
    'Credit Bank': 'creditbank://',
    'Mongol Bank': 'mongolbank://',
    'Development Bank': 'developmentbank://',
    'Candy Pay': 'candypay://',
    'Candy Alt': 'candy://',
    'QPay Wallet': 'qpay://',
  };

  /// Check which banking apps are available on the device
  static Future<Map<String, bool>> checkAvailableBankingApps() async {
    final availabilityMap = <String, bool>{};

    AppLogger.info('Checking banking app availability...');

    for (final entry in bankingAppSchemes.entries) {
      try {
        // Try multiple approaches for iOS compatibility
        final baseUri = Uri.parse(entry.value);

        // Test with just the scheme
        bool isAvailable = await canLaunchUrl(baseUri);

        // If that fails, try with a common path
        if (!isAvailable) {
          final testUri = Uri.parse('${entry.value}open');
          isAvailable = await canLaunchUrl(testUri);
        }

        // Last attempt with different parameter
        if (!isAvailable) {
          final testUri = Uri.parse('${entry.value}launch');
          isAvailable = await canLaunchUrl(testUri);
        }

        availabilityMap[entry.key] = isAvailable;

        if (isAvailable) {
          AppLogger.success('${entry.key} is available (${entry.value})');
        } else {
          AppLogger.info('${entry.key} not available (${entry.value})');
        }
      } catch (error) {
        AppLogger.error('Error checking ${entry.key}', error);
        availabilityMap[entry.key] = false;
      }
    }

    final availableCount = availabilityMap.values
        .where((available) => available)
        .length;
    AppLogger.success(
      'Found $availableCount available banking apps out of ${bankingAppSchemes.length}',
    );

    return availabilityMap;
  }

  /// Test a specific deep link
  static Future<bool> testDeepLink(String deepLink) async {
    try {
      final uri = Uri.parse(deepLink);

      // First try the exact link
      bool canLaunch = await canLaunchUrl(uri);

      // If that fails, try just the scheme
      if (!canLaunch && uri.scheme.isNotEmpty) {
        final schemeUri = Uri.parse('${uri.scheme}://');
        canLaunch = await canLaunchUrl(schemeUri);
      }

      AppLogger.info(
        'Deep link test: $deepLink - ${canLaunch ? 'Available' : 'Not available'}',
      );
      return canLaunch;
    } catch (error) {
      AppLogger.error('Error testing deep link: $deepLink', error);
      return false;
    }
  }

  /// Test multiple schemes for a bank and return the working one
  static Future<String?> findWorkingScheme(List<String> schemes) async {
    for (final scheme in schemes) {
      try {
        final testUri = Uri.parse('${scheme}test');
        final canLaunch = await canLaunchUrl(testUri);
        if (canLaunch) {
          AppLogger.success('Working scheme found: $scheme');
          return scheme;
        }
      } catch (error) {
        AppLogger.warning('Scheme $scheme failed: $error');
      }
    }
    return null;
  }

  /// Get optimized deep links for each bank with correct parameters
  static Future<Map<String, String>> getOptimizedDeepLinks(
    String qrText,
    String? invoiceId,
  ) async {
    final workingSchemes = <String, String>{};
    final encodedQR = Uri.encodeComponent(qrText);

    // Test schemes for each bank with their specific deep link formats
    final bankSchemes = {
      'Khan Bank': ['khanbank://', 'khanbankapp://'],
      'Social Pay': ['socialpay-payment://', 'socialpay://'],
      'State Bank': ['statebank://', 'statebankapp://'],
      'TDB Bank': ['tdbbank://', 'tdb://'],
      'Xac Bank': ['xacbank://', 'xac://'],
      'Most Money': ['most://', 'mostmoney://'],
      'NIB Bank': ['nibank://', 'ulaanbaatarbank://'],
      'Chinggis Khaan Bank': ['ckbank://', 'chinggisnbank://'],
      'Capitron Bank': ['capitronbank://', 'capitron://'],
      'Bogd Bank': ['bogdbank://', 'bogd://'],
      'Arig Bank': ['arigbank://', 'arig://'],
      'Trans Bank': ['transbank://'],
      'M Bank': ['mbank://'],
      'Candy Pay': ['candypay://', 'candy://'],
      'QPay Wallet': ['qpay://'],
    };

    for (final entry in bankSchemes.entries) {
      final workingScheme = await findWorkingScheme(entry.value);
      if (workingScheme != null) {
        // Create proper deep link based on the working scheme and bank-specific formats
        String deepLink = _generateBankSpecificDeepLink(
          entry.key,
          workingScheme,
          qrText,
          encodedQR,
          invoiceId,
        );

        workingSchemes[entry.key] = deepLink;
        AppLogger.success('${entry.key}: $deepLink');
      }
    }

    return workingSchemes;
  }

  /// Generate bank-specific deep link with correct parameters
  static String _generateBankSpecificDeepLink(
    String bankName,
    String scheme,
    String qrText,
    String encodedQR,
    String? invoiceId,
  ) {
    switch (bankName) {
      case 'QPay Wallet':
        if (invoiceId != null && invoiceId.isNotEmpty) {
          return 'qpay://invoice?id=$invoiceId';
        }
        return 'qpay://qr?data=$encodedQR';

      case 'Social Pay':
        // SocialPay uses a specific format that works
        if (scheme.contains('payment')) {
          return 'socialpay-payment://q?qPay_QRcode=$encodedQR';
        }
        return 'socialpay://qpay?qr=$encodedQR';

      case 'Khan Bank':
        // Khan Bank variations - try the format that works like SocialPay
        if (scheme.contains('khanbank://')) {
          return 'khanbank://q?qPay_QRcode=$encodedQR';
        }
        return 'khanbankapp://qpay?qr=$encodedQR';

      case 'State Bank':
        if (scheme.contains('statebank://')) {
          return 'statebank://q?qPay_QRcode=$encodedQR';
        }
        return 'statebankapp://qpay?qr=$encodedQR';

      case 'TDB Bank':
        if (scheme.contains('tdbbank://')) {
          return 'tdbbank://q?qPay_QRcode=$encodedQR';
        }
        return 'tdb://qpay?qr=$encodedQR';

      case 'Xac Bank':
        if (scheme.contains('xacbank://')) {
          return 'xacbank://q?qPay_QRcode=$encodedQR';
        }
        return 'xac://qpay?qr=$encodedQR';

      case 'Most Money':
        if (scheme.contains('most://')) {
          return 'most://q?qPay_QRcode=$encodedQR';
        }
        return 'mostmoney://qpay?qr=$encodedQR';

      case 'NIB Bank':
        if (scheme.contains('nibank://')) {
          return 'nibank://q?qPay_QRcode=$encodedQR';
        }
        return 'ulaanbaatarbank://qpay?qr=$encodedQR';

      case 'Chinggis Khaan Bank':
        if (scheme.contains('ckbank://')) {
          return 'ckbank://q?qPay_QRcode=$encodedQR';
        }
        return 'chinggisnbank://qpay?qr=$encodedQR';

      case 'Capitron Bank':
        if (scheme.contains('capitronbank://')) {
          return 'capitronbank://q?qPay_QRcode=$encodedQR';
        }
        return 'capitron://qpay?qr=$encodedQR';

      case 'Bogd Bank':
        if (scheme.contains('bogdbank://')) {
          return 'bogdbank://q?qPay_QRcode=$encodedQR';
        }
        return 'bogd://qpay?qr=$encodedQR';

      case 'Arig Bank':
        return 'arigbank://q?qPay_QRcode=$encodedQR';

      case 'Trans Bank':
        return 'transbank://q?qPay_QRcode=$encodedQR';

      case 'M Bank':
        return 'mbank://q?qPay_QRcode=$encodedQR';

      case 'Candy Pay':
        if (scheme.contains('candypay://')) {
          return 'candypay://q?qPay_QRcode=$encodedQR';
        }
        return 'candy://qpay?qr=$encodedQR';

      default:
        // Generic format - use the SocialPay-like format as it seems to work
        return '${scheme}q?qPay_QRcode=$encodedQR';
    }
  }

  /// Get a formatted report of available banking apps
  static Future<String> getAvailabilityReport() async {
    final availability = await checkAvailableBankingApps();
    final report = StringBuffer();

    report.writeln('Banking App Availability Report:');
    report.writeln('================================');

    for (final entry in availability.entries) {
      final status = entry.value ? '✅ Available' : '❌ Not Available';
      report.writeln('${entry.key}: $status');
    }

    return report.toString();
  }
}
