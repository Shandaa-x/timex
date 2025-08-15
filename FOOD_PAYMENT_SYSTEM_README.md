# Food Payment System

A comprehensive Flutter/Dart food payment tracking system with Firebase Firestore integration. This system allows users to track individual food items, make partial payments, and view payment history with advanced UI features.

## Features

### 🍔 Individual Food Tracking
- Add individual food items with photos and prices
- Track payment status per food item
- Base64 image encoding for storage
- Real-time status updates

### 💰 Payment Processing
- Process payments for multiple food items
- Support for partial payments
- Multiple payment methods (QPay, Card, Cash, Bank Transfer)
- Automatic payment distribution across selected foods
- Invoice ID tracking

### 📊 Advanced UI
- Beautiful food item cards with images
- Progress bars showing payment completion
- Selection mode for batch operations
- Real-time payment summaries
- Payment history with transaction details

### 🔄 Real-time Updates
- Firebase Firestore streams for live data
- Automatic UI updates when payments are made
- Cross-device synchronization

## Architecture

### Models (`lib/models/food_payment_models.dart`)
```dart
// Core data models
- FoodItem: Individual food item with payment tracking
- PaymentTransaction: Payment record with timestamp and method
- PaymentSummary: Aggregated payment statistics
- PaymentResult: Result of payment operations
```

### Services (`lib/services/food_payment_service.dart`)
```dart
// Core business logic
- addFoodItem(): Add new food items
- processPayment(): Handle payment processing
- getFoodItemsStream(): Real-time data streams
- getAllFoodItems(): Fetch all food data
```

### Widgets
- **FoodPaymentHistoryWidget**: Display food items with selection
- **FoodSelectionWidget**: Add new foods with camera integration
- **FoodPaymentProcessorWidget**: Process payments for selected foods
- **FoodManagementScreen**: Main screen with tabs and navigation

## Firebase Structure

```
users/{userId}/foods/{foodId}
├── id: string
├── name: string
├── totalPrice: number
├── paidAmount: number
├── imageBase64: string
├── selectedDate: timestamp
├── status: enum('unpaid', 'partiallyPaid', 'fullyPaid')
├── paymentHistory: array
│   ├── amount: number
│   ├── timestamp: timestamp
│   ├── method: string
│   └── invoiceId?: string
└── metadata: object
```

## Usage Examples

### 1. Basic Integration

```dart
// Add to your main app
import 'package:flutter/material.dart';
import 'lib/screens/food_management_screen.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food App',
      home: FoodManagementScreen(), // Full food management
    );
  }
}
```

### 2. Dashboard Widget

```dart
// Add payment stats to your dashboard
import 'lib/widgets/food_payment_history_widget.dart';

Widget buildDashboard() {
  return Column(
    children: [
      PaymentStatsWidget(), // Shows payment overview
      // ... other dashboard widgets
    ],
  );
}
```

### 3. Add Food Dialog

```dart
// Show add food dialog
import 'lib/widgets/food_selection_widget.dart';

void showAddFoodDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: FoodSelectionWidget(
        onFoodAdded: (food) {
          print('Added: ${food.name}');
          Navigator.pop(context);
        },
      ),
    ),
  );
}
```

### 4. Payment Processing

```dart
// Process payments for selected foods
import 'lib/widgets/food_payment_processor_widget.dart';

void processPayment(List<String> foodIds) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FoodPaymentProcessorWidget(
        selectedFoodIds: foodIds,
        onPaymentCompleted: (result) {
          print('Payment result: ${result.message}');
        },
      ),
    ),
  );
}
```

## Key Features Explained

### Individual Food Tracking
Each food item is tracked separately with:
- Unique ID and name
- Total price and paid amount
- Payment status (unpaid, partially paid, fully paid)
- Base64 encoded image
- Complete payment history

### Payment Distribution Logic
When making a payment for multiple foods:
1. Foods are sorted by selection date (oldest first)
2. Payment amount is distributed sequentially
3. Each food is paid up to its remaining balance
4. Transaction records are created for each food
5. Payment status is updated automatically

### Image Handling
- Camera integration for food photos
- Base64 encoding for Firestore storage
- Efficient image display with caching
- Fallback placeholder for missing images

### Real-time Updates
- Firebase streams provide live data
- UI updates automatically when payments are made
- Cross-device synchronization
- Offline support with Firebase cache

## Installation

1. **Add Dependencies** (pubspec.yaml):
```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^4.13.6
  firebase_core: ^2.24.2
  image_picker: ^1.0.4
```

2. **Configure Firebase**:
   - Add Firebase project
   - Add google-services.json (Android)
   - Add GoogleService-Info.plist (iOS)
   - Initialize Firebase in main.dart

3. **Setup Firestore Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/foods/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## File Structure

```
lib/
├── models/
│   └── food_payment_models.dart      # Data models
├── services/
│   ├── food_payment_service.dart     # Business logic
│   └── money_format.dart             # Currency formatting
├── widgets/
│   ├── food_payment_history_widget.dart    # History display
│   ├── food_selection_widget.dart          # Add new foods
│   └── food_payment_processor_widget.dart  # Payment processing
├── screens/
│   └── food_management_screen.dart   # Main screen
└── examples/
    └── food_payment_system_demo.dart # Usage examples
```

## Payment Methods Supported

- **QPay**: Mobile payment integration
- **Card**: Credit/debit card payments
- **Cash**: Cash payment tracking
- **Bank Transfer**: Bank transfer records

## Error Handling

The system includes comprehensive error handling:
- Network connectivity issues
- Firebase permission errors
- Invalid payment amounts
- Image processing errors
- Data validation errors

## Performance Considerations

- Lazy loading for large food lists
- Image compression for Base64 storage
- Efficient Firebase queries with pagination
- Local caching for offline support
- Optimized UI updates with streams

## Security Features

- User-based data isolation
- Firebase security rules
- Input validation
- Secure image handling
- Payment validation

## Testing

Example test file structure:
```dart
test/
├── models/
│   └── food_payment_models_test.dart
├── services/
│   └── food_payment_service_test.dart
└── widgets/
    └── food_payment_widgets_test.dart
```

## Contributing

1. Follow Flutter best practices
2. Add tests for new features
3. Update documentation
4. Follow the existing code style
5. Test on both Android and iOS

## License

[Your License Here]

---

## Quick Start Checklist

- [ ] Add Firebase dependencies
- [ ] Configure Firebase project
- [ ] Setup Firestore security rules
- [ ] Import food payment models
- [ ] Import food payment service
- [ ] Add food management screen to routes
- [ ] Test add food functionality
- [ ] Test payment processing
- [ ] Verify real-time updates

For detailed implementation examples, see `lib/examples/food_payment_system_demo.dart`.
