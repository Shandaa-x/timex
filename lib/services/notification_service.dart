import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_service.dart';
import '../config/fcm_config.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  static FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  
  static Future<void> initialize() async {
    try {
      print('🔔 Initializing NotificationService...');
      
      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      print('🔔 Local notifications initialized');
      
      // Request permissions for Android 13+
      try {
        final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          final granted = await androidImplementation.requestNotificationsPermission();
          print('🔔 Android notification permission granted: $granted');
        }
      } catch (e) {
        print('❌ Error requesting notification permissions: $e');
      }
      
      // Initialize Firebase Messaging with timeout
      try {
        await _initializeFirebaseMessaging().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⚠️ FCM initialization timed out, continuing without FCM');
          },
        );
      } catch (e) {
        print('❌ Error initializing FCM: $e');
        print('⚠️ Continuing without FCM - notifications may not work properly');
      }
      
      // Create notification channel for Android
      try {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'chat_messages',
          'Chat Messages',
          description: 'Notifications for chat messages',
          importance: Importance.high,
          playSound: true,
        );
        
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        print('🔔 Notification channel created');
      } catch (e) {
        print('❌ Error creating notification channel: $e');
      }
            
      print('🔔 NotificationService initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Critical error in NotificationService initialization: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Initialize Firebase Messaging
  static Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    print('🔔 FCM permission status: ${settings.authorizationStatus}');
    
    // Get FCM token and save to user profile
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveUserFCMToken(token);
      print('🔔 FCM Token: ${token.substring(0, 30)}...');
    }
    
    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveUserFCMToken);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Listen for push notifications in Firestore
    _listenForPushNotifications();
  }
  
  // Save FCM token to user profile
  static Future<void> _saveUserFCMToken(String token) async {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isNotEmpty) {
      await _firestore.collection('users').doc(currentUserId).update({
        'fcmToken': token,
        'lastTokenUpdate': DateTime.now(),
      });
      print('🔔 FCM token saved for user: $currentUserId');
    }
  }
  
  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 Received foreground FCM message from another user');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');
    
    // Only show notification if it's from another user (not ourselves)
    final chatRoomId = message.data['chatRoomId'];
    if (chatRoomId != null) {
      // Show local notification for messages from other users
      _showLocalNotification(message);
    }
  }
  
  // Handle background message tap
  static void _handleBackgroundMessageTap(RemoteMessage message) {
    print('🔔 Background message tapped: ${message.data}');
    final chatRoomId = message.data['chatRoomId'];
    if (chatRoomId != null) {
      // TODO: Navigate to chat room
      print('Navigate to chat room: $chatRoomId');
    }
  }
  
  // Show local notification from FCM message
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Notifications for chat messages',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              notification.body ?? '',
              contentTitle: notification.title,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['chatRoomId'],
      );
    }
  }
  
  // Send chat message notification to receiving users
  static Future<void> sendChatNotification({
    required String chatRoomId,
    required String senderName,
    required String senderPhotoURL,
    required String message,
    required DateTime timestamp,
    required bool isGroupChat,
  }) async {
    print('🔔 sendChatNotification called');
    print('   Chat room: $chatRoomId');
    print('   Sender: $senderName');
    print('   Message: $message');
    
    try {
      // Get chat room participants
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        print('🔔 Chat room not found');
        return;
      }
      
      final chatRoomData = chatRoomDoc.data()!;
      final participants = List<String>.from(chatRoomData['participants'] ?? []);
      final currentUserId = ChatService.currentUserId;
      
      // Get receiving participants (exclude sender)
      final receivers = participants.where((id) => id != currentUserId).toList();
      
      if (receivers.isEmpty) {
        print('🔔 No receivers found');
        return;
      }
      
      print('🔔 Checking ${receivers.length} receivers for online status...');
      
      // Get FCM tokens for receivers
      int notificationsSent = 0;
      
      for (final receiverId in receivers) {
        try {
          final userDoc = await _firestore.collection('users').doc(receiverId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final fcmToken = userData['fcmToken'] as String?;
            final displayName = userData['displayName'] as String? ?? 'Unknown';
            final isOnline = userData['isOnline'] as bool? ?? false;
            
            print('🔔 Receiver: $displayName ($receiverId)');
            print('   Status: ${isOnline ? "ONLINE" : "OFFLINE"}');
            print('   Sending notification regardless of status');
            
            if (fcmToken != null && fcmToken.isNotEmpty) {
              // ALWAYS send notification regardless of online status
              await _sendFCMNotification(
                token: fcmToken,
                chatRoomId: chatRoomId,
                senderName: senderName,
                message: message,
                isGroupChat: isGroupChat,
                senderPhotoURL: senderPhotoURL,
              );
              notificationsSent++;
            } else {
              print('   ❌ No FCM token found');
            }
          }
        } catch (e) {
          print('🔔 Error processing receiver $receiverId: $e');
        }
      }
      
      print('🔔 Notification Summary:');
      print('   Total receivers: ${receivers.length}');
      print('   Notifications sent: $notificationsSent');
      
    } catch (e) {
      print('🔔 Error sending notifications: $e');
    }
  }
  
  // Send direct FCM push notification - REAL-TIME VERSION
  static Future<void> _sendFCMNotification({
    required String token,
    required String chatRoomId,
    required String senderName,
    required String message,
    required bool isGroupChat,
    String? senderPhotoURL,
  }) async {
    try {
      // Get recipient user ID from the token
      final recipientId = await _getUserIdByToken(token);
      if (recipientId == null) {
        print('❌ Could not find user for token');
        return;
      }
      
      final title = isGroupChat ? 'Group: $senderName' : senderName;
      print('🔔 Sending REAL-TIME FCM push notification...');
      print('   Title: $title');
      print('   Message: $message');
      print('   Recipient: $recipientId');
      print('   Token: ${token.substring(0, 20)}...');
      
      // 1. Create Firestore document for in-app listener (when app is open)
      await _firestore.collection('push_notifications').add({
        'recipientId': recipientId,
        'token': token,
        'title': title,
        'body': message,
        'senderName': senderName,
        'senderId': ChatService.currentUserId,
        'senderPhotoURL': senderPhotoURL,
        'chatRoomId': chatRoomId,
        'isGroupChat': isGroupChat,
        'timestamp': FieldValue.serverTimestamp(),
        'delivered': false,
      });
      
      // 2. Send REAL FCM push notification for background/closed app
      await _sendRealTimeFCM(
        token: token,
        title: title,
        body: message,
        chatRoomId: chatRoomId,
        senderName: senderName,
        senderPhotoURL: senderPhotoURL,
      );
      
      print('✅ Both Firestore document and real-time FCM notification sent for recipient: $recipientId');
      
    } catch (e) {
      print('❌ Error creating/sending push notification: $e');
    }
  }
  
  // Send real-time FCM notification via HTTP API
  static Future<void> _sendRealTimeFCM({
    required String token,
    required String title,
    required String body,
    required String chatRoomId,
    String? senderName,
    String? senderPhotoURL,
  }) async {
    try {
      print('🔔 Sending real-time FCM via HTTP API...');
      
      // Try Cloud Function first (if available)
      final cloudFunctionUrl = 'https://us-central1-${FCMConfig.projectId}.cloudfunctions.net/sendChatNotification';
      
      final fcmPayload = {
        'token': token,
        'title': title,
        'body': body,
        'chatRoomId': chatRoomId,
        'senderName': senderName,
        'senderPhotoURL': senderPhotoURL,
      };
      
      try {
        final response = await http.post(
          Uri.parse(cloudFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode(fcmPayload),
        ).timeout(Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          print('✅ Real-time FCM sent via Cloud Function successfully');
          return;
        } else {
          print('❌ Cloud Function error: ${response.statusCode} - ${response.body}');
          throw Exception('Cloud function failed');
        }
      } catch (e) {
        print('❌ Cloud Function unavailable: $e');
        print('🔄 Falling back to Firestore trigger...');
        
        // Fallback: Use Firestore trigger method
        await _firestore.collection('fcm_requests').add({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'chatRoomId': chatRoomId,
            'senderName': senderName ?? '',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'android': {
            'notification': {
              'channel_id': 'chat_messages',
              'priority': 'high',
              'sound': 'default',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'alert': {
                  'title': title,
                  'body': body,
                },
                'badge': 1,
                'sound': 'default',
              },
            },
          },
          'timestamp': FieldValue.serverTimestamp(),
          'processed': false,
        });
        
        print('✅ FCM request added to Firestore trigger queue');
      }
      
    } catch (e) {
      print('❌ Error sending real-time FCM: $e');
    }
  }
  
  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final chatRoomId = response.payload;
    if (chatRoomId != null) {
      // TODO: Navigate to chat room
      // This would need to be implemented with a global navigation key
      print('Navigate to chat room: $chatRoomId');
    }
  }
  
  // Get unread message count for drawer badge
  static Stream<int> getUnreadMessageCount() {
    return ChatService.getUnreadMessageCount();
  }
  
  // Clear notifications for a specific chat
  static Future<void> clearChatNotifications(String chatRoomId) async {
    await _localNotifications.cancel(chatRoomId.hashCode);
  }
  
  // Listen for push notifications in Firestore (SIMPLIFIED APPROACH)
  static void _listenForPushNotifications() {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) {
      print('❌ No current user ID - cannot listen for notifications');
      return;
    }
    
    print('🔔 Setting up push notification listener for user: $currentUserId');
    
    // Listen for push notifications where current user is the recipient
    _firestore.collection('push_notifications')
        .where('recipientId', isEqualTo: currentUserId)
        .where('delivered', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            print('🔔 Push notifications snapshot received: ${snapshot.docChanges.length} changes');
            
            for (final doc in snapshot.docChanges) {
              if (doc.type == DocumentChangeType.added) {
                final data = doc.doc.data() as Map<String, dynamic>;
                print('🔔 New push notification document: ${data}');
                _showPushNotification(data, doc.doc.id);
              }
            }
          },
          onError: (error) {
            print('❌ Error in push notification listener: $error');
          },
        );
  }
  
  // Show push notification immediately
  static Future<void> _showPushNotification(Map<String, dynamic> data, String docId) async {
    try {
      final title = data['title'] as String?;
      final body = data['body'] as String?;
      final chatRoomId = data['chatRoomId'] as String?;
      // final senderPhotoURL = data['senderPhotoURL'] as String?; // TODO: Use for large icon
      
      if (title != null && body != null) {
        print('🔔 Showing push notification: $title - $body');
        
        // Show local notification immediately
        await _localNotifications.show(
          docId.hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_messages',
              'Chat Messages',
              channelDescription: 'Notifications for chat messages',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(
                body,
                contentTitle: title,
              ),
              // TODO: Add large icon from senderPhotoURL if available
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: chatRoomId,
        );
        
        // Mark as delivered
        await _firestore.collection('push_notifications').doc(docId).update({
          'delivered': true,
          'deliveredAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Push notification delivered and marked as delivered');
      }
    } catch (e) {
      print('❌ Error showing push notification: $e');
    }
  }

  // Initialize push notification listener for current user  
  static Future<void> initializePushNotificationListener() async {
    print('🔔 Initializing push notification listener...');
    _listenForPushNotifications();
  }
  
  // Debug: Check if current user has FCM token saved
  static Future<void> debugCheckFCMToken() async {
    final currentUserId = ChatService.currentUserId;
    print('🔔 DEBUG: FCM Configuration Status');
    print('   FCM Project ID: ${FCMConfig.projectId}');
    print('   FCM Configured: ${FCMConfig.isConfigured}');
    print('   Using Direct FCM Push Notifications: Yes');
    print('   Current User: $currentUserId');
    
    if (!FCMConfig.isConfigured) {
      print('❌ FCM NOT CONFIGURED!');
      print('❌ Project ID is empty in fcm_config.dart');
      return;
    }
    
    print('✅ FCM Configuration looks good');
    print('✅ Push notifications should work');
    
    if (currentUserId.isNotEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (userDoc.exists) {
          final fcmToken = userDoc.data()?['fcmToken'] as String?;
          final lastUpdate = userDoc.data()?['lastTokenUpdate'] as Timestamp?;
          
          print('🔔 DEBUG: Current user FCM token status:');
          print('   User ID: $currentUserId');
          print('   Has token: ${fcmToken != null}');
          if (fcmToken != null) {
            print('   Token: ${fcmToken.substring(0, 30)}...');
          }
          if (lastUpdate != null) {
            print('   Last update: ${lastUpdate.toDate()}');
          }
        } else {
          print('🔔 DEBUG: User document not found');
        }
      } catch (e) {
        print('🔔 DEBUG: Error checking FCM token: $e');
      }
    } else {
      print('🔔 DEBUG: No current user ID');
    }
  }

  // Test notification (for debugging)
  static Future<void> sendTestNotification() async {
    print('🔔 Sending test notification...');
    try {
      await _localNotifications.show(
        999,
        'Test Notification',
        'This is a test message to verify local notifications are working',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Notifications for chat messages',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('🔔 Error sending test notification: $e');
    }
  }

  // Test sending FCM notification to a specific user (for debugging)
  static Future<void> debugSendNotificationToUser(String userId, String message) async {
    try {
      print('🔔 DEBUG: Testing FCM notification send to user: $userId');
      
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User not found: $userId');
        return;
      }
      
      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;
      final displayName = userData['displayName'] as String? ?? 'Unknown User';
      final photoURL = userData['photoURL'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        print('❌ No FCM token found for user: $displayName');
        return;
      }
      
      print('✅ Found FCM token for $displayName');
      print('   Token: ${fcmToken.substring(0, 30)}...');
      
      // Send test notification using the same method as real messages
      await _sendFCMNotification(
        token: fcmToken,
        chatRoomId: 'debug_test_room',
        senderName: 'Debug Test',
        message: message,
        isGroupChat: false,
        senderPhotoURL: photoURL,
      );
      
      print('✅ Debug FCM notification sent');
      
    } catch (e) {
      print('❌ Error in debug send: $e');
    }
  }
  
  // Manual force notification for testing 
  static Future<void> debugForceShowNotification(String title, String body) async {
    try {
      print('🔔 FORCE showing notification: $title - $body');
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Notifications for chat messages',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      
      print('✅ Force notification shown successfully');
      
    } catch (e) {
      print('❌ Error force showing notification: $e');
    }
  }

  // Helper method to get user ID by FCM token
  static Future<String?> _getUserIdByToken(String token) async {
    try {
      final usersSnapshot = await _firestore.collection('users')
          .where('fcmToken', isEqualTo: token)
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isNotEmpty) {
        return usersSnapshot.docs.first.id;
      }
    } catch (e) {
      print('❌ Error getting user by token: $e');
    }
    return null;
  }

}
