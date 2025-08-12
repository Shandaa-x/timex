# QPay Flutter Integration

This directory contains the complete Dart/Flutter implementation of QPay payment integration, converted from the original JavaScript code.

## 📁 File Structure

```
lib/
├── config/
│   └── qpay_config.dart          # QPay configuration settings
├── models/
│   └── qpay_models.dart          # Data models for QPay operations
├── services/
│   ├── qpay_service.dart         # Main QPay service (frontend)
│   └── qpay_helper.dart          # QPay API helper functions
├── utils/
│   ├── logger.dart               # Logging utility
│   └── qr_utils.dart             # QR code utilities
└── examples/
    └── qpay_example.dart         # Usage examples and demo UI
```

## 🚀 Quick Start

### 1. Add Dependencies

Add these packages to your `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
  cloud_firestore: ^4.13.0
  qr_flutter: ^4.1.0  # For QR code generation (optional)

dev_dependencies:
  flutter_lints: ^3.0.0
```

### 2. Configure Environment

Set up your QPay credentials (use environment variables or configuration):

```dart
// lib/config/qpay_config.dart contains default values
// Override with environment variables:
const String.fromEnvironment('QPAY_USERNAME', defaultValue: 'GRAND_IT');
const String.fromEnvironment('QPAY_PASSWORD', defaultValue: 'gY8ljnov');
```

### 3. Basic Usage

```dart
import 'package:your_app/services/qpay_service.dart';
import 'package:your_app/models/qpay_models.dart';

// Create an order
final order = {
  'orderNumber': 'ORDER_123',
  'totalAmount': 25.99,
  'items': [
    {
      'productName': 'Product 1',
      'numericPrice': 15.99,
      'quantity': 1,
    },
    {
      'productName': 'Product 2', 
      'numericPrice': 10.00,
      'quantity': 1,
    }
  ],
};

// User information
final user = {
  'uid': 'user_123',
  'email': 'user@example.com',
};

// Create QPay invoice
try {
  final result = await QPayService.createInvoice(
    order,
    user,
    expirationMinutes: 5,
  );
  
  if (result.success) {
    print('Invoice created: ${result.invoiceId}');
    print('QR Text: ${result.qrText}');
    print('Amount: ${result.amount}');
    
    // Monitor payment status
    await QPayService.monitorPayment(
      result.invoiceId!,
      onPaymentComplete: (paymentData) {
        print('Payment successful! 🎉');
      },
      onSessionExpired: () {
        print('Session expired');
      },
    );
  }
} catch (error) {
  print('Error: $error');
}
```

## 🏗️ Architecture

### Core Components

1. **QPayService** (`services/qpay_service.dart`)
   - Main frontend interface
   - Communicates with backend QPay server
   - Handles Firebase integration
   - Manages payment monitoring

2. **QPayHelper** (`services/qpay_helper.dart`)
   - Direct QPay API communication
   - Token management
   - Invoice creation and management
   - Payment status checking

3. **QPayModels** (`models/qpay_models.dart`)
   - Type-safe data structures
   - JSON serialization/deserialization
   - Validation helpers

4. **QPayConfig** (`config/qpay_config.dart`)
   - Centralized configuration
   - Environment-based settings
   - Validation utilities

### Data Flow

```
Flutter App → QPayService → Backend Server → QPay API
     ↑                                           ↓
Firebase ←  Payment Monitoring  ←  Webhook  ←  QPay
```

## 🔧 API Reference

### QPayService Methods

#### `createInvoice(order, user, {expirationMinutes})`
Creates a new QPay invoice for payment.

**Parameters:**
- `order`: Order data with items and total amount
- `user`: User information (optional)
- `expirationMinutes`: Session timeout (default: 5 minutes)

**Returns:** `Future<QPayInvoiceResult>`

#### `checkPaymentStatus(invoiceId)`
Checks the current payment status of an invoice.

**Parameters:**
- `invoiceId`: QPay invoice ID

**Returns:** `Future<QPayPaymentStatus>`

#### `monitorPayment(invoiceId, {callbacks})`
Monitors payment status with callbacks for events.

**Parameters:**
- `invoiceId`: QPay invoice ID
- `onPaymentComplete`: Callback for successful payment
- `onSessionExpired`: Callback for session expiration
- `onTimeout`: Callback for monitoring timeout
- `onError`: Callback for errors

**Returns:** `Future<QPayMonitoringResult>`

#### `simulatePayment(invoiceId, amount)`
Simulates a payment for testing purposes.

**Parameters:**
- `invoiceId`: QPay invoice ID
- `amount`: Payment amount

**Returns:** `Future<Map<String, dynamic>>`

### Model Classes

#### `QPayInvoiceResult`
- `success`: Operation success status
- `invoiceId`: QPay invoice identifier
- `qrText`: QR code text for payment
- `qrDataURL`: Base64 encoded QR image
- `amount`: Invoice amount
- `expiresAt`: Session expiration time

#### `QPayPaymentStatus`
- `success`: Check success status
- `isPaid`: Payment completion status
- `isExpired`: Session expiration status
- `totalPaid`: Amount paid
- `paymentData`: Raw payment information

