const {setGlobalOptions} = require("firebase-functions");
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

// Cloud Function to send FCM notifications
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    console.log('📱 Received notification request:', req.body);
    
    const { message } = req.body;
    
    if (!message || !message.token) {
      console.error('❌ Invalid request: missing message or token');
      res.status(400).json({ error: 'Invalid request: missing message or token' });
      return;
    }
    
    console.log('🔔 Sending FCM notification...');
    console.log('   Token:', message.token.substring(0, 20) + '...');
    console.log('   Title:', message.notification && message.notification.title);
    console.log('   Body:', message.notification && message.notification.body);
    
    // Send the message using Firebase Admin SDK
    const response = await admin.messaging().send(message);
    
    console.log('✅ FCM notification sent successfully:', response);
    res.status(200).json({ 
      success: true, 
      messageId: response,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
    
    let errorMessage = 'Unknown error';
    let statusCode = 500;
    
    if (error.code === 'messaging/invalid-registration-token') {
      errorMessage = 'Invalid FCM token';
      statusCode = 400;
    } else if (error.code === 'messaging/registration-token-not-registered') {
      errorMessage = 'FCM token not registered';
      statusCode = 400;
    } else if (error.code === 'messaging/invalid-argument') {
      errorMessage = 'Invalid FCM message format';
      statusCode = 400;
    }
    
    res.status(statusCode).json({ 
      error: errorMessage,
      code: error.code,
      details: error.message
    });
  }
});

// Firestore trigger to send notifications when documents are added
exports.sendNotificationOnCreate = functions.firestore
  .document('notification_requests/{docId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      console.log('🔔 New notification request created:', data);
      
      if (!data.to || !data.notification) {
        console.error('❌ Invalid notification request: missing required fields');
        return;
      }
      
      const message = {
        token: data.to,
        notification: data.notification,
        data: data.data || {},
        android: data.android || {},
        apns: data.apns || {}
      };
      
      console.log('📱 Sending FCM via Firestore trigger...');
      const response = await admin.messaging().send(message);
      
      // Mark as processed
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmResponse: response
      });
      
      console.log('✅ Notification sent via Firestore trigger:', response);
      
    } catch (error) {
      console.error('❌ Error in Firestore trigger:', error);
      
      // Mark as failed
      await snap.ref.update({
        processed: true,
        failed: true,
        error: error.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
