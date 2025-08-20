# FCM Push Notifications Setup Guide

## Current Status
Your notification system has been updated to use **direct FCM push notifications** instead of the previous Firestore-based approach. This will ensure that notifications actually reach users' phones.

## What Changed
1. **Removed complex Firestore notification system** - No more saving notifications to database
2. **Added direct FCM HTTP API calls** - Real push notifications to devices  
3. **Created Firebase Cloud Functions** - To send FCM messages from server
4. **Simplified notification flow** - Just send notification with user image, name, and text

## Setup Steps

### 1. Deploy Firebase Cloud Functions

First, install Firebase CLI if you haven't already:
```bash
npm install -g firebase-tools
```

Navigate to your project root and initialize Firebase (if not done):
```bash
cd c:\Users\Labs1\Documents\xlab\timex
firebase login
firebase init functions
# Choose your existing project: timex-9ce03
```

Install function dependencies:
```bash
cd functions
npm install
```

Deploy the functions:
```bash
firebase deploy --only functions
```

### 2. Test the Setup

Add these debug calls to your app to test notifications:

```dart
// Test local notification
await NotificationService.sendTestNotification();

// Test FCM token status
await NotificationService.debugCheckFCMToken();

// Test sending to specific user (replace USER_ID)
await NotificationService.debugSendNotificationToUser('USER_ID', 'Test message');
```

### 3. Verify Cloud Functions

After deployment, your functions will be available at:
- https://us-central1-timex-9ce03.cloudfunctions.net/sendNotification
- https://us-central1-timex-9ce03.cloudfunctions.net/sendNotificationOnCreate

## How It Works Now

1. **User sends message** → `NotificationService.sendChatNotification()` called
2. **Check recipients** → Get FCM tokens for offline users  
3. **Send FCM notification** → Call Cloud Function to send push notification
4. **User receives push** → Notification appears on their phone immediately

## Key Features

✅ **Real push notifications** - Actually reach users' phones  
✅ **User profile images** - Shows sender's photo in notification  
✅ **Smart online detection** - Skip notifications for active users  
✅ **Group chat support** - Different notification titles for groups  
✅ **Cross-platform** - Works on Android and iOS  
✅ **No database bloat** - Doesn't save notification data  

## Testing

1. Send a message from User A to User B
2. User B should receive push notification on their phone
3. Check logs for "✅ FCM push notification sent successfully"
4. Verify notification appears with sender's name and profile image

## Troubleshooting

- **No notifications received**: Check FCM tokens are saved in user documents
- **Cloud function errors**: Check Firebase Functions logs
- **Token issues**: Call `debugCheckFCMToken()` to verify setup
- **Online users**: Notifications skipped for online users (can be disabled)

## Next Steps

1. Deploy the cloud functions using the commands above
2. Test with real devices 
3. Customize notification appearance as needed
4. Remove debug methods in production
