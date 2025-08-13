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