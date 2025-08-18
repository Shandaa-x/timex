# Cloud Function Setup for FCM Notifications

## Current Status ✅
- **Real-time messaging**: Works when both users have the app open
- **FCM tokens**: Saved correctly to Firestore
- **Configuration**: Updated to use FCM API v1

## Push Notifications Status 🔄
Currently, notification requests are saved to Firestore but need a Cloud Function to actually send them.

## Option 1: Quick Test (Works immediately)
The app will work for real-time messaging when both users are online:
1. Both users open the app
2. Messages appear instantly
3. Local notifications show when app is in foreground

## Option 2: Full Push Notifications (Requires Cloud Function)

### Set up Firebase Cloud Functions:

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Functions:**
   ```bash
   cd timex
   firebase init functions
   ```

3. **Create the function:** (in `functions/index.js`)
   ```javascript
   const functions = require('firebase-functions');
   const admin = require('firebase-admin');
   admin.initializeApp();

   exports.sendNotification = functions.firestore
     .document('notification_requests/{docId}')
     .onCreate(async (snap, context) => {
       const data = snap.data();
       
       if (data.processed) return;
       
       const message = {
         token: data.to,
         notification: data.notification,
         data: data.data,
         android: data.android,
         apns: data.apns,
       };
       
       try {
         await admin.messaging().send(message);
         await snap.ref.update({ processed: true });
         console.log('Notification sent successfully');
       } catch (error) {
         console.error('Error sending notification:', error);
       }
     });
   ```

4. **Deploy:**
   ```bash
   firebase deploy --only functions
   ```

## Testing the Current Setup

1. **Hot restart** the app (both devices)
2. Send a message
3. Check console - you should see:
   ```
   ✅ Notification request created in Firestore
   ℹ️ A Cloud Function will process this and send the actual notification
   ```
4. The other user will see the message in real-time if their app is open

## What Works Now vs What Needs Cloud Functions

### ✅ Works Now:
- Real-time messaging when both users are online
- FCM token management
- Message history and chat rooms
- Local notifications when app is in foreground

### 🔄 Needs Cloud Function:
- Push notifications when receiver's app is closed
- Background notifications
- Notification badges

The chat system is fully functional for real-time messaging! Push notifications are just the final enhancement.
