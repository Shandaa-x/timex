# QPay & Deeplink Integration Guide

> Complete guide for integrating QPay payment system with deeplink support for Mongolian banking apps

## Table of Contents

1. [Overview](#overview)
2. [QPay Architecture](#qpay-architecture)
3. [Deeplink Configuration](#deeplink-configuration)
4. [QPay vs SocialPay Integration](#qpay-vs-socialpay-integration)
5. [Implementation Guide](#implementation-guide)
6. [Supported Banks & Apps](#supported-banks--apps)
7. [Testing & Validation](#testing--validation)
8. [Troubleshooting](#troubleshooting)

## Overview

QPay is Mongolia's leading digital payment platform that enables QR code-based payments integrated with major Mongolian banks. This guide covers the complete implementation of QPay with deeplink support, allowing users to pay directly through their preferred banking applications.

### Key Features

- **Multi-bank Integration**: Supports 12+ major Mongolian banks
- **Deeplink Support**: Direct app-to-app payment flow
- **QR Code Generation**: Automatic QR code creation for payments
- **Real-time Payment Monitoring**: Webhook-based payment verification
- **Cross-platform**: Works on Android and iOS
- **International Support**: Cross-border payments via GLN network (2024)

## QPay Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │───▶│  QPay Service   │───▶│  QPay API       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └─────────────▶│ Deeplink Utils  │              │
                        └─────────────────┘              │
                                 │                       │
                        ┌─────────────────┐              │
                        │  Banking Apps   │◀─────────────┘
                        └─────────────────┘
```

### File Structure

```
lib/
├── config/
│   └── qpay_config.dart           # Configuration management
├── models/
│   └── qpay_models.dart           # Data models and DTOs
├── services/
│   ├── qpay_helper.dart           # Core QPay API interactions
│   ├── qpay_service.dart          # High-level service layer
│   └── qpay_webhook_service.dart  # Webhook handling
├── utils/
│   ├── qr_utils.dart              # QR code utilities
│   ├── banking_app_checker.dart   # Bank app detection
│   └── socialpay_integration.dart # SocialPay specific handling
└── screens/
    ├── qpay/
    │   └── qr_code_screen.dart    # Payment UI
    └── payment/
        └── payment_screen.dart    # Payment flow
```

## Deeplink Configuration

### 1. Android Configuration (`android/app/src/main/AndroidManifest.xml`)

```xml
<queries>
    <!-- Banking app queries for deep linking -->
    <package android:name="mn.khan.bank" />
    <package android:name="com.khanbank.mobile" />
    <package android:name="mn.qpay.wallet" />
    <package android:name="mn.socialpay" />
    <package android:name="com.khan.socialpay" />
    <package android:name="mn.statebank" />
    <package android:name="mn.tdb.online" />
    <package android:name="mn.xac.bank" />
    <package android:name="mn.most.money" />
    <package android:name="mn.capitron.bank" />
    <package android:name="mn.bogd.bank" />
    <package android:name="mn.candy.pay" />
    
    <!-- Query for banking schemes -->
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="qpay" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="khanbank" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="socialpay" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="socialpay-payment" />
    </intent>
    <!-- Additional bank schemes... -->
</queries>
```

### 2. iOS Configuration (`ios/Runner/Info.plist`)

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>qpay</string>
    <string>khanbank</string>
    <string>khanbankapp</string>
    <string>socialpay</string>
    <string>socialpay-payment</string>
    <string>statebank</string>
    <string>statebankapp</string>
    <string>tdbbank</string>
    <string>tdb</string>
    <string>xacbank</string>
    <string>xac</string>
    <string>most</string>
    <string>mostmoney</string>
    <string>capitronbank</string>
    <string>capitron</string>
    <string>bogdbank</string>
    <string>bogd</string>
    <string>candypay</string>
    <string>candy</string>
</array>
```

### 3. Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  url_launcher: ^6.2.1
  flutter_dotenv: ^5.1.0
  qr_flutter: ^4.1.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## QPay vs SocialPay Integration

### Key Differences

| Aspect | QPay | SocialPay |
|--------|------|-----------|
| **Operator** | Multiple banks consortium | Golomt Bank |
| **Launch Year** | 2019 | 2017 |
| **Coverage** | 12+ partner banks | Single bank focus |
| **Deeplink Format** | `qpay://q?qPay_QRcode=...` | `socialpay-payment://q?qPay_QRcode=...` |
| **International** | GLN network support (2024) | Limited international |
| **Integration Complexity** | Multi-bank coordination | Single bank API |

### SocialPay Specific Implementation

```dart
class SocialPayIntegration {
  /// Primary SocialPay deeplink format (2024)
  static String? getSocialPayDeepLink({
    required String qrText,
    required String invoiceId,
  }) {
    try {
      final encodedQR = Uri.encodeComponent(qrText);
      return 'socialpay-payment://q?qPay_QRcode=$encodedQR';
    } catch (error) {
      return null;
    }
  }

  /// Alternative format for older versions
  static String? getAlternativeSocialPayDeepLink({
    required String qrText,
    required String invoiceId,
  }) {
    try {
      final encodedQR = Uri.encodeComponent(qrText);
      return 'socialpay://qpay?qr=$encodedQR';
    } catch (error) {
      return null;
    }
  }
}
```

### QPay General Deeplink Pattern

```dart
class QRUtils {
  static Map<String, String> generateDeepLinks(String qrText) {
    final encodedQR = Uri.encodeComponent(qrText);
    
    return {
      'khanbank': 'khanbank://q?qPay_QRcode=$encodedQR',
      'statebank': 'statebank://q?qPay_QRcode=$encodedQR',
      'xacbank': 'xacbank://q?qPay_QRcode=$encodedQR',
      'tdbbank': 'tdbbank://q?qPay_QRcode=$encodedQR',
      'socialpay': 'socialpay-payment://q?qPay_QRcode=$encodedQR',
      'mostmoney': 'most://q?qPay_QRcode=$encodedQR',
      'capitronbank': 'capitronbank://q?qPay_QRcode=$encodedQR',
      'bogdbank': 'bogdbank://q?qPay_QRcode=$encodedQR',
      'candypay': 'candypay://q?qPay_QRcode=$encodedQR',
    };
  }
}
```

## Implementation Guide

### 1. Environment Configuration

Create `.env` file:

```bash
# QPay Configuration
QPAY_MODE=sandbox
QPAY_USERNAME=your_username
QPAY_PASSWORD=your_password
QPAY_TEMPLATE=your_template
QPAY_URL=https://merchant.qpay.mn/v2
QPAY_TEST_URL=https://merchant-sandbox.qpay.mn/v2
QPAY_CALLBACK_URL=https://your-domain.com/qpay/callback

# Server Configuration
PORT=3000
API_KEY=your_api_key
```

### 2. QPay Service Implementation

```dart
class QPayHelper {
  static Future<QPayInvoiceResult> createInvoiceWithQR(
    List<QPayProduct> products,
    String orderId,
    String userId, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      // 1. Get access token
      final String token = await ensureAuthenticated();
      
      // 2. Create invoice
      final Map<String, dynamic> invoiceResult = await createInvoice(
        token,
        products,
        orderId,
        userId,
        options: options,
      );
      
      if (invoiceResult['success'] != true) {
        throw Exception('Invoice creation failed');
      }
      
      // 3. Return complete result with QR data
      return QPayInvoiceResult(
        success: true,
        invoiceId: invoiceResult['invoice_id'],
        qrText: invoiceResult['qr_text'],
        bankUrls: List<String>.from(invoiceResult['urls'] ?? []),
        amount: invoiceResult['total_amount']?.toDouble() ?? 0.0,
        products: products.map((p) => p.toJson()).toList(),
        orderId: orderId,
        accessToken: token,
      );
    } catch (error) {
      return QPayInvoiceResult.error(error.toString());
    }
  }
}
```

### 3. Bank App Detection

```dart
class BankingAppChecker {
  static const Map<String, String> bankSchemes = {
    'Khan Bank': 'khanbank://',
    'State Bank': 'statebank://',
    'XAC Bank': 'xacbank://',
    'TDB Bank': 'tdbbank://',
    'Social Pay': 'socialpay://',
    'Social Pay Payment': 'socialpay-payment://',
    'Most Money': 'mostmoney://',
    'Capitron Bank': 'capitronbank://',
    'Bogd Bank': 'bogdbank://',
    'Candy Pay': 'candypay://',
  };

  static Future<List<String>> getAvailableBanks() async {
    final List<String> availableBanks = [];
    
    for (final entry in bankSchemes.entries) {
      final scheme = entry.value;
      if (await canLaunchUrl(Uri.parse(scheme))) {
        availableBanks.add(entry.key);
      }
    }
    
    return availableBanks;
  }

  static Future<bool> openBankApp(String bankName, String qrText) async {
    final scheme = bankSchemes[bankName];
    if (scheme == null) return false;
    
    final encodedQR = Uri.encodeComponent(qrText);
    final deepLink = '$scheme/q?qPay_QRcode=$encodedQR';
    
    return await launchUrl(Uri.parse(deepLink));
  }
}
```

### 4. Payment UI Integration

```dart
class QRCodeScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // QR Code Display
          QrImage(
            data: _qrText,
            version: QrVersions.auto,
            size: 200.0,
          ),
          
          // Bank Selection Buttons
          ...availableBanks.map((bank) => ElevatedButton(
            onPressed: () => _openBankApp(bank),
            child: Text('Pay with $bank'),
          )),
          
          // SocialPay Integration Button
          if (availableBanks.contains('Social Pay'))
            ElevatedButton(
              onPressed: _openSocialPay,
              child: Text('Pay with SocialPay'),
            ),
        ],
      ),
    );
  }

  Future<void> _openSocialPay() async {
    final socialPayLink = SocialPayIntegration.getSocialPayDeepLink(
      qrText: _qrText,
      invoiceId: _invoiceId,
    );
    
    if (socialPayLink != null) {
      final uri = Uri.parse(socialPayLink);
      if (await launchUrl(uri)) {
        _showMessage('Opened SocialPay', isError: false);
      } else {
        // Try alternative format
        final altLink = SocialPayIntegration.getAlternativeSocialPayDeepLink(
          qrText: _qrText,
          invoiceId: _invoiceId,
        );
        if (altLink != null) {
          await launchUrl(Uri.parse(altLink));
        }
      }
    }
  }
}
```

## Supported Banks & Apps

### Major Mongolian Banks (2024)

| Bank | Package Name | Deeplink Scheme | Status |
|------|-------------|----------------|--------|
| **Khan Bank** | `mn.khan.bank` | `khanbank://` | ✅ Active |
| **State Bank** | `mn.statebank` | `statebank://` | ✅ Active |
| **XAC Bank** | `mn.xac.bank` | `xacbank://` | ✅ Active |
| **TDB Bank** | `mn.tdb.online` | `tdbbank://` | ✅ Active |
| **SocialPay (Golomt)** | `mn.socialpay` | `socialpay-payment://` | ✅ Active |
| **Most Money** | `mn.most.money` | `mostmoney://` | ✅ Active |
| **Capitron Bank** | `mn.capitron.bank` | `capitronbank://` | ✅ Active |
| **Bogd Bank** | `mn.bogd.bank` | `bogdbank://` | ✅ Active |
| **Candy Pay** | `mn.candy.pay` | `candypay://` | ✅ Active |
| **UB Bank** | `mn.ub.bank` | `ulaanbaatarbank://` | ✅ Active |
| **Chinggis Khaan Bank** | `mn.ckbank` | `chinggisnbank://` | ✅ Active |
| **NIBank** | `mn.nibank` | `nibank://` | ✅ Active |

### Deeplink URL Formats

#### Standard QPay Format
```
{bank_scheme}://q?qPay_QRcode={encoded_qr_text}
```

#### SocialPay Specific Formats
```bash
# Primary format (2024)
socialpay-payment://q?qPay_QRcode={encoded_qr_text}

# Alternative format (legacy)
socialpay://qpay?qr={encoded_qr_text}
```

## Testing & Validation

### 1. Deeplink Testing

```dart
class DeeplinkTester {
  static Future<void> testAllBanks(String qrText) async {
    final deepLinks = QRUtils.generateDeepLinks(qrText);
    
    for (final entry in deepLinks.entries) {
      final bankName = entry.key;
      final deepLink = entry.value;
      
      print('Testing $bankName: $deepLink');
      
      try {
        final uri = Uri.parse(deepLink);
        final canLaunch = await canLaunchUrl(uri);
        print('$bankName - Can launch: $canLaunch');
        
        if (canLaunch) {
          // Test launching (be careful in production)
          // await launchUrl(uri);
        }
      } catch (error) {
        print('$bankName - Error: $error');
      }
    }
  }
}
```

### 2. Payment Flow Testing

```bash
# Test invoice creation
curl -X POST "https://merchant-sandbox.qpay.mn/v2/invoice" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "invoice_code": "YOUR_TEMPLATE",
    "sender_invoice_no": "TEST_001",
    "invoice_receiver_code": "terminal",
    "invoice_description": "Test Payment",
    "amount": 1000,
    "callback_url": "https://your-domain.com/qpay/callback"
  }'
```

### 3. Device Compatibility

```dart
// Check device support
Future<Map<String, bool>> checkDeviceSupport() async {
  return {
    'Android 6.0+': Platform.isAndroid,
    'iOS 12.0+': Platform.isIOS,
    'Deeplink Support': await canLaunchUrl(Uri.parse('khanbank://')),
    'URL Launcher': true,
  };
}
```

## Troubleshooting

### Common Issues

#### 1. Deeplink Not Opening
```dart
// Solution: Check app installation and scheme registration
if (!await canLaunchUrl(Uri.parse(deepLink))) {
  // App not installed or scheme not supported
  // Show QR code as fallback
  showQRCodeDialog();
}
```

#### 2. SocialPay Format Issues
```dart
// Try both formats sequentially
Future<bool> openSocialPayWithFallback(String qrText) async {
  // Try primary format first
  String primaryLink = 'socialpay-payment://q?qPay_QRcode=${Uri.encodeComponent(qrText)}';
  if (await launchUrl(Uri.parse(primaryLink))) {
    return true;
  }
  
  // Try alternative format
  String altLink = 'socialpay://qpay?qr=${Uri.encodeComponent(qrText)}';
  return await launchUrl(Uri.parse(altLink));
}
```

#### 3. QR Code Encoding Issues
```dart
// Ensure proper URL encoding
String encodeQRSafely(String qrText) {
  try {
    return Uri.encodeComponent(qrText);
  } catch (error) {
    // Fallback encoding
    return qrText.replaceAll(' ', '%20')
                 .replaceAll('+', '%2B')
                 .replaceAll('/', '%2F');
  }
}
```

#### 4. Authentication Failures
```dart
// Implement token refresh logic
static Future<String> ensureAuthenticated() async {
  if (_accessToken != null && 
      _tokenExpiry != null && 
      DateTime.now().isBefore(_tokenExpiry!)) {
    return _accessToken!;
  }
  
  final result = await getAccessToken();
  if (result['success'] == true) {
    return result['access_token'];
  } else {
    throw Exception('Authentication failed: ${result['error']}');
  }
}
```

### Debug Commands

```bash
# Check Flutter doctor
flutter doctor

# Analyze code
flutter analyze

# Test on device
flutter run --debug

# Build for testing
flutter build apk --debug

# Check package installation (Android)
adb shell pm list packages | grep socialpay
adb shell pm list packages | grep khan
```

### Performance Optimization

```dart
class QPayOptimizer {
  // Cache frequently used data
  static final Map<String, QPayInvoiceResult> _invoiceCache = {};
  static final Map<String, bool> _bankAvailabilityCache = {};
  
  // Batch bank availability checks
  static Future<void> preloadBankAvailability() async {
    final schemes = BankingAppChecker.bankSchemes.values;
    await Future.wait(schemes.map((scheme) async {
      _bankAvailabilityCache[scheme] = 
          await canLaunchUrl(Uri.parse(scheme));
    }));
  }
  
  // Optimize deeplink generation
  static String? getCachedDeepLink(String bank, String qrText) {
    final cacheKey = '$bank:$qrText';
    return _deeplinkCache[cacheKey];
  }
}
```

---

## Summary

This guide provides a complete implementation for QPay and deeplink integration with Mongolian banking applications. Key takeaways:

1. **Multi-Bank Support**: QPay supports 12+ major banks with consistent deeplink patterns
2. **SocialPay Differences**: Uses specific deeplink formats and is operated by Golomt Bank
3. **Cross-Platform**: Works on both Android and iOS with proper configuration
4. **Fallback Strategy**: Always provide QR code display as backup
5. **Error Handling**: Implement robust error handling and user feedback
6. **Testing**: Thoroughly test on real devices with actual banking apps installed

The implementation ensures seamless payment integration while maintaining compatibility across different Mongolian banking applications and payment systems.