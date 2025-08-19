# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Timex is a Flutter-based mobile application featuring time tracking, meal planning, and payment integration via QPay (Mongolian payment system). The app uses Firebase for authentication and data storage, with Google Sign-In for user authentication.

## Common Development Commands

### Flutter Commands
```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Build and run
flutter run --debug           # Run debug build
flutter run --release         # Run release build
flutter build apk            # Build Android APK
flutter build ios            # Build iOS app

# Code analysis and testing
flutter analyze              # Static analysis
flutter test                # Run unit tests
flutter doctor              # Check Flutter setup
```

### Firebase SHA-1 Configuration
When Google Sign-In fails, get SHA-1 fingerprint:
```bash
# Using keytool (if Java is available)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Using Gradle in Android Studio
./gradlew signingReport     # Run in android/ directory
```
Add the SHA-1 fingerprint to Firebase Console → Project Settings → Your apps → Add fingerprint.

## Architecture Overview

### Core Structure
- **Authentication Flow**: `AuthWrapper` → Google Sign-In → `MainScreen`
- **Main Navigation**: Bottom tab navigation with 5 screens using `PageController`
- **State Management**: Traditional StatefulWidget approach with Firebase Auth streams
- **Routing**: Custom route management via `Routes` class with `RouteObserver`

### Key Components


#### QPAY helper function 
const BASE_URL = config.QPAY_MODE === "production" ? config.QPAY_PRODUCTION_URL : config.QPAY_SANDBOX_URL;

/**
 * 🔐 Access Token авах
 */
async function getAccessToken() {
  try {
    const resp = await axios.post(`${BASE_URL}/auth/token`, null, {
      auth: {
        username: config.QPAY_USERNAME,
        password: config.QPAY_PASSWORD
      }
    });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("getAccessToken", error);
  }
}

/**
 * 🔄 Token refresh хийх
 */
async function refreshToken(refresh_token) {
  try {
    const resp = await axios.post(`${BASE_URL}/auth/refresh`, { refresh_token });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("refreshToken", error);
  }
}

/**
 * 🧾 Нэхэмжлэл үүсгэх (энгийн хувилбар)
 * @param {string} token
 * @param {number} amount
 * @param {string} orderId
 * @param {string} userId
 * @param {string} invoiceDescription
 */
