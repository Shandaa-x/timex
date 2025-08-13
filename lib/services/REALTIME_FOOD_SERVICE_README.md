# Real-time Food Total Service

## Overview
The `RealtimeFoodTotalService` automatically calculates and updates the total food amount consumed by a user in real-time. This service listens to changes in the `eatens` subcollection and updates the `totalFoodAmount` field in the user's document.

## How it works

### 1. Service Initialization
- The service starts when the user logs in and navigates to the main screen
- It listens to all changes in the `users/{userId}/eatens` collection
- When any document is added, updated, or deleted, it recalculates the total

### 2. Real-time Calculation
```dart
// Service automatically:
1. Listens to eatens collection changes
2. Sums all `totalPrice` fields from all documents  
3. Updates `totalFoodAmount` in the user's document
4. Updates `lastFoodUpdate` timestamp
```

### 3. Data Flow
```
Food Consumption → Save to eatens/{date} → Real-time Listener → Calculate Sum → Update users/totalFoodAmount
```

### 4. UI Updates
The `FoodReportScreen` displays:
- **Төлөх дүн** (Amount to Pay): Shows `totalFoodAmount` from users collection
- **Төлбөрийн үлдэгдэл** (Payment Balance): `totalPaymentsMade - totalFoodAmount`
- **Нийт төлбөр** (Total Payment): Shows `totalPaymentsMade` from users collection

### 5. Example Data Structure

#### Users Collection
```json
{
  "users": {
    "userId123": {
      "totalFoodAmount": 25000,      // Auto-calculated sum of all eatens
      "totalPaymentsMade": 0,        // Manual payments made
      "lastFoodUpdate": "timestamp"
    }
  }
}
```

#### Eatens Subcollection
```json
{
  "users": {
    "userId123": {
      "eatens": {
        "2025-08-13": {
          "totalPrice": 25000,
          "foodCount": 2,
          "foods": [...],
          "eatenAt": "timestamp"
        },
        "2025-08-14": {
          "totalPrice": 15000,
          "foodCount": 1,
          "foods": [...],
          "eatenAt": "timestamp"
        }
      }
    }
  }
}
```

In this example, `totalFoodAmount` would be automatically updated to 40000 (25000 + 15000).

### 6. Real-time Updates
- ✅ Automatically updates when new food is consumed
- ✅ Updates when existing food consumption is modified
- ✅ Updates when food consumption is deleted
- ✅ UI shows changes immediately without refresh
- ✅ Works across multiple app instances

### 7. Performance
- Uses Firestore listeners for real-time updates
- Only listens to user's own data
- Automatically cleans up listeners when user logs out
- Minimal data transfer (only changed documents)
