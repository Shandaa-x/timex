# Payment Duplication Fix

## Problem Description
The `totalFoodAmount` field in the user document was being duplicated every time the app refreshed or the real-time listener was triggered.

## Root Cause
Two separate mechanisms were updating the `totalFoodAmount`:

1. **Manual Increment** (❌ REMOVED): In `food_eaten_status_widget.dart`, when food was marked as eaten:
   ```dart
   await _firestore.collection('users').doc(_userId).update({
     'totalFoodAmount': FieldValue.increment(totalPrice),
     'lastFoodUpdate': FieldValue.serverTimestamp(),
   });
   ```

2. **Real-time Recalculation** (✅ KEPT): In `RealtimeFoodTotalService`, listening to `eatens` collection:
   ```dart
   int totalFoodAmount = 0;
   for (final doc in snapshot.docs) {
     final data = doc.data() as Map<String, dynamic>?;
     if (data != null) {
       final price = data['totalPrice'] as int? ?? 0;
       totalFoodAmount += price;
     }
   }
   await _firestore.collection('users').doc(userId).update({
     'totalFoodAmount': totalFoodAmount,
     'lastFoodUpdate': FieldValue.serverTimestamp(),
   });
   ```

## The Issue
When the app refreshed:
1. The manual increment had already added the amount once
2. The real-time service recalculated from scratch, adding all amounts again
3. This resulted in duplication of amounts

## Solution Applied
Removed the manual increment from `food_eaten_status_widget.dart` and kept only the real-time service:

**Before:**
```dart
// Save to eatens subcollection
await _firestore.collection('users').doc(_userId).collection('eatens').doc(widget.dateString).set(eatenData);

// Manual increment (PROBLEMATIC)
await _firestore.collection('users').doc(_userId).update({
  'totalFoodAmount': FieldValue.increment(totalPrice),
  'lastFoodUpdate': FieldValue.serverTimestamp(),
});
```

**After:**
```dart
// Save to eatens subcollection
await _firestore.collection('users').doc(_userId).collection('eatens').doc(widget.dateString).set(eatenData);

// Note: totalFoodAmount will be automatically updated by RealtimeFoodTotalService
// when it detects changes in the eatens collection
```

## Benefits
- ✅ **Single Source of Truth**: Only `RealtimeFoodTotalService` manages `totalFoodAmount`
- ✅ **Consistent Calculation**: Total is always calculated from scratch
- ✅ **No Duplication**: Refreshing produces correct totals
- ✅ **Automatic Updates**: Real-time listener ensures immediate UI updates

## Files Modified
- `lib/screens/time_track/widgets/food_eaten_status_widget.dart`

## Testing
1. Mark food as eaten → Amount should be added to total
2. Refresh the app → Total should remain the same (not doubled)
3. Add more food → Total should increase correctly
4. Real-time updates should work seamlessly across app instances
