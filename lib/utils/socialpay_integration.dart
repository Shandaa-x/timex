import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'logger.dart';

/// SocialPay payment request model
class SocialPayPaymentRequest {
  final double amount;
  final String description;
  final String invoiceId;
  final String? merchantId;
  final String? qrCode;
  final String? callbackUrl;
  final String? socialPayKey; // Official SocialPay deep link key

  const SocialPayPaymentRequest({
    required this.amount,
    required this.description,
    required this.invoiceId,
    this.merchantId,
    this.qrCode,
    this.callbackUrl,
    this.socialPayKey,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'description': description,
    'invoiceId': invoiceId,
    'merchantId': merchantId,
    'qrCode': qrCode,
    'callbackUrl': callbackUrl,
    'socialPayKey': socialPayKey,
  };
}

/// SocialPay integration result
class SocialPayResult {
  final bool success;
  final String message;
  final SocialPayAction action;
  final String? error;

  const SocialPayResult({
    required this.success,
    required this.message,
    required this.action,
    this.error,
  });

  factory SocialPayResult.success(String message, SocialPayAction action) =>
      SocialPayResult(
        success: true,
        message: message,
        action: action,
      );

  factory SocialPayResult.error(String message, String error) =>
      SocialPayResult(
        success: false,
        message: message,
        action: SocialPayAction.error,
        error: error,
      );
}

/// Actions taken during SocialPay integration
enum SocialPayAction {
  appOpened,
  redirectedToStore,
  fallbackUsed,
  error,
}

/// Comprehensive SocialPay integration utility
class SocialPayIntegration {
  /// SocialPay app store URLs and package IDs
  static const List<String> _androidPackageIds = [
    'mn.socialpay',           // Primary SocialPay package
    'com.khan.socialpay',     // Alternative SocialPay package (legacy)
    'mn.socialpay.wallet',    // SocialPay wallet variant
  ];
  static const String _iosAppId = '1591439099'; // SocialPay App Store ID
  
  /// Current SocialPay deep link schemes (2025) - ordered by preference
  static const List<String> _socialPaySchemes = [
    'socialpay://',          // Primary SocialPay scheme (no key needed)
    'mn.socialpay://',       // Package-based scheme
    'socialpaywallet://',    // Alternative wallet scheme
    'socialpay-payment://',  // Official SocialPay scheme (requires key parameter - use last)
  ];

  /// Khan Bank specific schemes (separate from SocialPay)
  static const List<String> _khanBankSchemes = [
    'khanbank://',           // Khan Bank app
    'khanbankapp://',        // Alternative Khan Bank scheme
  ];

  /// Check if SocialPay app is installed (separate from Khan Bank)
  static Future<bool> isAppInstalled() async {
    AppLogger.info('Checking SocialPay app availability...');
    
    // Method 1: Try deep link schemes
    for (final scheme in _socialPaySchemes) {
      try {
        final uri = Uri.parse('${scheme}test');
        final canLaunch = await canLaunchUrl(uri);
        
        if (canLaunch) {
          AppLogger.success('Found SocialPay app with scheme: $scheme');
          return true;
        }
      } catch (error) {
        AppLogger.warning('SocialPay scheme $scheme not available: $error');
      }
    }
    
    // Method 2: Try package-specific schemes for Android
    if (Platform.isAndroid) {
      for (final packageId in _androidPackageIds) {
        try {
          final packageUri = Uri.parse('package:$packageId');
          final canLaunchPackage = await canLaunchUrl(packageUri);
          if (canLaunchPackage) {
            AppLogger.success('Found SocialPay app via package scheme: $packageId');
            return true;
          }
        } catch (error) {
          AppLogger.warning('Package scheme $packageId not available: $error');
        }
      }
    }
    
    AppLogger.warning('SocialPay app not detected on device');
    return false;
  }

  /// Check if Khan Bank app is installed (separate check)
  static Future<bool> isKhanBankInstalled() async {
    AppLogger.info('Checking Khan Bank app availability...');
    
    for (final scheme in _khanBankSchemes) {
      try {
        final uri = Uri.parse('${scheme}test');
        final canLaunch = await canLaunchUrl(uri);
        
        if (canLaunch) {
          AppLogger.success('Found Khan Bank app with scheme: $scheme');
          return true;
        }
      } catch (error) {
        AppLogger.warning('Khan Bank scheme $scheme not available: $error');
      }
    }
    
    AppLogger.warning('Khan Bank app not detected on device');
    return false;
  }

