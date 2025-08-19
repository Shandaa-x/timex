const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

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
    console.log('   Title:', message.notification?.title);
    console.log('   Body:', message.notification?.body);
    
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

// Optional: Cloud Function to clean up old notification requests
exports.cleanupNotificationRequests = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('🧹 Cleaning up old notification requests...');
    
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago
    const batch = admin.firestore().batch();
    
    try {
      const oldRequests = await admin.firestore()
        .collection('notification_requests')
        .where('timestamp', '<', cutoff)
        .limit(500)
        .get();
      
      if (oldRequests.empty) {
        console.log('✅ No old notification requests to clean up');
        return null;
      }
      
      oldRequests.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`✅ Cleaned up ${oldRequests.docs.length} old notification requests`);
      
    } catch (error) {
      console.error('❌ Error cleaning up notification requests:', error);
    }
    
    return null;
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

// Cloud Function specifically for chat notifications
exports.sendChatNotification = functions.https.onRequest(async (req, res) => {
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
    console.log('💬 Received chat notification request:', req.body);
    
    const { token, title, body, chatRoomId, senderName, senderPhotoURL } = req.body;
    
    if (!token || !title || !body) {
      console.error('❌ Invalid request: missing required fields');
      res.status(400).json({ error: 'Invalid request: missing token, title, or body' });
      return;
    }
    
    console.log('🔔 Sending real-time chat notification...');
    console.log('   Token:', token.substring(0, 20) + '...');
    console.log('   Title:', title);
    console.log('   Body:', body);
    console.log('   Chat Room:', chatRoomId);
    
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        chatRoomId: chatRoomId || '',
        senderName: senderName || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: 'chat_message'
      },
      android: {
        notification: {
          channelId: 'chat_messages',
          priority: 'high',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 1,
            sound: 'default',
            category: 'CHAT_MESSAGE',
          },
        },
      },
    };
    
    // Send the message using Firebase Admin SDK
    const response = await admin.messaging().send(message);
    
    console.log('✅ Real-time chat notification sent successfully:', response);
    res.status(200).json({ 
      success: true, 
      messageId: response,
      timestamp: new Date().toISOString(),
      chatRoomId: chatRoomId
    });
    
  } catch (error) {
    console.error('❌ Error sending chat notification:', error);
    
    let errorMessage = 'Unknown error';
    let statusCode = 500;
    
    if (error.code === 'messaging/invalid-registration-token') {
      errorMessage = 'Invalid FCM token';
      statusCode = 400;
    } else if (error.code === 'messaging/registration-token-not-registered') {
      errorMessage = 'FCM token not registered';
      statusCode = 404;
    } else {
      errorMessage = error.message || errorMessage;
    }
    
    res.status(statusCode).json({ 
      error: errorMessage,
      code: error.code,
      timestamp: new Date().toISOString()
    });
  }
});

// Firestore trigger for FCM requests (fallback method)
exports.processFCMRequest = functions.firestore
  .document('fcm_requests/{requestId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      console.log('🔔 Processing FCM request from Firestore:', data);
      
      if (data.processed) {
        console.log('⚠️ Request already processed, skipping...');
        return;
      }
      
      const message = {
        token: data.to,
        notification: data.notification,
        data: data.data || {},
        android: data.android || {},
        apns: data.apns || {},
      };
      
      console.log('📤 Sending FCM via Firestore trigger...');
      const response = await admin.messaging().send(message);
      
      // Mark as processed
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response
      });
      
      console.log('✅ FCM sent via Firestore trigger:', response);
      
    } catch (error) {
      console.error('❌ Error in Firestore FCM trigger:', error);
      
      // Mark as failed
      await snap.ref.update({
        processed: true,
        failed: true,
        error: error.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
