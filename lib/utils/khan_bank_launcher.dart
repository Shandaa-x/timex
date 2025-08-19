/// Specialized Khan Bank app launcher utility
/// Handles different Khan Bank app launch methods and URL formats
library;

import 'package:url_launcher/url_launcher.dart';
import 'logger.dart';

class KhanBankLauncher {
  /// Try multiple methods to launch Khan Bank app with QPay QR code
  static Future<bool> launchKhanBankApp({
    required String qrText,
    String? invoiceId,
  }) async {
    AppLogger.info('Attempting to launch Khan Bank app with multiple methods...');
    
    final encodedQR = Uri.encodeComponent(qrText);
    
    // Method 1: Official QPay format (most reliable)
    final methods = [
      {
        'name': 'Official QPay Khan Bank format',
        'url': 'khanbank://q?qPay_QRcode=$encodedQR',
      },
      {
        'name': 'Khan Bank retail scheme',
        'url': 'khanbank-retail://q?qPay_QRcode=$encodedQR',
      },
      {
        'name': 'Khan Bank app scheme',
        'url': 'khanbankapp://q?qPay_QRcode=$encodedQR',
      },
      // Android-specific intent method
      if (invoiceId != null)
        {
          'name': 'Android Intent with package',
          'url': 'intent://q?qPay_QRcode=$encodedQR#Intent;package=com.khanbank.retail;scheme=khanbank;end;',
        },
    ];
    
    for (final method in methods) {
      try {
        AppLogger.info('Trying: ${method['name']}');
        final uri = Uri.parse(method['url']!);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          AppLogger.success('✅ Successfully launched Khan Bank with: ${method['name']}');
          return true;
        } else {
          AppLogger.warning('❌ Cannot launch with: ${method['name']}');
        }
      } catch (error) {
        AppLogger.error('Error with ${method['name']}: $error');
      }
    }
    
    AppLogger.error('All Khan Bank launch methods failed');
    return false;
  }
  
  /// Check if Khan Bank app is installed using multiple detection methods
  static Future<bool> isKhanBankInstalled() async {
    final testSchemes = [
      'khanbank://',
      'khanbank-retail://',
      'khanbankapp://',
    ];
    
    for (final scheme in testSchemes) {
      try {
        final uri = Uri.parse(scheme);
        if (await canLaunchUrl(uri)) {
          AppLogger.success('Khan Bank detected with scheme: $scheme');
          return true;
        }
      } catch (error) {
        AppLogger.warning('Failed to test scheme $scheme: $error');
      }
    }
    
    return false;
  }
  
  /// Get the best Khan Bank deep link format
  static Future<String?> getBestKhanBankDeepLink({
    required String qrText,
    String? invoiceId,
  }) async {
    final encodedQR = Uri.encodeComponent(qrText);
    
    final candidates = [
      'khanbank://q?qPay_QRcode=$encodedQR',
      'khanbank-retail://q?qPay_QRcode=$encodedQR',
      'khanbankapp://q?qPay_QRcode=$encodedQR',
    ];
    
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse(candidate);
        if (await canLaunchUrl(uri)) {
          AppLogger.success('Best Khan Bank link found: $candidate');
          return candidate;
        }
      } catch (error) {
        AppLogger.warning('Invalid candidate URL: $candidate');
      }
    }
    
    AppLogger.warning('No working Khan Bank deep link found');
    return null;
  }
}