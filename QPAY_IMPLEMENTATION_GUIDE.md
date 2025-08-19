# QPay Implementation Guide - Complete Integration Documentation

## Table of Contents
1. [Introduction & Overview](#introduction--overview)
2. [QPay vs Social Pay Differences](#qpay-vs-social-pay-differences)
3. [Environment Setup](#environment-setup)
4. [Configuration Files](#configuration-files)
5. [Flutter Implementation](#flutter-implementation)
6. [Deeplink Integration](#deeplink-integration)
7. [QR Code Generation](#qr-code-generation)
8. [Payment Flow Architecture](#payment-flow-architecture)
9. [Session Management](#session-management)
10. [Error Handling](#error-handling)
11. [Testing & Debugging](#testing--debugging)
12. [Prompt Engineering for AI Agents](#prompt-engineering-for-ai-agents)

## Introduction & Overview

QPay is Mongolia's leading digital payment platform that enables secure transactions through QR codes and deeplinks. This guide provides complete implementation details for integrating QPay into Flutter applications with comprehensive deeplink support.

### Key Features Implemented
- ✅ Invoice creation and management
- ✅ QR code generation with deeplinks
- ✅ Real-time payment monitoring
- ✅ Session management with timeouts
- ✅ Partial payment support
- ✅ Multi-bank deeplink integration
- ✅ Firebase integration for order tracking
- ✅ Comprehensive error handling
- ✅ Production and sandbox environments

## QPay vs Social Pay Differences

### QPay Characteristics
```
- Primary URL Scheme: qpay://
- Payment Flow: QR → Bank App → Confirmation
- Session Management: 3-minute timeout
- API Structure: RESTful with OAuth
- Bank Integration: Universal QR support
- Payment Status: Real-time polling required
```

### Social Pay Characteristics  
```
- Primary URL Scheme: socialpay:// or socialpay-payment://
- Payment Flow: Direct bank integration
- Session Management: Extended timeout (5+ minutes)
- API Structure: Bank-specific implementations
- Bank Integration: Khan Bank exclusive initially
- Payment Status: Webhook-based notifications
```

### Implementation Differences

**QPay Implementation:**
```dart
// QPay uses universal QR codes
final qrData = 'data:image/png;base64,${response.qr_image}';

// Deeplink format
final deeplink = 'qpay://payment?invoice=${invoiceId}&amount=${amount}';
```

**Social Pay Implementation:**
```dart
// Social Pay uses bank-specific links
final socialPayLink = 'socialpay-payment://pay?merchant=${merchantId}&amount=${amount}';

// Khan Bank specific
final khanBankLink = 'khanbank://payment?ref=${referenceId}';
```

## Environment Setup

### 1. Create Environment Configuration

Create `.env` file in project root:
```bash
# QPay Configuration
QPAY_MODE=production
QPAY_URL=https://merchant.qpay.mn/v2
QPAY_TEST_URL=https://merchant.qpay.mn/v2
QPAY_USERNAME=your_qpay_username
QPAY_PASSWORD=your_qpay_password
QPAY_TEMPLATE=your_invoice_template
QPAY_CALLBACK_URL=http://localhost:3000/qpay/callback

# Server Configuration
PORT=3000
API_KEY=your_api_key_here

# Feature Flags
ENABLE_PAYMENT_MONITORING=true
ENABLE_MOCK_PAYMENTS=false
QPAY_DETAILED_LOGGING=false
```

### 2. Flutter Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  flutter_dotenv: ^5.1.0
  url_launcher: ^6.2.1
  qr_flutter: ^4.1.0
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  provider: ^6.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2
```

## Configuration Files

### Android Configuration - AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet permission for API calls -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Camera permission for QR scanning -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <application
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:label="YourApp">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            
            <!-- Main launcher intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

    <!-- Banking app queries for deeplinks -->
    <queries>
        <!-- QPay and Social Pay packages -->
        <package android:name="mn.qpay.wallet" />
        <package android:name="com.qpay.wallet" />
        <package android:name="mn.socialpay" />
        <package android:name="com.khan.socialpay" />
        
        <!-- Major Mongolian banks -->
        <package android:name="mn.khan.bank" />
        <package android:name="com.khanbank.mobile" />
        <package android:name="mn.statebank" />
        <package android:name="mn.tdb.online" />
        <package android:name="mn.xac.bank" />
        <package android:name="mn.ub.bank" />
        <package android:name="mn.most.money" />
        <package android:name="mn.capitron.bank" />
        <package android:name="mn.bogd.bank" />
        <package android:name="mn.candy.pay" />
        
        <!-- Intent queries for banking schemes -->
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="qpay" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="socialpay" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="socialpay-payment" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="khanbank" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="statebank" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tdbbank" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="xacbank" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="most" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="candypay" />
        </intent>
    </queries>
</manifest>
```

### iOS Configuration - Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Bundle Configuration -->
    <key>CFBundleDisplayName</key>
    <string>YourApp</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    
    <!-- URL Schemes for Banking Apps -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <!-- Primary Payment Platforms -->
        <string>qpay</string>
        <string>qpay-wallet</string>
        <string>qpay-payment</string>
        <string>socialpay</string>
        <string>socialpay-payment</string>
        
        <!-- Khan Bank (Most Popular) -->
        <string>khanbank</string>
        <string>khanbank-mobile</string>
        <string>khanbank-payment</string>
        
        <!-- State Bank -->
        <string>statebank</string>
        <string>statebank-payment</string>
        
        <!-- Trade and Development Bank -->
        <string>tdbbank</string>
        <string>tdb-payment</string>
        
        <!-- XAC Bank -->
        <string>xacbank</string>
        
        <!-- Ulaanbaatar Bank -->
        <string>ubbank</string>
        
        <!-- Most Money -->
        <string>most</string>
        <string>mostmoney</string>
        
        <!-- National Investment Bank -->
        <string>nibank</string>
        
        <!-- Chinggis Khaan Bank -->
        <string>ckbank</string>
        
        <!-- Capitron Bank -->
        <string>capitronbank</string>
        
        <!-- Bogd Bank -->
        <string>bogdbank</string>
        
        <!-- Candy Pay -->
        <string>candypay</string>
        
        <!-- Golomt Bank -->
        <string>golomtbank</string>
        
        <!-- Arig Bank -->
        <string>arigbank</string>
        
        <!-- Trans Bank -->
        <string>transbank</string>
        
        <!-- M Bank -->
        <string>mbank</string>
        
        <!-- Credit Bank -->
        <string>creditbank</string>
        
        <!-- Mongol Bank -->
        <string>mongolbank</string>
        
        <!-- Development Bank -->
        <string>developmentbank</string>
    </array>
    
    <!-- Camera Permission for QR Scanning -->
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access to scan QR codes for payments.</string>
    
    <!-- Photo Library Permission -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app needs photo library access to save QR code images.</string>
    
    <!-- Internet Permission -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
```

## Flutter Implementation

### 1. QPay Configuration Class

```dart
// lib/config/qpay_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QPayConfig {
  // Environment settings
  static String get mode => dotenv.env['QPAY_MODE'] ?? 'production';
  
  // QPay API URLs
  static String get productionUrl => dotenv.env['QPAY_URL'] ?? 'https://merchant.qpay.mn/v2';
  static String get sandboxUrl => dotenv.env['QPAY_TEST_URL'] ?? 'https://merchant-sandbox.qpay.mn/v2';
  
  // QPay Credentials
  static String get username => dotenv.env['QPAY_USERNAME'] ?? '';
  static String get password => dotenv.env['QPAY_PASSWORD'] ?? '';
  static String get template => dotenv.env['QPAY_TEMPLATE'] ?? '';
  
  // Business Logic Constants
  static const int sessionTimeoutMs = 180000; // 3 minutes
  static const int checkIntervalMs = 180000; // Check every 3 minutes
  static const String defaultCurrency = 'USD';
  
  // Get base URL based on mode
  static String get baseUrl => mode == 'production' ? productionUrl : sandboxUrl;
  
  // Validation
  static bool get hasValidCredentials {
    return username.isNotEmpty && password.isNotEmpty && template.isNotEmpty;
  }
}
```

### 2. QPay Data Models

```dart
// lib/models/qpay_models.dart
class QPayInvoiceResult {
  final String invoiceId;
  final String qrImage; // Base64 encoded QR code
  final String urls; // Deeplink URLs for banks
  final String qPayShortUrl;
  
  QPayInvoiceResult({
    required this.invoiceId,
    required this.qrImage,
    required this.urls,
    required this.qPayShortUrl,
  });
  
  factory QPayInvoiceResult.fromJson(Map<String, dynamic> json) {
    return QPayInvoiceResult(
      invoiceId: json['invoice_id'] ?? '',
      qrImage: json['qr_image'] ?? '',
      urls: json['urls'] ?? '',
      qPayShortUrl: json['qpay_short_url'] ?? '',
    );
  }
}

class QPayPaymentStatus {
  final String status;
  final double paidAmount;
  final double remainingAmount;
  final String description;
  final DateTime? paidDate;
  
  QPayPaymentStatus({
    required this.status,
    required this.paidAmount,
    required this.remainingAmount,
    required this.description,
    this.paidDate,
  });
  
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isPartiallyPaid => paidAmount > 0 && remainingAmount > 0;
  
  factory QPayPaymentStatus.fromJson(Map<String, dynamic> json) {
    return QPayPaymentStatus(
      status: json['payment_status'] ?? 'pending',
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      remainingAmount: (json['remaining_amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      paidDate: json['paid_date'] != null 
        ? DateTime.parse(json['paid_date']) 
        : null,
    );
  }
}
```

### 3. QPay Service Implementation

```dart
// lib/services/qpay_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qpay_models.dart';
import '../config/qpay_config.dart';

class QPayService {
  static final QPayService _instance = QPayService._internal();
  factory QPayService() => _instance;
  QPayService._internal();

  String? _accessToken;
  DateTime? _tokenExpiration;
  final Map<String, Timer> _activeSessions = {};

  // Get access token with caching
  Future<String> _getAccessToken() async {
    if (_accessToken != null && 
        _tokenExpiration != null && 
        DateTime.now().isBefore(_tokenExpiration!)) {
      return _accessToken!;
    }

    final url = Uri.parse('${QPayConfig.baseUrl}/auth/token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': QPayConfig.username,
        'password': QPayConfig.password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      _tokenExpiration = DateTime.now().add(Duration(hours: 1));
      return _accessToken!;
    } else {
      throw Exception('Failed to get access token: ${response.statusCode}');
    }
  }

  // Create QPay invoice with Firebase integration
  Future<QPayInvoiceResult> createInvoice({
    required String orderId,
    required double amount,
    required String description,
    String currency = 'USD',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await _getAccessToken();
      final url = Uri.parse('${QPayConfig.baseUrl}/invoice');

      final requestBody = {
        'invoice_code': QPayConfig.template,
        'sender_invoice_no': orderId,
        'invoice_receiver_code': orderId,
        'invoice_description': description,
        'amount': amount,
        'currency': currency,
        'callback_url': QPayConfig.callbackUrl,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = QPayInvoiceResult.fromJson(data);
        
        // Store in Firebase for tracking
        await _storeInvoiceInFirebase(orderId, result, amount, metadata);
        
        // Start payment monitoring session
        _startPaymentMonitoring(result.invoiceId, orderId);
        
        return result;
      } else {
        throw Exception('Failed to create invoice: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error creating QPay invoice: $e');
      rethrow;
    }
  }

  // Store invoice data in Firebase
  Future<void> _storeInvoiceInFirebase(
    String orderId,
    QPayInvoiceResult invoice,
    double amount,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('qpay_orders').doc(orderId).set({
        'invoice_id': invoice.invoiceId,
        'amount': amount,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'qr_image': invoice.qrImage,
        'urls': invoice.urls,
        'short_url': invoice.qPayShortUrl,
        'metadata': metadata ?? {},
      });
    } catch (e) {
      print('Error storing invoice in Firebase: $e');
    }
  }

  // Check payment status
  Future<QPayPaymentStatus> checkPaymentStatus(String invoiceId) async {
    try {
      final token = await _getAccessToken();
      final url = Uri.parse('${QPayConfig.baseUrl}/invoice/$invoiceId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return QPayPaymentStatus.fromJson(data);
      } else {
        throw Exception('Failed to check payment status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking payment status: $e');
      rethrow;
    }
  }

  // Start payment monitoring session
  void _startPaymentMonitoring(String invoiceId, String orderId) {
    // Cancel existing session if any
    _cancelPaymentMonitoring(invoiceId);

    // Create new monitoring timer
    final timer = Timer.periodic(
      Duration(milliseconds: QPayConfig.checkIntervalMs),
      (timer) async {
        try {
          final status = await checkPaymentStatus(invoiceId);
          
          // Update Firebase with status
          await FirebaseFirestore.instance
            .collection('qpay_orders')
            .doc(orderId)
            .update({
              'status': status.status,
              'paid_amount': status.paidAmount,
              'remaining_amount': status.remainingAmount,
              'last_checked': FieldValue.serverTimestamp(),
            });

          // If payment is complete, stop monitoring
          if (status.isPaid) {
            _cancelPaymentMonitoring(invoiceId);
          }
        } catch (e) {
          print('Error during payment monitoring: $e');
        }
      },
    );

    _activeSessions[invoiceId] = timer;

    // Auto-cancel after session timeout
    Timer(Duration(milliseconds: QPayConfig.sessionTimeoutMs), () {
      _cancelPaymentMonitoring(invoiceId);
    });
  }

  // Cancel payment monitoring
  void _cancelPaymentMonitoring(String invoiceId) {
    final timer = _activeSessions.remove(invoiceId);
    timer?.cancel();
  }

  // Get all active monitoring sessions
  List<String> getActiveSessionInvoices() {
    return _activeSessions.keys.toList();
  }

  // Cancel all monitoring sessions
  void cancelAllSessions() {
    for (final timer in _activeSessions.values) {
      timer.cancel();
    }
    _activeSessions.clear();
  }

  // Get payment history from Firebase
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('qpay_orders')
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting payment history: $e');
      return [];
    }
  }

  // Dispose service and cleanup
  void dispose() {
    cancelAllSessions();
  }
}
```

## Deeplink Integration

### 1. URL Launcher Service

```dart
// lib/services/deeplink_service.dart
import 'package:url_launcher/url_launcher.dart';

class DeepLinkService {
  // Launch QPay deeplink
  static Future<bool> launchQPayDeeplink({
    required String invoiceId,
    required double amount,
    String? preferredBank,
  }) async {
    try {
      // Primary QPay URL
      final qpayUrl = 'qpay://payment?invoice=$invoiceId&amount=$amount';
      
      if (await canLaunchUrl(Uri.parse(qpayUrl))) {
        return await launchUrl(
          Uri.parse(qpayUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      // Fallback to specific bank apps
      return await _launchBankSpecificApp(invoiceId, amount, preferredBank);
    } catch (e) {
      print('Error launching QPay deeplink: $e');
      return false;
    }
  }

  // Launch bank-specific deeplinks
  static Future<bool> _launchBankSpecificApp(
    String invoiceId,
    double amount,
    String? preferredBank,
  ) async {
    final bankUrls = {
      'khanbank': 'khanbank://payment?invoice=$invoiceId&amount=$amount',
      'statebank': 'statebank://payment?invoice=$invoiceId&amount=$amount',
      'tdbbank': 'tdbbank://payment?invoice=$invoiceId&amount=$amount',
      'socialpay': 'socialpay-payment://pay?invoice=$invoiceId&amount=$amount',
    };

    // Try preferred bank first
    if (preferredBank != null && bankUrls.containsKey(preferredBank)) {
      final url = bankUrls[preferredBank]!;
      if (await canLaunchUrl(Uri.parse(url))) {
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    }

    // Try all banks in priority order
    final priorityBanks = ['khanbank', 'socialpay', 'statebank', 'tdbbank'];
    
    for (final bank in priorityBanks) {
      final url = bankUrls[bank]!;
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          return await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        continue; // Try next bank
      }
    }

    return false;
  }

  // Check which banking apps are available
  static Future<List<String>> getAvailableBankApps() async {
    final banks = ['khanbank', 'socialpay', 'statebank', 'tdbbank', 'qpay'];
    final available = <String>[];

    for (final bank in banks) {
      final url = '$bank://';
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          available.add(bank);
        }
      } catch (e) {
        continue;
      }
    }

    return available;
  }
}
```

### 2. Bank Selection Widget

```dart
// lib/widgets/bank_selection_widget.dart
import 'package:flutter/material.dart';
import '../services/deeplink_service.dart';

class BankSelectionWidget extends StatefulWidget {
  final String invoiceId;
  final double amount;
  final Function(bool success) onPaymentLaunched;

  const BankSelectionWidget({
    Key? key,
    required this.invoiceId,
    required this.amount,
    required this.onPaymentLaunched,
  }) : super(key: key);

  @override
  _BankSelectionWidgetState createState() => _BankSelectionWidgetState();
}

class _BankSelectionWidgetState extends State<BankSelectionWidget> {
  List<String> availableBanks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableBanks();
  }

  Future<void> _loadAvailableBanks() async {
    final banks = await DeepLinkService.getAvailableBankApps();
    setState(() {
      availableBanks = banks;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (availableBanks.isEmpty) {
      return Center(
        child: Text(
          'No banking apps found. Please install a supported banking app.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Text(
          'Select Banking App',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 16),
        ...availableBanks.map((bank) => BankTile(
          bankName: bank,
          onTap: () => _launchBankApp(bank),
        )),
      ],
    );
  }

  Future<void> _launchBankApp(String bank) async {
    final success = await DeepLinkService.launchQPayDeeplink(
      invoiceId: widget.invoiceId,
      amount: widget.amount,
      preferredBank: bank,
    );
    widget.onPaymentLaunched(success);
  }
}

class BankTile extends StatelessWidget {
  final String bankName;
  final VoidCallback onTap;

  const BankTile({
    Key? key,
    required this.bankName,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bankInfo = _getBankInfo(bankName);
    
    return Card(
      child: ListTile(
        leading: Icon(
          bankInfo['icon'],
          color: bankInfo['color'],
          size: 32,
        ),
        title: Text(bankInfo['displayName']),
        subtitle: Text(bankInfo['description']),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Map<String, dynamic> _getBankInfo(String bankName) {
    final bankInfoMap = {
      'khanbank': {
        'displayName': 'Khan Bank',
        'description': 'Mongolia\'s largest commercial bank',
        'icon': Icons.account_balance,
        'color': Colors.blue,
      },
      'socialpay': {
        'displayName': 'Social Pay',
        'description': 'Digital payment platform',
        'icon': Icons.payment,
        'color': Colors.green,
      },
      'statebank': {
        'displayName': 'State Bank',
        'description': 'State-owned commercial bank',
        'icon': Icons.account_balance,
        'color': Colors.red,
      },
      'tdbbank': {
        'displayName': 'TDB Bank',
        'description': 'Trade and Development Bank',
        'icon': Icons.account_balance,
        'color': Colors.orange,
      },
      'qpay': {
        'displayName': 'QPay',
        'description': 'Universal payment platform',
        'icon': Icons.qr_code,
        'color': Colors.purple,
      },
    };

    return bankInfoMap[bankName] ?? {
      'displayName': bankName.toUpperCase(),
      'description': 'Banking application',
      'icon': Icons.account_balance,
      'color': Colors.grey,
    };
  }
}
```

## QR Code Generation

### 1. QR Code Display Widget

```dart
// lib/widgets/qr_code_widget.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeWidget extends StatelessWidget {
  final String qrImageData; // Base64 encoded image from QPay
  final String invoiceId;
  final double amount;
  final VoidCallback? onTap;

  const QRCodeWidget({
    Key? key,
    required this.qrImageData,
    required this.invoiceId,
    required this.amount,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Scan to Pay',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: onTap,
              child: _buildQRCode(),
            ),
            SizedBox(height: 16),
            Text(
              'Amount: \$${amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Invoice: $invoiceId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 8),
            Text(
              'Tap QR code to open payment app',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCode() {
    try {
      // Remove data URL prefix if present
      String base64Data = qrImageData;
      if (base64Data.startsWith('data:image')) {
        base64Data = base64Data.split(',')[1];
      }

      final bytes = base64Decode(base64Data);
      
      return Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to generated QR code if image fails
              return _buildFallbackQR();
            },
          ),
        ),
      );
    } catch (e) {
      print('Error displaying QR code image: $e');
      return _buildFallbackQR();
    }
  }

  Widget _buildFallbackQR() {
    // Generate QR code with payment URL
    final paymentUrl = 'qpay://payment?invoice=$invoiceId&amount=$amount';
    
    return QrImageView(
      data: paymentUrl,
      version: QrVersions.auto,
      size: 250,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      padding: EdgeInsets.all(8),
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }
}
```

### 2. Payment Screen Implementation

```dart
// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/qpay_service.dart';
import '../services/deeplink_service.dart';
import '../widgets/qr_code_widget.dart';
import '../widgets/bank_selection_widget.dart';
import '../models/qpay_models.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String description;
  final String orderId;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.description,
    required this.orderId,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  QPayInvoiceResult? invoice;
  QPayPaymentStatus? paymentStatus;
  bool isLoading = false;
  bool isMonitoring = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _createInvoice();
  }

  Future<void> _createInvoice() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final qpayService = QPayService();
      final result = await qpayService.createInvoice(
        orderId: widget.orderId,
        amount: widget.amount,
        description: widget.description,
      );

      setState(() {
        invoice = result;
        isLoading = false;
        isMonitoring = true;
      });

      _startPaymentStatusMonitoring();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _startPaymentStatusMonitoring() {
    // Monitor payment status in real-time
    if (invoice != null) {
      _checkPaymentStatus();
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (invoice == null) return;

    try {
      final status = await QPayService().checkPaymentStatus(invoice!.invoiceId);
      setState(() {
        paymentStatus = status;
      });

      if (status.isPaid) {
        _onPaymentSuccess();
      } else if (status.isPartiallyPaid) {
        _onPartialPayment(status);
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }
  }

  void _onPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Payment Successful'),
        content: Text('Your payment has been processed successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to previous screen
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onPartialPayment(QPayPaymentStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Partial Payment Received'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paid: \$${status.paidAmount.toStringAsFixed(2)}'),
            Text('Remaining: \$${status.remainingAmount.toStringAsFixed(2)}'),
            SizedBox(height: 8),
            Text('You can continue to pay the remaining amount.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating payment invoice...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text('Error creating payment:', style: TextStyle(fontSize: 16)),
            Text(error!, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createInvoice,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (invoice == null) {
      return Center(child: Text('No invoice data available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Payment Status
          if (paymentStatus != null) _buildPaymentStatus(),
          
          // QR Code
          QRCodeWidget(
            qrImageData: invoice!.qrImage,
            invoiceId: invoice!.invoiceId,
            amount: widget.amount,
            onTap: () => _launchDeeplink(),
          ),
          
          SizedBox(height: 24),
          
          // Bank Selection
          BankSelectionWidget(
            invoiceId: invoice!.invoiceId,
            amount: widget.amount,
            onPaymentLaunched: (success) {
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open banking app'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          
          SizedBox(height: 24),
          
          // Manual refresh button
          ElevatedButton.icon(
            onPressed: _checkPaymentStatus,
            icon: Icon(Icons.refresh),
            label: Text('Check Payment Status'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    if (paymentStatus == null) return SizedBox.shrink();

    Color statusColor = Colors.orange;
    String statusText = 'Pending Payment';
    
    if (paymentStatus!.isPaid) {
      statusColor = Colors.green;
      statusText = 'Payment Complete';
    } else if (paymentStatus!.isPartiallyPaid) {
      statusColor = Colors.blue;
      statusText = 'Partially Paid';
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info, color: statusColor),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (paymentStatus!.isPartiallyPaid)
                    Text(
                      'Paid: \$${paymentStatus!.paidAmount.toStringAsFixed(2)} / \$${widget.amount.toStringAsFixed(2)}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDeeplink() async {
    if (invoice != null) {
      await DeepLinkService.launchQPayDeeplink(
        invoiceId: invoice!.invoiceId,
        amount: widget.amount,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

## Payment Flow Architecture

### Flow Diagram
```
User Initiates Payment
         ↓
Create QPay Invoice (API Call)
         ↓
Store in Firebase + Start Session Monitoring
         ↓
Display QR Code + Bank Selection
         ↓
User Scans QR or Taps Deeplink
         ↓
Banking App Opens → User Completes Payment
         ↓
QPay Webhook/Polling Updates Status
         ↓
Firebase Updated → App Notified
         ↓
Payment Success/Partial/Failed
```

### Session Management Strategy

1. **Session Creation**: 3-minute active monitoring window
2. **Status Polling**: Check every 3 minutes for payment updates
3. **Firebase Sync**: Real-time status updates across devices
4. **Auto Cleanup**: Sessions expire automatically to prevent resource leaks
5. **Error Recovery**: Retry logic for failed API calls

## Session Management

### Advanced Session Handling

```dart
// lib/services/session_manager.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final Map<String, PaymentSession> _activeSessions = {};
  late StreamSubscription<QuerySnapshot> _firestoreListener;

  void initialize() {
    _startFirestoreListener();
  }

  void _startFirestoreListener() {
    _firestoreListener = FirebaseFirestore.instance
        .collection('qpay_orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(_handleFirestoreUpdates);
  }

  void _handleFirestoreUpdates(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.modified) {
        final data = change.doc.data() as Map<String, dynamic>;
        final orderId = change.doc.id;
        final status = data['status'] as String;

        if (status != 'pending') {
          _completeSession(orderId, status);
        }
      }
    }
  }

  void _completeSession(String orderId, String status) {
    final session = _activeSessions.remove(orderId);
    session?.complete(status);
  }

  Future<PaymentSession> createSession({
    required String orderId,
    required String invoiceId,
    required double amount,
  }) async {
    final session = PaymentSession(
      orderId: orderId,
      invoiceId: invoiceId,
      amount: amount,
    );

    _activeSessions[orderId] = session;
    
    // Auto-cleanup after timeout
    Timer(Duration(minutes: 5), () {
      final existingSession = _activeSessions.remove(orderId);
      existingSession?.timeout();
    });

    return session;
  }

  void dispose() {
    _firestoreListener.cancel();
    for (final session in _activeSessions.values) {
      session.cancel();
    }
    _activeSessions.clear();
  }
}

class PaymentSession {
  final String orderId;
  final String invoiceId;
  final double amount;
  final DateTime createdAt;
  final Completer<String> _completer = Completer<String>();

  PaymentSession({
    required this.orderId,
    required this.invoiceId,
    required this.amount,
  }) : createdAt = DateTime.now();

  Future<String> get result => _completer.future;

  void complete(String status) {
    if (!_completer.isCompleted) {
      _completer.complete(status);
    }
  }

  void timeout() {
    if (!_completer.isCompleted) {
      _completer.complete('timeout');
    }
  }

  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete('cancelled');
    }
  }

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 3;
}
```

## Error Handling

### Comprehensive Error Management

```dart
// lib/utils/qpay_errors.dart
enum QPayErrorType {
  networkError,
  authenticationError,
  invalidCredentials,
  invoiceCreationFailed,
  paymentStatusCheckFailed,
  sessionTimeout,
  deeplinkFailed,
  firebaseError,
  unknownError,
}

class QPayException implements Exception {
  final QPayErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;

  QPayException({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'QPayException: $message (Type: $type)';

  String get userFriendlyMessage {
    switch (type) {
      case QPayErrorType.networkError:
        return 'Network connection error. Please check your internet connection.';
      case QPayErrorType.authenticationError:
        return 'Authentication failed. Please contact support.';
      case QPayErrorType.invalidCredentials:
        return 'Invalid QPay credentials. Please check configuration.';
      case QPayErrorType.invoiceCreationFailed:
        return 'Failed to create payment invoice. Please try again.';
      case QPayErrorType.paymentStatusCheckFailed:
        return 'Could not check payment status. Please refresh manually.';
      case QPayErrorType.sessionTimeout:
        return 'Payment session has expired. Please create a new payment.';
      case QPayErrorType.deeplinkFailed:
        return 'Could not open banking app. Please scan QR code manually.';
      case QPayErrorType.firebaseError:
        return 'Database sync error. Your payment may still be processing.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

// Error handler utility
class QPayErrorHandler {
  static QPayException handleError(dynamic error) {
    if (error is QPayException) {
      return error;
    }

    if (error.toString().contains('SocketException')) {
      return QPayException(
        type: QPayErrorType.networkError,
        message: 'Network connection failed',
        originalError: error,
      );
    }

    if (error.toString().contains('401') || error.toString().contains('403')) {
      return QPayException(
        type: QPayErrorType.authenticationError,
        message: 'Authentication failed',
        originalError: error,
      );
    }

    return QPayException(
      type: QPayErrorType.unknownError,
      message: error.toString(),
      originalError: error,
    );
  }

  static void logError(QPayException error) {
    print('QPay Error: ${error.type} - ${error.message}');
    if (error.originalError != null) {
      print('Original Error: ${error.originalError}');
    }
  }
}
```

## Testing & Debugging

### Mock QPay Service for Testing

```dart
// lib/services/mock_qpay_service.dart
import '../models/qpay_models.dart';

class MockQPayService {
  static const bool enableMocks = bool.fromEnvironment('ENABLE_QPAY_MOCKS');

  static Future<QPayInvoiceResult> createMockInvoice({
    required String orderId,
    required double amount,
    required String description,
  }) async {
    // Simulate API delay
    await Future.delayed(Duration(seconds: 2));

    return QPayInvoiceResult(
      invoiceId: 'MOCK_${DateTime.now().millisecondsSinceEpoch}',
      qrImage: _generateMockQRBase64(),
      urls: 'qpay://payment?mock=true&amount=$amount',
      qPayShortUrl: 'https://qpay.mn/mock/$orderId',
    );
  }

  static Future<QPayPaymentStatus> getMockPaymentStatus(String invoiceId) async {
    await Future.delayed(Duration(milliseconds: 500));

    // Simulate different payment states for testing
    final random = DateTime.now().millisecond % 100;
    
    if (random < 30) {
      // 30% chance of being paid
      return QPayPaymentStatus(
        status: 'paid',
        paidAmount: 100.0,
        remainingAmount: 0.0,
        description: 'Payment completed successfully',
        paidDate: DateTime.now(),
      );
    } else if (random < 50) {
      // 20% chance of partial payment
      return QPayPaymentStatus(
        status: 'partial',
        paidAmount: 60.0,
        remainingAmount: 40.0,
        description: 'Partial payment received',
      );
    } else {
      // 50% chance still pending
      return QPayPaymentStatus(
        status: 'pending',
        paidAmount: 0.0,
        remainingAmount: 100.0,
        description: 'Waiting for payment',
      );
    }
  }

  static String _generateMockQRBase64() {
    // Returns a simple base64 encoded 1x1 pixel PNG for testing
    return 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
  }
}
```

### Debug Widget for Development

```dart
// lib/widgets/debug_payment_widget.dart
import 'package:flutter/material.dart';

class DebugPaymentWidget extends StatelessWidget {
  final String? invoiceId;
  final Map<String, dynamic>? paymentData;

  const DebugPaymentWidget({
    Key? key,
    this.invoiceId,
    this.paymentData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    assert(() {
      return true;
    }());
    
    return Card(
      color: Colors.yellow[100],
      child: ExpansionTile(
        title: Text('Debug Info'),
        leading: Icon(Icons.bug_report),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (invoiceId != null)
                  Text('Invoice ID: $invoiceId'),
                if (paymentData != null)
                  ...paymentData!.entries.map((entry) =>
                    Text('${entry.key}: ${entry.value}')),
                SizedBox(height: 8),
                Text(
                  'Environment: ${const bool.fromEnvironment('dart.vm.product') ? 'Production' : 'Debug'}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Prompt Engineering for AI Agents

### AI Agent Context Prompt

When working with AI agents on this QPay integration, use this comprehensive prompt:

```markdown
# QPay Integration Context for AI Agents

## System Overview
This Flutter application implements QPay payment integration for Mongolian banking system with the following architecture:

### Core Components
- **QPayService**: Handles API communication, session management, and Firebase integration
- **DeepLinkService**: Manages banking app deeplinks and URL schemes  
- **SessionManager**: Monitors payment status and handles real-time updates
- **QPayConfig**: Centralized configuration management

### Payment Flow
1. User initiates payment → createInvoice() called
2. QPay API returns QR code and deeplinks → stored in Firebase
3. User scans QR or taps deeplink → banking app opens
4. Payment completed in bank app → status updated via polling/webhook
5. Firebase syncs status → app updates UI → session cleanup

### Key Technical Details
- **Session Timeout**: 3 minutes for active monitoring
- **Status Polling**: Every 3 minutes until payment complete
- **Partial Payments**: Supported with remaining amount tracking
- **Currency**: USD used throughout system
- **Deeplink Priority**: qpay:// → khanbank:// → socialpay:// → other banks

### Critical Implementation Notes
- **Banking App URLs**: Configured in AndroidManifest.xml (Android) and Info.plist (iOS)
- **Firebase Integration**: Real-time payment tracking in 'qpay_orders' collection
- **Error Handling**: Comprehensive QPayException with user-friendly messages
- **Environment**: Production vs Sandbox modes supported

### Social Pay vs QPay Differences
- **QPay**: Universal QR codes, 3-min sessions, RESTful API, polling-based status
- **Social Pay**: Bank-specific links, 5+ min sessions, webhook notifications, Khan Bank focus

### Configuration Requirements
- QPAY_USERNAME, QPAY_PASSWORD, QPAY_TEMPLATE in .env file
- AndroidManifest.xml must include banking app queries and intent filters
- Info.plist must include LSApplicationQueriesSchemes with bank URL schemes
- Firebase project configured for real-time database updates

### When Debugging Issues
1. Check .env file for valid QPay credentials
2. Verify AndroidManifest.xml/Info.plist have banking URL schemes
3. Confirm Firebase connection and 'qpay_orders' collection exists
4. Test deeplinks with url_launcher canLaunchUrl()
5. Check QPay API response format matches QPayInvoiceResult model

### Common Error Patterns
- "Connection refused" = Check QPay credentials and network
- "Banking app not opening" = Missing URL scheme configuration
- "Status not updating" = Firebase sync or session management issue
- "QR code not displaying" = Base64 image decoding problem

Use this context when analyzing QPay-related code or implementing new features.
```

### Debugging Prompt Template

```markdown
# QPay Debugging Assistant Prompt

I'm working on a QPay payment integration issue. Here's the context:

**Error Type**: [Connection/Authentication/Deeplink/UI/Other]
**Environment**: [Production/Sandbox]
**Platform**: [Android/iOS/Both]
**Error Message**: [Exact error text]

**What I'm trying to do**:
[Describe the specific functionality]

**What's happening instead**:
[Describe the actual behavior]

**Code involved**:
[Paste relevant code snippets]

**Additional context**:
- QPay credentials: [Valid/Invalid/Not sure]
- Firebase connection: [Working/Not working/Not sure]  
- Banking apps installed: [List available apps]
- URL schemes configured: [Yes/No/Not sure]

Based on the QPay implementation guide, please:
1. Identify the most likely cause
2. Provide specific debugging steps
3. Suggest code fixes if needed
4. Recommend prevention strategies

Focus on the QPay-specific architecture and Mongolian banking integration requirements.
```

### Feature Development Prompt

```markdown
# QPay Feature Development Assistant

I need to implement a new QPay-related feature with these requirements:

**Feature Description**: [Detailed description]
**Integration Points**: [Which existing services/components to use]
**User Experience**: [Expected user interaction flow]
**Technical Requirements**: [Performance, security, compatibility needs]

**Existing QPay Architecture to Consider**:
- QPayService for API communication
- DeepLinkService for banking app integration  
- SessionManager for payment monitoring
- Firebase for real-time status updates
- QPayConfig for environment management

**Constraints**:
- Must support partial payments
- Session timeout: 3 minutes
- Multi-bank deeplink compatibility
- Production and sandbox environments

Please provide:
1. **Architecture Plan**: How feature fits into existing structure
2. **Implementation Steps**: Detailed coding approach
3. **Configuration Changes**: Updates needed for AndroidManifest.xml/Info.plist
4. **Testing Strategy**: How to validate functionality
5. **Error Handling**: Expected failure modes and recovery

Consider Social Pay differences and Mongolian banking system requirements.
```

---

## Conclusion

This comprehensive guide covers complete QPay integration with:

✅ **Full Flutter Implementation** - Service architecture, models, and UI components
✅ **Deeplink Integration** - Multi-bank support with priority fallback system  
✅ **QR Code Generation** - Base64 image handling with fallback generation
✅ **Session Management** - Real-time monitoring with Firebase integration
✅ **Configuration Files** - Android and iOS setup for banking app support
✅ **Error Handling** - Comprehensive exception management with user-friendly messages
✅ **Testing Framework** - Mock services and debugging utilities
✅ **Prompt Engineering** - AI agent context for future development

### Quick Start Checklist

1. ✅ Copy configuration files (AndroidManifest.xml, Info.plist)
2. ✅ Add Flutter dependencies to pubspec.yaml  
3. ✅ Create .env file with QPay credentials
4. ✅ Implement service classes (QPayService, DeepLinkService)
5. ✅ Configure Firebase for payment tracking
6. ✅ Test deeplinks with banking apps
7. ✅ Validate QR code generation and display

**For Social Pay Integration**: Use similar architecture but replace QPay-specific URLs with `socialpay://` and `socialpay-payment://` schemes, extend session timeouts, and implement webhook-based status updates instead of polling.

This guide provides everything needed for production-ready QPay integration in Flutter applications with comprehensive Mongolian banking system support.