  /// Get the best available deep link scheme
  static Future<String?> _getAvailableScheme() async {
    for (final scheme in _socialPaySchemes) {
      try {
        final uri = Uri.parse('${scheme}test');
        final canLaunch = await canLaunchUrl(uri);
        
        if (canLaunch) {
          return scheme;
        }
      } catch (error) {
        continue;
      }
    }
    return null;
  }

  /// Generate SocialPay deep link URL
  static String _generateDeepLink(
    String scheme,
    SocialPayPaymentRequest request,
  ) {
    // Official SocialPay deep link formats (2025)
    switch (scheme) {
      case 'socialpay-payment://':
        // Official SocialPay format - requires key from E-Commerce API
        if (request.socialPayKey != null && request.socialPayKey!.isNotEmpty) {
          return 'socialpay-payment://key=${request.socialPayKey!}';
        } else {
          // Skip this scheme if no key available, let caller try next scheme
          throw ArgumentError('Key required for socialpay-payment:// scheme');
        }

      case 'socialpay://':
      case 'mn.socialpay://':
      case 'socialpaywallet://':
        // Standard SocialPay formats (no key required)
        if (request.qrCode != null && request.qrCode!.isNotEmpty) {
          return '${scheme}qpay?qr=${Uri.encodeComponent(request.qrCode!)}';
        } else {
          return '${scheme}payment?'
              'amount=${request.amount}&'
              'description=${Uri.encodeComponent(request.description)}&'
              'invoiceId=${Uri.encodeComponent(request.invoiceId)}';
        }

      default:
        // Fallback for any other scheme
        if (request.qrCode != null && request.qrCode!.isNotEmpty) {
          return '${scheme}qpay?qr=${Uri.encodeComponent(request.qrCode!)}';
        } else {
          return '${scheme}payment?'
              'amount=${request.amount}&'
              'description=${Uri.encodeComponent(request.description)}&'
              'invoiceId=${Uri.encodeComponent(request.invoiceId)}';
        }
    }
  }

  /// Open SocialPay app with payment request
  static Future<SocialPayResult> openApp(
    SocialPayPaymentRequest request,
  ) async {
    try {
      AppLogger.info('Attempting to open SocialPay app...');
      AppLogger.info('Payment request: ${request.toJson()}');

      // Check if app is installed
      final isInstalled = await isAppInstalled();
      if (!isInstalled) {
        AppLogger.warning('SocialPay app not installed, redirecting to store');
        final storeResult = await _redirectToAppStore();
        return storeResult;
      }

      // Try each available scheme until one works
      for (final scheme in _socialPaySchemes) {
        try {
          final uri = Uri.parse('${scheme}test');
          final canLaunch = await canLaunchUrl(uri);
          
          if (!canLaunch) {
            AppLogger.info('Scheme $scheme not available, trying next...');
            continue;
          }

          // Try to generate deep link for this scheme
          String deepLink;
          try {
            deepLink = _generateDeepLink(scheme, request);
          } catch (error) {
            AppLogger.warning('Failed to generate deep link for $scheme: $error');
            continue; // Try next scheme
          }

          AppLogger.info('Trying deep link: $deepLink');

          // Launch app
          final launchUri = Uri.parse(deepLink);
          final launched = await launchUrl(
            launchUri,
            mode: LaunchMode.externalApplication,
          );

          if (launched) {
            AppLogger.success('Successfully opened SocialPay app with scheme: $scheme');
            return SocialPayResult.success(
              'Opened SocialPay app successfully',
              SocialPayAction.appOpened,
            );
          } else {
            AppLogger.warning('Failed to launch with scheme $scheme, trying next...');
          }
        } catch (error) {
          AppLogger.warning('Error with scheme $scheme: $error');
          continue; // Try next scheme
        }
      }

      // If all schemes failed, redirect to app store
      AppLogger.error('All schemes failed, redirecting to store');
      final storeResult = await _redirectToAppStore();
      return storeResult;

    } catch (error) {
      AppLogger.error('Error opening SocialPay app', error);
      return SocialPayResult.error(
        'Failed to open SocialPay app: $error',
        error.toString(),
      );
    }
  }