async function createInvoice(token, amount, orderId, userId, invoiceDescription) {
  const payload = {
    invoice_code: config.QPAY_TEMPLATE,
    sender_invoice_no: `INV_${orderId}`,
    invoice_receiver_code: userId || 'terminal',
    invoice_description: invoiceDescription,
    amount: amount,
    callback_url: config.QPAY_CALLBACK_URL
  };

  try {
    const resp = await axios.post(`${BASE_URL}/invoice`, payload, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("createInvoice", error);
  }
}

/**
 * 📄 Нэхэмжлэлийн мэдээлэл авах
 */
async function getInvoice(token, invoiceId) {
  try {
    const resp = await axios.get(`${BASE_URL}/invoice/${invoiceId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("getInvoice", error);
  }
}

/**
 * 🚫 Нэхэмжлэл цуцлах
 */
async function cancelInvoice(token, invoiceId) {
  try {
    const resp = await axios.delete(`${BASE_URL}/invoice/${invoiceId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("cancelInvoice", error);
  }
}

/**
 * ✅ Төлбөр шалгах
 */
async function checkPayment(token, invoiceId) {
  try {
    // Load mock data for testing
    let mockData = {};
    try {
      mockData = JSON.parse(fs.readFileSync('./mock.json', 'utf8'));
    } catch (error) {
      console.warn('⚠️ Warning: Could not load mock.json file, falling back to real API');
    }

    // Check dynamic_payments first (from webhook simulation)
    const dynamicPayments = mockData.dynamic_payments || {};
    if (dynamicPayments[invoiceId]) {
      console.log(`🧪 Using dynamic mock data for payment check: ${invoiceId}`);
      const payment = dynamicPayments[invoiceId];
      return {
        success: true,
        count: 1,
        paid_amount: payment.payment_amount,
        rows: [{
          ...payment,
          payment_id: `mock_payment_${Date.now()}`,
          created_at: payment.payment_date || new Date().toISOString(),
          updated_at: new Date().toISOString()
        }]
      };
    }

    // Check static webhooks as fallback
    const mockWebhooks = mockData.webhooks || {};
    const mockPayment = Object.values(mockWebhooks).find(webhook => 
      webhook.object_id === invoiceId
    );

    if (mockPayment) {
      console.log(`🧪 Using static mock data for payment check: ${invoiceId}`);
      return {
        success: true,
        count: 1,
        paid_amount: mockPayment.payment_amount,
        rows: [{
          ...mockPayment,
          payment_id: `mock_payment_${Date.now()}`,
          created_at: mockPayment.payment_date || new Date().toISOString(),
          updated_at: new Date().toISOString()
        }]
      };s
    }

    // Fall back to real API call if no mock data found
    console.log(`🌐 Making real API call for payment check: ${invoiceId}`);
    const resp = await axios.post(`${BASE_URL}/payment/check`, {
      object_type: "INVOICE",
      object_id: invoiceId,
      offset: {
        "page_number": 1,
        "page_limit": 100
      }
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("checkPayment", error);
  }
}

/**
 * 📋 Төлбөрийн жагсаалт
 */
async function listPayments(token, query = {}) {
  try {
    const resp = await axios.post(`${BASE_URL}/payment/list`, query, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return { success: true, ...resp.data };
  } catch (error) {
    return handleError("listPayments", error);
  }
}

/**
 * 📱 QR код зураг файл үүсгэх
 * @param {string} qrText - QR кодын текст
 * @param {string} invoiceId - Нэхэмжлэлийн ID
 * @param {object} options - QR кодын тохиргоо
 */
async function generateQRImage(qrText, invoiceId, options = {}) {
  const defaultOptions = {
    width: 300,
    margin: 2,
    color: {
      dark: '#000000',
      light: '#FFFFFF'
    }
  };

  const qrOptions = { ...defaultOptions, ...options };
  
  try {
    // Create qr-images directory if it doesn't exist
    const dir = './qr-images';
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir);
    }

    // Generate filename
    const filename = `qr-${invoiceId}.png`;
    const filepath = `${dir}/${filename}`;

    // Generate QR code image
    await QRCode.toFile(filepath, qrText, qrOptions);
    
    console.log(`✅ QR код зураг хадгалагдлаа: ${filepath}`);
    return {
      success: true,
      filename,
      filepath,
      url: `/qr-images/${filename}`
    };
  } catch (error) {
    return handleError("generateQRImage", error);
  }
}

/**
 * 📱 QR код data URL үүсгэх (веб дэлгэцэнд харуулахад)
 * @param {string} qrText - QR кодын текст
 * @param {object} options - QR кодын тохиргоо
 */
async function generateQRDataURL(qrText, options = {}) {
  const defaultOptions = {
    width: 300,
    margin: 2,
    color: {
      dark: '#000000',
      light: '#FFFFFF'
    }
  };

  const qrOptions = { ...defaultOptions, ...options };
  
  try {
    const dataURL = await QRCode.toDataURL(qrText, qrOptions);
    return { success: true, dataURL };
  } catch (error) {
    return handleError("generateQRDataURL", error);
  }
}

/**
 * 🚀 Нэхэмжлэл үүсгээд QR код зураг авах (бүрэн функц)
 * @param {number} amount - Мөнгөн дүн
 * @param {string} orderId - Захиалгын дугаар
 * @param {string} userId - Хэрэглэгчийн ID
 * @param {string} invoiceDescription - Нэхэмжлэлийн тайлбар
 */
async function createInvoiceWithQR(amount, orderId, userId, invoiceDescription) {
  try {
    // 1. Access token авах
    console.log('🔐 QPay-тай холбогдож байна...');
    const authResult = await getAccessToken();
    if (!authResult.success) {
      throw new Error('Authentication failed: ' + authResult.error);
    }

    // 2. Нэхэмжлэл үүсгэх
    console.log('📄 Нэхэмжлэл үүсгэж байна...');
    const invoiceResult = await createInvoice(
      authResult.access_token,
      amount,
      orderId,
      userId,
      invoiceDescription
    );
    
    if (!invoiceResult.success) {
      throw new Error('Invoice creation failed: ' + invoiceResult.error);
    }

    // 3. QR код зураг үүсгэх
    console.log('📱 QR код зураг үүсгэж байна...');
    const qrImageResult = await generateQRImage(invoiceResult.qr_text, invoiceResult.invoice_id);
    const qrDataResult = await generateQRDataURL(invoiceResult.qr_text);

    // 4. Үр дүнг буцаах
    return {
      success: true,
      invoice: invoiceResult,
      qr_image: qrImageResult,
      qr_data_url: qrDataResult.success ? qrDataResult.dataURL : null,
      access_token: authResult.access_token
    };

  } catch (error) {
    return handleError("createInvoiceWithQR", error);
  }
}

/**
 * 🛑 Алдааг барьж авах
 */
function handleError(fnName, error) {
  console.error(`❌ Error in ${fnName}:`, error?.response?.data || error.message);
  return {
    success: false,
    error: error?.response?.data || error.message || "Unknown error",
    source: fnName
  };
}

#### Authentication (`lib/screens/auth/`)
- `AuthWrapper`: StreamBuilder listening to Firebase Auth state changes
- `GoogleLoginScreen`: Handles Google Sign-In with Firebase integration
- `LoginSelectionScreen`: Login method selection (if used)

#### Main Application (`lib/screens/main/`)
- `MainScreen`: TabBar container with PageView for 5 main sections:
  1. Time Tracking (`TimeTrackScreen`)
  2. Monthly Statistics (`MonthlyStatisticsScreen`)
  3. Meal Planning (`MealPlanCalendar`)
  4. Food Reports (`FoodReportScreen`)
  5. QPay QR Code (`QRCodeScreen`)

#### QPay Payment Integration (`lib/services/qpay_*`)
- **Complete payment solution** for Mongolian market
- `QPayHelper`: Core API interaction class with token management
- `QPayConfig`: Environment-based configuration management
- `QPayModels`: Data models for invoices, payments, and products
- Features: Invoice creation, QR generation, payment monitoring, status checking

### Firebase Integration
- **Authentication**: Google Sign-In with Firebase Auth
- **Firestore**: User profile storage with automatic document creation
- **Configuration**: Multi-platform setup (iOS, Android, Web, macOS, Windows)
- **Project**: `timex-9ce03` with proper platform configurations

### Environment Configuration
The app uses `.env` files for configuration:
- QPay credentials and API settings
- Firebase project configuration
- Server ports and callback URLs
- Feature flags (production/sandbox modes)

## Development Guidelines

### QPay Integration
- Always use `QPayHelper.ensureAuthenticated()` before API calls
- Environment variables are loaded in `main.dart` with proper error handling
- Test in sandbox mode before production deployment
- Monitor payment status using built-in checking mechanisms

### Firebase & Authentication
- `AuthWrapper` automatically handles login/logout navigation
- Google Sign-In requires proper SHA-1 configuration in Firebase Console
- User profiles are automatically created/updated in Firestore
- Sign-out process clears both Firebase and Google Sign-In sessions

### Code Patterns
- **Error Handling**: Comprehensive try-catch with user-friendly messages in Mongolian
- **Logging**: Centralized logging via `AppLogger` for different operation types
- **Navigation**: Uses GetX for routing with custom route observer
- **State Management**: StatefulWidget pattern with proper lifecycle management

### Common Issues & Solutions

#### Google Sign-In Failures
1. Verify SHA-1 fingerprint is added to Firebase Console
2. Check `google-services.json` is up-to-date
3. Ensure Firebase project ID matches across all configuration files
4. Test on different devices/emulators

#### QPay Integration Issues
1. Verify environment variables are loaded correctly
2. Check network connectivity for API calls
3. Validate product data before invoice creation
4. Monitor token expiration and refresh cycles

### File Organization
```
lib/
├── config/          # Configuration files (QPay, app settings)
├── models/          # Data models (QPay, app models)
├── screens/         # UI screens organized by feature
│   ├── auth/        # Authentication screens
│   ├── main/        # Main application container
│   ├── qpay/        # Payment-related screens
│   └── ...
├── services/        # Business logic and API services
├── utils/           # Utility functions and helpers
├── widgets/         # Reusable UI components
└── theme/           # App styling and assets
```

## Testing & Deployment

### Pre-deployment Checklist
1. Run `flutter analyze` to check for code issues
2. Test Google Sign-In with proper SHA-1 configuration
3. Verify QPay integration in sandbox mode
4. Test on both iOS and Android platforms
5. Check Firebase Console for proper app configuration

### Environment Setup
1. Copy `.env.example` to `.env` and configure QPay credentials
2. Ensure Firebase configuration files are present:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. Run `flutter pub get` after environment setup

---

# 🏦 QPay Integration & Mobile Banking Deep Links

## Overview

This application integrates with QPay (Mongolia's unified payment system) to enable seamless mobile banking payments. Users can generate QPay QR codes and open them directly in Mongolian banking applications.

## 📱 Deep Link Architecture

### Supported Banking Applications

The app supports deep links for all major Mongolian banks using the **official QPay format**:

```dart
// Standard QPay Deep Link Format
scheme://q?qPay_QRcode=<URL_encoded_qr_text>
```

#### Official Banking App Schemes

| Bank Name | Mongolian Name | Deep Link Scheme | Package Name |
|-----------|----------------|------------------|--------------|
| Khan Bank | Хаан банк | `khanbank://q?qPay_QRcode=...` | com.khanbank.retail |
| State Bank | Төрийн банк 3.0 | `statebank://q?qPay_QRcode=...` | mn.statebank |
| TDB Bank | TDB online | `tdbbank://q?qPay_QRcode=...` | mn.tdb.online |
| Xac Bank | Хас банк | `xacbank://q?qPay_QRcode=...` | mn.xac.bank |
| Most Money | МОСТ мони | `most://q?qPay_QRcode=...` | mn.most.money |
| NIB Bank | Үндэсний хөрөнгө оруулалт | `nibank://q?qPay_QRcode=...` | mn.nibank |
| Chinggis Khaan Bank | Чингис Хаан банк | `ckbank://q?qPay_QRcode=...` | mn.chinggisnbank |
| Capitron Bank | Капитрон банк | `capitronbank://q?qPay_QRcode=...` | mn.capitron.bank |
| Bogd Bank | Богд банк | `bogdbank://q?qPay_QRcode=...` | mn.bogd.bank |
| Candy Pay | Кэнди пэй | `candypay://q?qPay_QRcode=...` | mn.candy.pay |
| QPay Wallet | QPay хэтэвч | `qpay://invoice?id=<invoice_id>` | mn.qpay.wallet |

#### Special Case: Social Pay (Khan Bank)

Social Pay uses a different format and is currently the most reliable:

```dart
// Social Pay Deep Link (Different format)
socialpay-payment://q?qPay_QRcode=<URL_encoded_qr_text>
```

### 🔧 Complete QPay Implementation Guide

## 🚀 QPay API Integration

### Environment Configuration

The app uses environment variables for QPay configuration:

```dart
// Environment setup in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // QPay configuration
  final qpayMode = dotenv.env['QPAY_MODE'] ?? 'sandbox';
  final qpayUsername = dotenv.env['QPAY_USERNAME'] ?? '';
  final qpayPassword = dotenv.env['QPAY_PASSWORD'] ?? '';
  
  runApp(MyApp());
}
```

Required `.env` variables:
```bash
# QPay Configuration
QPAY_MODE=sandbox                    # or 'production'
QPAY_USERNAME=your_qpay_username
QPAY_PASSWORD=your_qpay_password
QPAY_TEMPLATE=your_template_id
QPAY_CALLBACK_URL=http://localhost:3000/qpay/webhook

# URLs
QPAY_SANDBOX_URL=https://merchant-sandbox.qpay.mn/v2
QPAY_PRODUCTION_URL=https://merchant.qpay.mn/v2
```

### 🔐 QPay Authentication Service

**File**: `lib/services/qpay_helper_service.dart`

```dart
class QPayHelperService {
  static const String _baseUrl = 'https://merchant-sandbox.qpay.mn/v2';
  
  /// Get QPay access token
  static Future<Map<String, dynamic>> getAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': dotenv.env['QPAY_USERNAME'],
          'password': dotenv.env['QPAY_PASSWORD'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.success('QPay authentication successful');
        return {'success': true, ...data};
      } else {
        throw Exception('Auth failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('QPay authentication failed', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Refresh expired access token
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.success('QPay token refreshed successfully');
        return {'success': true, ...data};
      } else {
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (error) {
      AppLogger.error('QPay token refresh failed', error);
      return {'success': false, 'error': error.toString()};
    }
  }
}
```

### 📄 Invoice Creation Service

```dart
/// Create QPay invoice with QR code
static Future<Map<String, dynamic>> createInvoiceWithQR({
  required double amount,
  required String orderId,
  required String userId,
  required String invoiceDescription,
  String? callbackUrl,
  bool enableSocialPay = false,
}) async {
  try {
    // 1. Get access token
    final authResult = await getAccessToken();
    if (authResult['success'] != true) {
      throw Exception('Authentication failed: ${authResult['error']}');
    }
    
    final accessToken = authResult['access_token'];
    
    // 2. Create invoice payload
    final payload = {
      'invoice_code': dotenv.env['QPAY_TEMPLATE'],
      'sender_invoice_no': 'INV_$orderId',
      'invoice_receiver_code': userId,
      'invoice_description': invoiceDescription,
      'amount': amount,
      'callback_url': callbackUrl ?? dotenv.env['QPAY_CALLBACK_URL'],
    };
    
    // 3. Create invoice
    final response = await http.post(
      Uri.parse('$_baseUrl/invoice'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    
    if (response.statusCode == 200) {
      final invoice = jsonDecode(response.body);
      
      AppLogger.success('QPay invoice created: ${invoice['invoice_id']}');
      
      // 4. Generate QR code image (optional)
      String? qrImageBase64;
      if (invoice['qr_text'] != null) {
        qrImageBase64 = await _generateQRImageBase64(
          invoice['qr_text'],
          invoice['invoice_id'],
        );
      }
      
      return {
        'success': true,
        'invoice': invoice,
        'qr_image_base64': qrImageBase64,
        'access_token': accessToken,
      };
    } else {
      throw Exception('Invoice creation failed: ${response.statusCode}');
    }
  } catch (error) {
    AppLogger.error('Invoice creation failed', error);
    return {'success': false, 'error': error.toString()};
  }
}

/// Generate QR code image as base64 string
static Future<String?> _generateQRImageBase64(String qrText, String invoiceId) async {
  try {
    final qrValidationResult = await QrCode.fromData(
      data: qrText,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    
    final qrCode = qrValidationResult.qrCode;
    final qrImage = QrImage(qrCode);
    
    // Convert to image bytes
    final imageBytes = await qrImage.toImageData(300);
    final base64String = base64Encode(imageBytes!.buffer.asUint8List());
    
    AppLogger.success('QR code image generated for invoice: $invoiceId');
    return base64String;
  } catch (error) {
    AppLogger.error('QR code generation failed', error);
    return null;
  }
}
```

### ✅ Payment Status Checking Service

```dart
/// Check payment status for an invoice
static Future<Map<String, dynamic>> checkPayment(
  String accessToken,
  String invoiceId,
) async {
  try {
    final payload = {
      'object_type': 'INVOICE',
      'object_id': invoiceId,
      'offset': {
        'page_number': 1,
        'page_limit': 100,
      },
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/payment/check'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final count = data['count'] ?? 0;
      final paidAmount = data['paid_amount'] ?? 0.0;
      
      AppLogger.info('Payment check result: $count payments, total: $paidAmount');
      
      return {
        'success': true,
        'count': count,
        'paid_amount': paidAmount.toDouble(),
        'rows': data['rows'] ?? [],
      };
    } else {
      throw Exception('Payment check failed: ${response.statusCode}');
    }
  } catch (error) {
    AppLogger.error('Payment check failed', error);
    return {'success': false, 'error': error.toString()};
  }
}

/// Get detailed invoice information
static Future<Map<String, dynamic>> getInvoice(
  String accessToken,
  String invoiceId,
) async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/invoice/$invoiceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final invoice = jsonDecode(response.body);
      AppLogger.success('Invoice retrieved: $invoiceId');
      return {'success': true, 'invoice': invoice};
    } else {
      throw Exception('Get invoice failed: ${response.statusCode}');
    }
  } catch (error) {
    AppLogger.error('Get invoice failed', error);
    return {'success': false, 'error': error.toString()};
  }
}

/// Cancel an unpaid invoice
static Future<Map<String, dynamic>> cancelInvoice(
  String accessToken,
  String invoiceId,
) async {
  try {
    final response = await http.delete(
      Uri.parse('$_baseUrl/invoice/$invoiceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      AppLogger.success('Invoice cancelled: $invoiceId');
      return {'success': true, 'message': 'Invoice cancelled successfully'};
    } else {
      throw Exception('Cancel invoice failed: ${response.statusCode}');
    }
  } catch (error) {
    AppLogger.error('Cancel invoice failed', error);
    return {'success': false, 'error': error.toString()};
  }
}
```

### 🔄 Complete Payment Flow Implementation

```dart
class PaymentFlowService {
  static String? _currentAccessToken;
  static String? _currentInvoiceId;
  static Timer? _paymentCheckTimer;

  /// Complete payment flow from invoice creation to verification
  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String userId,
    required String description,
    required Function(String invoiceId, String qrText) onInvoiceCreated,
    required Function(double paidAmount) onPaymentConfirmed,
    required Function(String error) onError,
  }) async {
    try {
      // 1. Create invoice
      final orderId = 'TIMEX_${DateTime.now().millisecondsSinceEpoch}';
      final invoiceResult = await QPayHelperService.createInvoiceWithQR(
        amount: amount,
        orderId: orderId,
        userId: userId,
        invoiceDescription: description,
      );

      if (invoiceResult['success'] != true) {
        throw Exception(invoiceResult['error']);
      }

      final invoice = invoiceResult['invoice'];
      _currentInvoiceId = invoice['invoice_id'];
      _currentAccessToken = invoiceResult['access_token'];
      
      // 2. Notify UI about invoice creation
      onInvoiceCreated(_currentInvoiceId!, invoice['qr_text']);

      // 3. Start payment monitoring
      _startPaymentMonitoring(onPaymentConfirmed, onError);

      return {'success': true, 'invoice_id': _currentInvoiceId};
    } catch (error) {
      onError(error.toString());
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Start automatic payment status checking
  static void _startPaymentMonitoring(
    Function(double paidAmount) onPaymentConfirmed,
    Function(String error) onError,
  ) {
    _paymentCheckTimer?.cancel();
    
    _paymentCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        if (_currentInvoiceId == null || _currentAccessToken == null) {
          timer.cancel();
          return;
        }

        try {
          final result = await QPayHelperService.checkPayment(
            _currentAccessToken!,
            _currentInvoiceId!,
          );

          if (result['success'] == true) {
            final count = result['count'] ?? 0;
            if (count > 0) {
              final paidAmount = result['paid_amount'] ?? 0.0;
              timer.cancel();
              onPaymentConfirmed(paidAmount.toDouble());
            }
          }
        } catch (error) {
          AppLogger.error('Payment monitoring error', error);
          // Don't cancel timer on temporary errors
        }
      },
    );
  }

  /// Stop payment monitoring
  static void stopPaymentMonitoring() {
    _paymentCheckTimer?.cancel();
    _currentInvoiceId = null;
    _currentAccessToken = null;
  }

  /// Manual payment verification
  static Future<Map<String, dynamic>> verifyPayment() async {
    if (_currentInvoiceId == null || _currentAccessToken == null) {
      return {'success': false, 'error': 'No active payment to verify'};
    }

    return await QPayHelperService.checkPayment(
      _currentAccessToken!,
      _currentInvoiceId!,
    );
  }
}
```

### 🏦 Deep Link Implementation Components

#### Core Deep Link Components

1. **QR Utils** (`lib/utils/qr_utils.dart`):
   ```dart
   // Generate deep links for all banks
   static Map<String, String> generateDeepLinks(
     String qrText,
     String? qpayShortUrl,
     String? invoiceId,
   );
   
   // Get the primary deep link
   static String? getPrimaryDeepLink(
     String qrText,
     String? qpayShortUrl, 
     String? invoiceId,
   );
   ```

2. **Banking App Checker** (`lib/utils/banking_app_checker.dart`):
   ```dart
   // Check which banking apps are installed
   static Future<Map<String, bool>> checkAvailableBankingApps();
   
   // Get optimized deep links for detected apps
   static Future<Map<String, String>> getOptimizedDeepLinks(
     String qrText,
     String? invoiceId,
   );
   ```

3. **Khan Bank Specialized Launcher** (`lib/utils/khan_bank_launcher.dart`):
   ```dart
   // Try multiple Khan Bank app launch methods
   static Future<bool> launchKhanBankApp({
     required String qrText,
     String? invoiceId,
   });
   ```

4. **Social Pay Integration** (`lib/utils/socialpay_integration.dart`):
   ```dart
   /// Generate Social Pay deep link (different format from other banks)
   static String? getSocialPayDeepLink({
     required String qrText,
     required String invoiceId,
   }) {
     if (qrText.isEmpty) return null;
     
     try {
       final encodedQR = Uri.encodeComponent(qrText);
       return 'socialpay-payment://q?qPay_QRcode=$encodedQR';
     } catch (error) {
       AppLogger.error('SocialPay deep link generation failed', error);
       return null;
     }
   }
   ```

### 🎯 Complete Banking App Launch Implementation

```dart
/// Complete banking app launcher with fallbacks
class BankingAppLauncher {
  /// Launch the most appropriate banking app for payment
  static Future<Map<String, dynamic>> launchBestBankingApp({
    required String qrText,
    required String invoiceId,
  }) async {
    try {
      // 1. Try Social Pay first (most reliable)
      final socialPayResult = await _trySocialPay(qrText, invoiceId);
      if (socialPayResult['success'] == true) {
        return socialPayResult;
      }

      // 2. Try Khan Bank (second most reliable)
      final khanBankResult = await _tryKhanBank(qrText, invoiceId);
      if (khanBankResult['success'] == true) {
        return khanBankResult;
      }

      // 3. Try other banking apps
      final otherBanksResult = await _tryOtherBanks(qrText, invoiceId);
      if (otherBanksResult['success'] == true) {
        return otherBanksResult;
      }

      return {
        'success': false,
        'error': 'No compatible banking app found',
      };
    } catch (error) {
      AppLogger.error('Banking app launch failed', error);
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _trySocialPay(
    String qrText,
    String invoiceId,
  ) async {
    try {
      final socialPayLink = SocialPayIntegration.getSocialPayDeepLink(
        qrText: qrText,
        invoiceId: invoiceId,
      );

      if (socialPayLink != null) {
        final uri = Uri.parse(socialPayLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          AppLogger.success('Launched Social Pay successfully');
          return {
            'success': true,
            'bank': 'Social Pay',
            'scheme': 'socialpay-payment://',
          };
        }
      }
    } catch (error) {
      AppLogger.warning('Social Pay launch failed: $error');
    }

    return {'success': false};
  }

  static Future<Map<String, dynamic>> _tryKhanBank(
    String qrText,
    String invoiceId,
  ) async {
    try {
      if (await KhanBankLauncher.launchKhanBankApp(
        qrText: qrText,
        invoiceId: invoiceId,
      )) {
        return {
          'success': true,
          'bank': 'Khan Bank',
          'scheme': 'khanbank://',
        };
      }
    } catch (error) {
      AppLogger.warning('Khan Bank launch failed: $error');
    }

    return {'success': false};
  }

  static Future<Map<String, dynamic>> _tryOtherBanks(
    String qrText,
    String invoiceId,
  ) async {
    final deepLinks = QRUtils.generateDeepLinks(qrText, null, invoiceId);
    
    // Priority order for other banks
    final bankPriority = [
      'statebank',
      'tdbbank',
      'xacbank',
      'most',
      'nibank',
      'ckbank',
      'capitronbank',
      'bogdbank',
      'candypay',
    ];

    for (final bankKey in bankPriority) {
      if (deepLinks.containsKey(bankKey)) {
        try {
          final uri = Uri.parse(deepLinks[bankKey]!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            AppLogger.success('Launched $bankKey successfully');
            return {
              'success': true,
              'bank': bankKey,
              'scheme': deepLinks[bankKey],
            };
          }
        } catch (error) {
          AppLogger.warning('$bankKey launch failed: $error');
        }
      }
    }

    return {'success': false};
  }
}
```

### 💳 User Payment Service Integration

**File**: `lib/services/user_payment_service.dart`

```dart
class UserPaymentService {
  /// Process payment and update user balance
  static Future<Map<String, dynamic>> processPayment({
    required String userId,
    required double paidAmount,
    required String paymentMethod,
    required String invoiceId,
    String? orderId,
  }) async {
    try {
      // Get current user payment info
      final currentInfo = await getUserPaymentInfo();
      final currentBalance = currentInfo['totalFoodAmount'] ?? 0.0;
      
      // Calculate new balance (subtract payment from debt)
      final newBalance = (currentBalance - paidAmount).clamp(0.0, double.infinity);
      
      // Determine payment status
      String paymentStatus;
      if (newBalance <= 0) {
        paymentStatus = 'paid';
      } else if (newBalance < currentBalance) {
        paymentStatus = 'partial';
      } else {
        paymentStatus = 'pending';
      }

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'totalFoodAmount': newBalance,
        'qpayStatus': paymentStatus,
        'lastPaymentAmount': paidAmount,
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'lastPaymentMethod': paymentMethod,
        'lastInvoiceId': invoiceId,
        'lastOrderId': orderId,
      });

      AppLogger.success(
        'Payment processed: ₮$paidAmount, New balance: ₮$newBalance, Status: $paymentStatus'
      );

      return {
        'success': true,
        'previousAmount': currentBalance,
        'newAmount': newBalance,
        'status': paymentStatus,
        'paidAmount': paidAmount,
      };
    } catch (error) {
      AppLogger.error('Payment processing failed', error);
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  /// Get current user payment information
  static Future<Map<String, dynamic>> getUserPaymentInfo() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'success': true,
          'totalFoodAmount': data['totalFoodAmount'] ?? 0.0,
          'qpayStatus': data['qpayStatus'] ?? 'none',
          'lastPaymentAmount': data['lastPaymentAmount'] ?? 0.0,
          'lastPaymentDate': data['lastPaymentDate'],
          'lastPaymentMethod': data['lastPaymentMethod'] ?? '',
          'lastInvoiceId': data['lastInvoiceId'] ?? '',
        };
      }

      return {'success': false, 'error': 'User document not found'};
    } catch (error) {
      AppLogger.error('Get user payment info failed', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Update payment status without processing payment
  static Future<Map<String, dynamic>> updatePaymentStatus({
    required String userId,
    required String status,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'qpayStatus': status});

      return {'success': true};
    } catch (error) {
      AppLogger.error('Update payment status failed', error);
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Ensure user document exists
  static Future<void> ensureUserDocument() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!doc.exists) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'totalFoodAmount': 0.0,
        'qpayStatus': 'none',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      AppLogger.info('User document created for: ${currentUser.uid}');
    }
  }
}
```

### 🔄 Complete UI Implementation Example

**File**: `lib/screens/qpay/qr_code_screen.dart` (Key Methods)

```dart
/// Generate QPay invoice and QR code
Future<void> _generateQPayQR() async {
  if (_isGenerating) return;

  setState(() {
    _isGenerating = true;
    _errorMessage = null;
  });

  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Generate unique order ID
    final orderId = 'TIMEX_QR_${DateTime.now().millisecondsSinceEpoch}';

    // Create invoice with QR
    final result = await QPayHelperService.createInvoiceWithQR(
      amount: 50000.0, // Fixed amount or dynamic
      orderId: orderId,
      userId: currentUser.uid,
      invoiceDescription: 'Timex Food Payment - ₮50,000',
      enableSocialPay: true,
    );

    if (result['success'] == true) {
      final invoice = result['invoice'];
      
      setState(() {
        qpayResult = {
          'success': true,
          'invoice_id': invoice['invoice_id'],
          'qr_text': invoice['qr_text'],
          'qpay_shorturl': invoice['qpay_shorturl'],
          'access_token': result['access_token'],
        };
        _currentInvoiceId = invoice['invoice_id'];
        _currentAccessToken = result['access_token'];
      });

      _showMessage('QPay invoice created successfully!', isError: false);
      
      // Start automatic payment monitoring
      _startPaymentMonitoring();
    } else {
      throw Exception(result['error'] ?? 'Failed to create QPay invoice');
    }
  } catch (error) {
    setState(() {
      _errorMessage = 'Failed to generate QPay QR: $error';
    });
    _showMessage('Failed to create QPay invoice: $error', isError: true);
  } finally {
    setState(() {
      _isGenerating = false;
    });
  }
}

/// Launch banking app with QR code
Future<void> _openBankingApp() async {
  if (qpayResult == null) return;

  try {
    final qrText = qpayResult!['qr_text'] ?? '';
    final invoiceId = qpayResult!['invoice_id'] ?? '';

    // Use comprehensive banking app launcher
    final launchResult = await BankingAppLauncher.launchBestBankingApp(
      qrText: qrText,
      invoiceId: invoiceId,
    );

    if (launchResult['success'] == true) {
      final bankName = launchResult['bank'];
      _showMessage('Opened $bankName successfully', isError: false);
    } else {
      _showMessage('No compatible banking app found', isError: true);
    }
  } catch (error) {
    _showMessage('Failed to open banking app: $error', isError: true);
  }
}

/// Start automatic payment monitoring
void _startPaymentMonitoring() {
  _paymentCheckTimer?.cancel();
  
  _paymentCheckTimer = Timer.periodic(
    const Duration(seconds: 3),
    (timer) => _checkPaymentStatus(),
  );
}

/// Check payment status
Future<void> _checkPaymentStatus() async {
  if (_currentInvoiceId == null || _currentAccessToken == null) return;

  try {
    final result = await QPayHelperService.checkPayment(
      _currentAccessToken!,
      _currentInvoiceId!,
    );

    if (result['success'] == true) {
      final count = result['count'] ?? 0;
      if (count > 0) {
        // Payment found - process it
        final payments = result['rows'] ?? [];
        final payment = payments.first;
        final paidAmount = (payment['payment_amount'] ?? 0.0).toDouble();

        await _processPayment(paidAmount);
      }
    }
  } catch (error) {
    AppLogger.error('Payment status check failed', error);
  }
}

/// Process confirmed payment
Future<void> _processPayment(double paidAmount) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final result = await UserPaymentService.processPayment(
      userId: currentUser.uid,
      paidAmount: paidAmount,
      paymentMethod: 'QPay',
      invoiceId: _currentInvoiceId!,
    );

    if (result['success'] == true) {
      // Stop monitoring
      _paymentCheckTimer?.cancel();
      
      // Show success message
      _showPaymentSuccessDialog(
        paidAmount,
        result['newAmount'] ?? 0.0,
        result['status'] ?? 'unknown',
      );
    }
  } catch (error) {
    AppLogger.error('Payment processing failed', error);
    _showMessage('Payment verification failed: $error', isError: true);
  }
}
```

### 📋 Platform Configuration

#### Android Configuration (`android/app/src/main/AndroidManifest.xml`)

Add intent filters to handle deep links and allow querying other apps:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  
  <!-- Permissions to query and launch banking apps -->
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
  
  <!-- Banking app package queries for Android 11+ -->
  <queries>
    <!-- Khan Bank -->
    <package android:name="com.khanbank.retail" />
    <package android:name="com.khanbank.app" />
    
    <!-- State Bank -->
    <package android:name="mn.statebank" />
    <package android:name="mn.statebank.mobile" />
    
    <!-- TDB Bank -->
    <package android:name="mn.tdb.online" />
    <package android:name="mn.tdb.pay" />
    
    <!-- Other Banks -->
    <package android:name="mn.xac.bank" />
    <package android:name="mn.most.money" />
    <package android:name="mn.nibank" />
    <package android:name="mn.chinggisnbank" />
    <package android:name="mn.capitron.bank" />
    <package android:name="mn.bogd.bank" />
    <package android:name="mn.candy.pay" />
    <package android:name="mn.qpay.wallet" />
    
    <!-- Social Pay -->
    <package android:name="mn.khan.socialpay" />
    
    <!-- Intent filters for banking schemes -->
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="khanbank" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="statebank" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="tdbbank" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="socialpay-payment" />
    </intent>
    <!-- Add more banking schemes as needed -->
  </queries>

  <application
    android:label="timex"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
    
    <activity
      android:name=".MainActivity"
      android:exported="true"
      android:launchMode="singleTop"
      android:theme="@style/LaunchTheme"
      android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
      android:hardwareAccelerated="true"
      android:windowSoftInputMode="adjustResize">
      
      <!-- App launch intent -->
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
      
      <!-- Deep link handling for QPay callbacks -->
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="timex"
              android:host="qpay" />
      </intent-filter>
    </activity>
    
    <!-- Don't delete the meta-data below -->
    <meta-data
      android:name="flutterEmbedding"
      android:value="2" />
  </application>
</manifest>
```

#### iOS Configuration (`ios/Runner/Info.plist`)

Add URL schemes and LSApplicationQueriesSchemes for banking apps:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- App Info -->
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Timex</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleName</key>
	<string>timex</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	
	<!-- URL Schemes for Deep Links -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>timex.qpay</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>timex</string>
			</array>
		</dict>
	</array>
	
	<!-- Banking App Query Schemes (iOS 9+) -->
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<!-- Khan Bank -->
		<string>khanbank</string>
		<string>khanbankapp</string>
		<string>khanbank-retail</string>
		
		<!-- Social Pay (Khan Bank) -->
		<string>socialpay</string>
		<string>socialpay-payment</string>
		
		<!-- State Bank -->
		<string>statebank</string>
		<string>statebankapp</string>
		
		<!-- TDB Bank -->
		<string>tdbbank</string>
		<string>tdb</string>
		
		<!-- Xac Bank -->
		<string>xacbank</string>
		<string>xac</string>
		
		<!-- Most Money -->
		<string>most</string>
		<string>mostmoney</string>
		
		<!-- NIB Bank -->
		<string>nibank</string>
		<string>ulaanbaatarbank</string>
		
		<!-- Chinggis Khaan Bank -->
		<string>ckbank</string>
		<string>chinggisnbank</string>
		
		<!-- Capitron Bank -->
		<string>capitronbank</string>
		<string>capitron</string>
		
		<!-- Bogd Bank -->
		<string>bogdbank</string>
		<string>bogd</string>
		
		<!-- Other Banks -->
		<string>arigbank</string>
		<string>transbank</string>
		<string>ardbank</string>
		
		<!-- Digital Wallets -->
		<string>candypay</string>
		<string>candy</string>
		<string>qpay</string>
	</array>
	
	<!-- App Transport Security -->
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
		<key>NSExceptionDomains</key>
		<dict>
			<key>qpay.mn</key>
			<dict>
				<key>NSExceptionAllowsInsecureHTTPLoads</key>
				<true/>
				<key>NSExceptionMinimumTLSVersion</key>
				<string>TLSv1.0</string>
				<key>NSIncludesSubdomains</key>
				<true/>
			</dict>
		</dict>
	</dict>
	
	<!-- Camera Permission for QR Scanning -->
	<key>NSCameraUsageDescription</key>
	<string>Camera access is required to scan QR codes for payments</string>
	
	<!-- Other required keys -->
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
</dict>
</plist>
```

### 🚀 QPay Integration Flow

#### 1. Create Invoice with QR Code

```dart
// Create QPay invoice
final result = await QPayHelperService.createInvoiceWithQR(
  amount: 50000.0,
  orderId: 'TIMEX_${DateTime.now().millisecondsSinceEpoch}',
  userId: currentUser.uid,
  invoiceDescription: 'TIMEX Payment - ₮50,000',
  enableSocialPay: true,
  callbackUrl: 'http://localhost:3000/qpay/webhook',
);

if (result['success'] == true) {
  final invoice = result['invoice'];
  final qrText = invoice['qr_text'];
  final invoiceId = invoice['invoice_id'];
  
  // Launch banking app with QR data
  await _launchBankingApp(qrText, invoiceId);
}
```

#### 2. Launch Banking Application

```dart
Future<void> _launchBankingApp(String qrText, String invoiceId) async {
  // Try Khan Bank first (most reliable after Social Pay)
  if (await KhanBankLauncher.launchKhanBankApp(
    qrText: qrText,
    invoiceId: invoiceId,
  )) {
    return; // Successfully launched Khan Bank
  }
  
  // Try Social Pay (most reliable)
  final socialPayLink = SocialPayIntegration.getSocialPayDeepLink(
    qrText: qrText,
    invoiceId: invoiceId,
  );
  
  if (socialPayLink != null) {
    final uri = Uri.parse(socialPayLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }
  
  // Fallback to other banking apps
  final deepLinks = QRUtils.generateDeepLinks(qrText, null, invoiceId);
  for (final link in deepLinks.values) {
    try {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      print('Failed to launch: $link');
    }
  }
}
```

#### 3. Payment Status Monitoring

```dart
// Check payment status
Future<void> _checkPaymentStatus(String accessToken, String invoiceId) async {
  final result = await QPayHelperService.checkPayment(accessToken, invoiceId);
  
  if (result['success'] == true) {
    final count = result['count'] ?? 0;
    if (count > 0) {
      // Payment found - process it
      final payments = result['rows'] ?? [];
      final payment = payments.first;
      final paidAmount = payment['payment_amount'];
      
      await _processPayment(paidAmount, invoiceId);
    }
  }
}
```

### 🛠️ Troubleshooting Guide

#### Common Deep Link Issues

1. **Banking App Not Opening**
   ```dart
   // Debug: Check if app can launch URLs
   final uri = Uri.parse('khanbank://q?qPay_QRcode=test');
   final canLaunch = await canLaunchUrl(uri);
   print('Can launch Khan Bank: $canLaunch');
   ```

2. **Wrong URL Format**
   ```dart
   // ❌ Wrong (old format)
   'khanbank://qpay?qrText=$qrText&invoiceId=$invoiceId'
   
   // ✅ Correct (official QPay format)
   'khanbank://q?qPay_QRcode=${Uri.encodeComponent(qrText)}'
   ```

3. **Platform Configuration Missing**
   - Android: Add package queries to AndroidManifest.xml
   - iOS: Add LSApplicationQueriesSchemes to Info.plist

#### Banking App Priority Order

1. **Social Pay** - Most reliable, different format
2. **Khan Bank** - Official QPay format, most popular
3. **State Bank** - Official QPay format
4. **TDB Bank** - Official QPay format
5. **Other Banks** - Official QPay format

### 📊 Deep Link Analytics

Monitor deep link success rates:

```dart
class DeepLinkAnalytics {
  static void trackLaunchAttempt(String bankName, String scheme) {
    AppLogger.info('Attempting to launch $bankName with $scheme');
  }
  
  static void trackLaunchSuccess(String bankName) {
    AppLogger.success('Successfully launched $bankName');
  }
  
  static void trackLaunchFailure(String bankName, String error) {
    AppLogger.error('Failed to launch $bankName: $error');
  }
}
```

---

# 🤖 Prompt Engineering Guidelines

## Working with QPay Integration

When working on QPay-related features, use these specific prompts for better AI assistance:

### 🎯 Effective Prompts for QPay Development

#### 1. Deep Link Troubleshooting
```
"The Khan Bank app is opening but not loading the invoice. I'm using deep link format: 
[current_format]. Based on the QPay developer documentation in CLAUDE.md, what's the 
correct format and how should I debug this?"
```

#### 2. New Banking App Integration
```
"I need to add support for [BankName] mobile app. According to QPay documentation, 
what deep link format should I use? Please provide the complete implementation 
including URL scheme, parameter format, and platform configuration."
```

#### 3. Payment Status Issues
```
"QPay payment status checking is not working correctly. The webhook shows payment 
as completed but the app status is still pending. Please help debug the payment 
verification flow and suggest improvements."
```

#### 4. Platform-Specific Configuration
```
"I need to configure [iOS/Android] to support QPay deep links for all Mongolian 
banking apps. Please provide the complete AndroidManifest.xml or Info.plist 
configuration based on the banking apps list in CLAUDE.md."
```

#### 5. Error Handling Enhancement
```
"QPay integration needs better error handling for network issues, authentication 
failures, and payment timeouts. Please review the current implementation and 
suggest comprehensive error handling patterns."
```

### 📝 Context-Rich Prompts

Always provide context when asking for QPay-related help:

```
"Context: Working on Timex Flutter app with QPay integration for Mongolian banking.
Current issue: [specific_issue]
Relevant code: [code_snippet]
Error logs: [error_logs]
Expected behavior: [expected_result]

Please help debug and provide solution following the patterns in CLAUDE.md."
```

### 🔍 Code Review Prompts

```
"Please review this QPay deep link implementation against the official format 
documented in CLAUDE.md. Check for:
1. Correct URL scheme format
2. Proper QR text encoding
3. Banking app compatibility
4. Error handling completeness
5. Platform configuration requirements"
```

### 🚀 Feature Development Prompts

```
"I need to implement [feature_name] for QPay integration. Based on the existing 
architecture in CLAUDE.md, please provide:
1. Complete implementation with proper error handling
2. Platform configuration updates (Android/iOS)
3. Testing approach and edge cases
4. Integration with existing QPayHelperService"
```

### 🎨 UI/UX Enhancement Prompts

```
"The QPay payment flow needs UX improvements. Current flow: [describe_current_flow].
Please suggest enhancements following Material Design principles and considering 
Mongolian user preferences. Include loading states, error messages in Mongolian, 
and success animations."
```

### 🧪 Testing & Debugging Prompts

```
"I need comprehensive testing for QPay deep links across all supported banking apps. 
Please provide:
1. Unit tests for deep link generation
2. Integration tests for banking app launches  
3. Mock data for payment status testing
4. Debug utilities for troubleshooting"
```

## 💡 Best Practices for AI Assistance

### Do's ✅
- Always reference CLAUDE.md for project context
- Provide specific error logs and code snippets
- Mention the target platform (iOS/Android/both)
- Include expected vs actual behavior
- Ask for complete solutions including error handling

### Don'ts ❌
- Don't ask generic questions without context
- Don't assume AI knows about Mongolian banking specifics
- Don't request solutions without considering existing architecture
- Don't ignore platform-specific requirements

### Example High-Quality Prompt

```
"Context: Timex Flutter app, QPay integration for Mongolian banking
Platform: Android
Issue: Social Pay deep link works but Khan Bank fails with 'app opens but doesn't load invoice'

Current Khan Bank implementation:
```dart
final deepLink = 'khanbank://qpay?qrText=$qrText&invoiceId=$invoiceId';
```

Logs show: 'component name for khanbank://qpay?qrText=... is {com.khanbank.retail/...}'

Based on CLAUDE.md QPay documentation, please:
1. Identify the issue with current deep link format
2. Provide correct implementation using official QPay format  
3. Update both QR screen and payment screen implementations
4. Add necessary AndroidManifest.xml configuration
5. Include error handling for failed launches

Expected result: Khan Bank app should open and load the invoice for payment."
```

This prompt provides complete context, shows the current code, includes error logs, references the documentation, and asks for a comprehensive solution.