#### `QPayProduct`
- `name`: Product name
- `amount`: Price per unit
- `quantity`: Number of items

## 🎨 UI Integration

### Example Payment Screen

See `examples/qpay_example.dart` for a complete Flutter widget implementation:

```dart
class QPayPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic>? user;

  const QPayPaymentScreen({
    Key? key,
    required this.order,
    this.user,
  }) : super(key: key);

  @override
  State<QPayPaymentScreen> createState() => _QPayPaymentScreenState();
}
```

### QR Code Display

To display QR codes, add the `qr_flutter` package:

```dart
import 'package:qr_flutter/qr_flutter.dart';

QrImageView(
  data: invoiceResult.qrText,
  version: QrVersions.auto,
  size: 200.0,
)
```

## 🔧 Configuration

### Environment Variables

```bash
# QPay API Configuration
QPAY_MODE=production              # or 'sandbox'
QPAY_USERNAME=your_username
QPAY_PASSWORD=your_password
QPAY_TEMPLATE=your_template_code

# Server Configuration  
PORT=3000
QPAY_CALLBACK_URL=http://localhost:3000/qpay/callback

# Optional
QPAY_WEBHOOK_SECRET=your_secret
ENABLE_MOCK_PAYMENTS=false
ENABLE_DETAILED_LOGGING=false
```

### Runtime Configuration

```dart
// Check configuration
print(QPayConfig.summary);

// Validate settings
if (!QPayConfig.hasValidCredentials) {
  throw Exception('Invalid QPay credentials');
}

// Mode checking
if (QPayConfig.isProduction) {
  print('Running in production mode');
}
```

## 🧪 Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/services/qpay_service.dart';

void main() {
  group('QPayService Tests', () {
    test('should create valid invoice', () async {
      final order = createTestOrder();
      final user = createTestUser();
      
      final result = await QPayService.createInvoice(order, user);
      
      expect(result.success, true);
      expect(result.invoiceId, isNotNull);
      expect(result.amount, greaterThan(0));
    });
  });
}
```

### Integration Tests

```dart
// Test with mock server
await QPayService.simulatePayment(invoiceId, amount);
final status = await QPayService.checkPaymentStatus(invoiceId);
expect(status.isPaid, true);
```

## 🚨 Error Handling

### Common Error Patterns

```dart
try {
  final result = await QPayService.createInvoice(order, user);
  if (!result.success) {
    // Handle business logic errors
    showError('Invoice creation failed: ${result.error}');
    return;
  }
  // Process successful result
} on SocketException {
  // Handle network errors
  showError('Network connection failed');
} on TimeoutException {
  // Handle timeout errors
  showError('Request timed out');
} catch (error) {
  // Handle unexpected errors
  showError('Unexpected error: $error');
}
```

### Retry Logic

```dart
Future<QPayInvoiceResult> createInvoiceWithRetry(
  Map<String, dynamic> order,
  Map<String, dynamic>? user, {
  int maxRetries = 3,
}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await QPayService.createInvoice(order, user);
    } catch (error) {
      if (attempt == maxRetries) rethrow;
      await Future.delayed(Duration(seconds: attempt * 2));
    }
  }
  throw Exception('Max retries exceeded');
}
```

## 📊 Logging

The implementation includes comprehensive logging:

```dart
// Different log levels
AppLogger.info('Invoice creation started');
AppLogger.success('Payment completed successfully');
AppLogger.warning('Session will expire soon');
AppLogger.error('Payment failed', error);

// Specialized loggers
AppLogger.qpay('invoice', 'Creating invoice', {'orderId': 'ORDER_123'});
AppLogger.payment('paid', 'Payment successful', {'amount': 25.99});
AppLogger.network('POST', '/api/create-invoice', statusCode: 200);
```

## 🔒 Security Considerations

1. **API Keys**: Store QPay credentials securely
2. **SSL/TLS**: Always use HTTPS in production
3. **Webhook Validation**: Verify webhook signatures
4. **Session Management**: Implement proper session timeouts
5. **Data Validation**: Validate all input data

## 📋 Requirements

- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Backend QPay server running on localhost:3000
- Firebase project with Firestore enabled
- Valid QPay merchant account

## 🤝 Integration Checklist

- [ ] Add required dependencies to pubspec.yaml
- [ ] Configure QPay credentials
- [ ] Set up backend server
- [ ] Configure Firebase Firestore
- [ ] Implement error handling
- [ ] Add logging
- [ ] Test with sandbox environment
- [ ] Implement UI components
- [ ] Add payment monitoring
- [ ] Set up webhook handling
- [ ] Test end-to-end flow
- [ ] Deploy to production

## 📞 Support

For questions or issues:

1. Check the logging output for detailed error information
2. Verify backend server is running and accessible
3. Confirm QPay credentials are valid
4. Test with sandbox environment first
5. Review Firebase console for Firestore errors

## 🔄 Migration from JavaScript

This Dart implementation provides feature parity with the original JavaScript QPayService:

- ✅ Invoice creation with session management
- ✅ Payment status checking
- ✅ Firebase integration
- ✅ QR code generation
- ✅ Payment monitoring
- ✅ Error handling and logging
- ✅ Development testing tools

The API surface is nearly identical, making migration straightforward for existing users.