  /// Redirect user to app store to install SocialPay
  static Future<SocialPayResult> _redirectToAppStore() async {
    try {
      String storeUrl;
      
      if (Platform.isAndroid) {
        // Use primary package ID for Play Store
        final primaryPackageId = _androidPackageIds.first;
        storeUrl = 'https://play.google.com/store/apps/details?id=$primaryPackageId';
        
        // Try Play Store app first
        final playStoreUri = Uri.parse('market://details?id=$primaryPackageId');
        final canLaunchPlayStore = await canLaunchUrl(playStoreUri);
        
        if (canLaunchPlayStore) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
          AppLogger.success('Redirected to Google Play Store app');
        } else {
          // Fallback to web browser
          final webUri = Uri.parse(storeUrl);
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          AppLogger.success('Redirected to Google Play Store web');
        }
      } else if (Platform.isIOS) {
        // App Store
        storeUrl = 'https://apps.apple.com/app/id$_iosAppId';
        
        // Try App Store app first
        final appStoreUri = Uri.parse('itms-apps://apps.apple.com/app/id$_iosAppId');
        final canLaunchAppStore = await canLaunchUrl(appStoreUri);
        
        if (canLaunchAppStore) {
          await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
          AppLogger.success('Redirected to App Store app');
        } else {
          // Fallback to web browser
          final webUri = Uri.parse(storeUrl);
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          AppLogger.success('Redirected to App Store web');
        }
      } else {
        throw UnsupportedError('Platform not supported');
      }

      return SocialPayResult.success(
        'Redirected to app store to install SocialPay',
        SocialPayAction.redirectedToStore,
      );

    } catch (error) {
      AppLogger.error('Error redirecting to app store', error);
      return SocialPayResult.error(
        'Failed to redirect to app store: $error',
        error.toString(),
      );
    }
  }

  /// Show user-friendly dialog with options
  static Future<void> showPaymentDialog(
    BuildContext context,
    SocialPayPaymentRequest request,
  ) async {
    final isInstalled = await isAppInstalled();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('SocialPay Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ₮${request.amount.toStringAsFixed(0)}'),
              Text('Description: ${request.description}'),
              Text('Invoice: ${request.invoiceId}'),
              SizedBox(height: 16),
              if (isInstalled)
                Text(
                  'SocialPay app is installed and ready to use.',
                  style: TextStyle(color: Colors.green),
                )
              else
                Text(
                  'SocialPay app is not installed. You will be redirected to the app store.',
                  style: TextStyle(color: Colors.orange),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                final result = await openApp(request);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: Text(isInstalled ? 'Pay with SocialPay' : 'Install SocialPay'),
            ),
          ],
        );
      },
    );
  }

  /// Quick utility method for QPay QR code integration
  static Future<SocialPayResult> payWithQRCode(
    String qrCode,
    double amount,
    String description,
    String invoiceId,
  ) async {
    final request = SocialPayPaymentRequest(
      amount: amount,
      description: description,
      invoiceId: invoiceId,
      qrCode: qrCode,
    );

    return await openApp(request);
  }

  /// Get app installation status and available schemes
  static Future<Map<String, dynamic>> getSystemInfo() async {
    final isInstalled = await isAppInstalled();
    final availableScheme = await _getAvailableScheme();
    
    final availableSchemes = <String>[];
    for (final scheme in _socialPaySchemes) {
      try {
        final uri = Uri.parse('${scheme}test');
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          availableSchemes.add(scheme);
        }
      } catch (error) {
        // Skip invalid schemes
      }
    }

    return {
      'isInstalled': isInstalled,
      'primaryScheme': availableScheme,
      'availableSchemes': availableSchemes,
      'platform': Platform.operatingSystem,
      'androidPackageIds': _androidPackageIds,
      'iosAppId': _iosAppId,
    };
  }

  /// Debug method to test all schemes and log results
  static Future<void> debugSchemeDetection() async {
    AppLogger.info('=== SocialPay Scheme Detection Debug ===');
    AppLogger.info('Platform: ${Platform.operatingSystem}');
    AppLogger.info('Testing ${_socialPaySchemes.length} schemes...');
    
    for (final scheme in _socialPaySchemes) {
      try {
        final uri = Uri.parse('${scheme}test');
        final canLaunch = await canLaunchUrl(uri);
        AppLogger.info('Scheme $scheme: ${canLaunch ? "AVAILABLE" : "NOT AVAILABLE"}');
      } catch (error) {
        AppLogger.error('Scheme $scheme: ERROR - $error');
      }
    }
    
    // Test package detection on Android
    if (Platform.isAndroid) {
      for (final packageId in _androidPackageIds) {
        try {
          final packageUri = Uri.parse('package:$packageId');
          final canLaunchPackage = await canLaunchUrl(packageUri);
          AppLogger.info('Package $packageId: ${canLaunchPackage ? "AVAILABLE" : "NOT AVAILABLE"}');
        } catch (error) {
          AppLogger.error('Package $packageId detection: ERROR - $error');
        }
      }
    }
    
    AppLogger.info('=== End Debug ===');
  }
}