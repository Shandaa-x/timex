# timex

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## QPay Configuration

This project includes QPay payment integration. To configure QPay:

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in your QPay credentials in the `.env` file:
   ```
   QPAY_MODE=production
   QPAY_URL=https://merchant.qpay.mn/v2
   QPAY_USERNAME=your_username_here
   QPAY_PASSWORD=your_password_here
   QPAY_TEMPLATE=your_template_here
   # ... other configurations
   ```

3. The `.env` file is already added to `.gitignore` to prevent committing sensitive credentials.

4. Environment variables are loaded automatically when the app starts.

### QPay Features Available

- **Authentication**: Automatic access token management
- **Invoice Creation**: Create invoices for single or multiple products
- **Payment Checking**: Monitor payment status
- **QR Code Generation**: Generate QR codes for payments
- **Error Handling**: Comprehensive error handling and logging

### Usage Example

```dart
import 'package:timex/services/qpay_helper.dart';
import 'package:timex/models/qpay_models.dart';

// Create products
List<QPayProduct> products = [
  QPayProduct(name: 'Product 1', amount: 10.0, quantity: 1),
  QPayProduct(name: 'Product 2', amount: 20.0, quantity: 2),
];

// Create invoice with QR code
QPayInvoiceResult result = await QPayHelper.createInvoiceWithQR(
  products,
  'ORDER_123',
  'user_id',
);

if (result.success) {
  print('Invoice created: ${result.invoiceId}');
  print('QR Text: ${result.qrText}');
} else {
  print('Error: ${result.error}');
}
```

## Environment Variables

The following environment variables are used:

- `QPAY_MODE`: Set to 'production' or 'sandbox'
- `QPAY_URL`: QPay API URL for production
- `QPAY_TEST_URL`: QPay API URL for testing
- `QPAY_USERNAME`: Your QPay username
- `QPAY_PASSWORD`: Your QPay password
- `QPAY_TEMPLATE`: Your QPay invoice template
- `QPAY_CALLBACK_URL`: Callback URL for payment notifications
- `PORT`: Server port (default: 3000)
- `API_KEY`: Your API key for authentication

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
