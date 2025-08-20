/// QPay Configuration for Flutter
/// Centralized configuration management for QPay integration
library qpay_config;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// QPay configuration class
class QPayConfig {
  // Environment settings
  static String get mode => dotenv.env['QPAY_MODE'] ?? 'production';

  // QPay API URLs
  static String get productionUrl =>
      dotenv.env['QPAY_URL'] ?? 'https://merchant.qpay.mn/v2';

  static String get sandboxUrl =>
      dotenv.env['QPAY_TEST_URL'] ?? 'https://merchant-sandbox.qpay.mn/v2';

  // QPay Credentials
  static String get username => dotenv.env['QPAY_USERNAME'] ?? 'GRAND_IT';

  static String get password => dotenv.env['QPAY_PASSWORD'] ?? 'gY8ljnov';

  static String get template =>
      dotenv.env['QPAY_TEMPLATE'] ?? 'GRAND_IT_INVOICE';

  static String? get apiKey => dotenv.env['API_KEY'];

  // Server Configuration
  static int get serverPort {
    final portStr = dotenv.env['PORT'];
    return portStr != null ? int.tryParse(portStr) ?? 3000 : 3000;
  }

  static String get callbackUrl =>
      dotenv.env['QPAY_CALLBACK_URL'] ?? 'http://localhost:3000/qpay/callback';

  // Business Logic Constants
  static const int sessionTimeoutMs = 3000; // 3 seconds
  static const int checkIntervalMs = 3000; // Check every 3 minutes
  static const int maxDescriptionLength = 255;
  static const int maxInvoiceNoLength = 45;

  // QR Code Settings
  static const int qrCodeWidth = 300;
  static const int qrCodeMargin = 2;
  static const String qrCodeDarkColor = '#000000';
  static const String qrCodeLightColor = '#FFFFFF';

  // Get base URL based on mode
  static String get baseUrl {
    return mode == 'production' ? productionUrl : sandboxUrl;
  }

  // Get server base URL
  static String get serverBaseUrl {
    return 'http://localhost:$serverPort/api';
  }

  // Validation methods
  static bool get isProduction => mode == 'production';
  static bool get isSandbox => mode != 'production';

  static bool get hasValidCredentials {
    return username.isNotEmpty && password.isNotEmpty && template.isNotEmpty;
  }

  // Configuration summary for debugging
  static Map<String, dynamic> get summary {
    return {
      'mode': mode,
      'baseUrl': baseUrl,
      'serverBaseUrl': serverBaseUrl,
      'username': username,
      'template': template,
      'callbackUrl': callbackUrl,
      'sessionTimeoutMs': sessionTimeoutMs,
      'checkIntervalMs': checkIntervalMs,
      'hasValidCredentials': hasValidCredentials,
      'isProduction': isProduction,
    };
  }

  // Invoice configuration
  static const Duration defaultSessionTimeout = Duration(minutes: 3);
  static const Duration defaultCheckInterval = Duration(minutes: 3);
  static const Duration defaultExpirationTime = Duration(hours: 24);

  // HTTP timeouts
  static const Duration httpTimeout = Duration(seconds: 30);
  static const Duration httpConnectTimeout = Duration(seconds: 10);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Logging configuration
  static const bool enableDetailedLogging = bool.fromEnvironment(
    'QPAY_DETAILED_LOGGING',
    defaultValue: false,
  );

  // Currency settings (now using USD directly)
  static const String defaultCurrency = 'USD';
  static const String displayCurrency = 'USD';

  // File paths and storage
  static const String qrCodeStoragePath = 'qr_codes';
  static const String mockDataPath = 'mock.json';

  // Security settings
  static const String? webhookSecret = String.fromEnvironment(
    'QPAY_WEBHOOK_SECRET',
  );

  static bool get hasWebhookSecurity =>
      webhookSecret != null && webhookSecret!.isNotEmpty;

  // Feature flags
  static const bool enablePaymentMonitoring = bool.fromEnvironment(
    'ENABLE_PAYMENT_MONITORING',
    defaultValue: true,
  );

  static const bool enableMockPayments = bool.fromEnvironment(
    'ENABLE_MOCK_PAYMENTS',
    defaultValue: false,
  );

  static const bool enableBatchPayments = bool.fromEnvironment(
    'ENABLE_BATCH_PAYMENTS',
    defaultValue: true,
  );

  // Validation helpers
  static String? validateInvoiceDescription(String description) {
    if (description.isEmpty) {
      return 'Description cannot be empty';
    }
    if (description.length > maxDescriptionLength) {
      return 'Description too long (max $maxDescriptionLength characters)';
    }
    return null;
  }

  static String? validateInvoiceNumber(String invoiceNo) {
    if (invoiceNo.isEmpty) {
      return 'Invoice number cannot be empty';
    }
    if (invoiceNo.length > maxInvoiceNoLength) {
      return 'Invoice number too long (max $maxInvoiceNoLength characters)';
    }
    return null;
  }

  static String? validateAmount(double amount) {
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amount > 999999999) {
      return 'Amount too large';
    }
    return null;
  }
}
