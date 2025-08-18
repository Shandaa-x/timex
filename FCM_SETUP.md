# FCM Configuration Guide - URGENT FIX FOR NOTIFICATIONS

## 🚨 The Problem
Currently, notifications are showing on the **sender's device** instead of the **receiver's device** because FCM is not configured.

## 🚀 Quick Fix (5 minutes)

### Step 1: Get Your FCM Server Key
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **timex** project
3. Click the ⚙️ gear icon → **"Project settings"**
4. Go to **"Cloud Messaging"** tab
5. Scroll down to **"Cloud Messaging API (Legacy)"**
6. Copy the **"Server key"** (starts with `AAAA...`)

### Step 2: Configure the App
1. Open `lib/config/fcm_config.dart`
2. Replace this line:
   ```dart
   static const String serverKey = 'AAAA...'; // Your server key here
   ```
   
   With your actual server key:
   ```dart
   static const String serverKey = 'AAAAxyz123:APA91bF...your-actual-server-key-here';
   ```

3. Save the file
4. **Hot restart** the app (not hot reload)

### Step 3: Test
1. Open the app on **two different devices/emulators**
2. Log in with different users on each device
3. Send a message from one device
4. The **OTHER device** should receive the notification ✅

## 🧪 Debugging Tools
- Use the notification icon in the chat screen to debug
- Check the console output for FCM status
- The debug will show if tokens are saved correctly

## ⚠️ Important Notes
- **Hot restart** required after changing FCM config
- Both devices need internet connection
- Notifications work even when receiver app is in background
- Test on real devices for best results

## 🔧 If Still Not Working
1. Check Firebase Console logs
2. Verify Cloud Messaging is enabled
3. Make sure both users have FCM tokens saved
4. Check device notification permissions
