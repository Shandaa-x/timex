import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          const Duration(seconds: 5),
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
      print('🔔 FCM Token: $token');
    }
    
    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveUserFCMToken);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Listen for notification requests in Firestore (for real-time notifications)
    _listenForNotificationRequests();
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
      
      // Get FCM tokens for receivers and check online status
      int notificationsSent = 0;
      int onlineUsers = 0;
      
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
            
            if (fcmToken != null && fcmToken.isNotEmpty) {
              if (isOnline) {
                onlineUsers++;
                print('   ⚠️ User is online - skipping notification');
              } else {
                await _sendFCMNotification(
                  token: fcmToken,
                  chatRoomId: chatRoomId,
                  senderName: senderName,
                  message: message,
                  isGroupChat: isGroupChat,
                );
                notificationsSent++;
              }
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
      print('   Online users (no notification): $onlineUsers');
      print('   Offline users (notification sent): $notificationsSent');
      
    } catch (e) {
      print('🔔 Error sending notifications: $e');
    }
  }
  
  // Send FCM notification using Firebase Cloud Messaging API v1
  static Future<void> _sendFCMNotification({
    required String token,
    required String chatRoomId,
    required String senderName,
    required String message,
    required bool isGroupChat,
  }) async {
    try {
      // Get recipient user ID from the token
      final recipientId = await _getUserIdByToken(token);
      if (recipientId == null) {
        print('❌ Could not find user for token');
        return;
      }
      
      // Check if recipient is online
      final isRecipientOnline = await _isUserOnline(recipientId);
      
      if (isRecipientOnline) {
        print('🔔 Recipient is online - skipping notification');
        print('   Recipient: $recipientId (ONLINE)');
        print('   Message will be seen in real-time chat');
        return;
      }
      
      print('🔔 Creating real-time notification via Firestore...');
      print('   Title: ${isGroupChat ? 'Group: $senderName' : senderName}');
      print('   Message: $message');
      print('   Recipient: $recipientId (OFFLINE)');
      
      // Create a notification request that will trigger a real-time notification
      await _firestore.collection('notification_requests').add({
        'recipientId': recipientId,
        'to': token,
        'notification': {
          'title': isGroupChat ? 'Group: $senderName' : senderName,
          'body': message,
        },
        'data': {
          'chatRoomId': chatRoomId,
          'senderName': senderName,
          'isGroupChat': isGroupChat.toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'chat_messages',
            'priority': 'high',
            'sound': 'default',
          }
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
            }
          }
        },
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });
      
      print('✅ Notification sent to OFFLINE user');
      print('✅ Recipient should receive notification when they open the app');
      
    } catch (e) {
      print('❌ Error creating notification request: $e');
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
  
  // Listen for notification requests in Firestore and show local notifications
  static void _listenForNotificationRequests() {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) return;
    
    print('🔔 Setting up real-time notification listener for user: $currentUserId');
    
    // Listen for notification requests where current user is the recipient
    _firestore.collection('notification_requests')
        .where('recipientId', isEqualTo: currentUserId)
        .where('processed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          _handleNotificationRequest(data, doc.doc.id);
        }
      }
    });
  }
  
  // Handle incoming notification request and show local notification
  static Future<void> _handleNotificationRequest(Map<String, dynamic> data, String docId) async {
    try {
      final notification = data['notification'] as Map<String, dynamic>?;
      final chatRoomId = data['data']?['chatRoomId'] as String?;
      
      if (notification != null) {
        print('🔔 Received notification request: ${notification['title']}');
        
        // Show local notification immediately
        await _localNotifications.show(
          docId.hashCode,
          notification['title'] as String?,
          notification['body'] as String?,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_messages',
              'Chat Messages',
              channelDescription: 'Notifications for chat messages',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(
                notification['body'] as String? ?? '',
                contentTitle: notification['title'] as String?,
              ),
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: chatRoomId,
        );
        
        // Mark as processed
        await _firestore.collection('notification_requests').doc(docId).update({
          'processed': true,
          'processedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Local notification shown and marked as processed');
      }
    } catch (e) {
      print('❌ Error handling notification request: $e');
    }
  }
  
  // Initialize notification listener for current user
  static Future<void> initializeNotificationListener() async {
    print('🔔 Initializing notification listener...');
    _listenForNotificationRequests();
  }
  
  // Get unread message count for drawer badge
  static Stream<int> getUnreadMessageCount() {
    return ChatService.getUnreadMessageCount();
  }
  
  // Clear notifications for a specific chat
  static Future<void> clearChatNotifications(String chatRoomId) async {
    await _localNotifications.cancel(chatRoomId.hashCode);
  }
  
  // Debug: Check if current user has FCM token saved
  static Future<void> debugCheckFCMToken() async {
    final currentUserId = ChatService.currentUserId;
    print('🔔 DEBUG: FCM Configuration Status');
    print('   FCM Project ID: ${FCMConfig.projectId}');
    print('   FCM Configured: ${FCMConfig.isConfigured}');
    print('   Using Real-time Firestore Notifications: Yes');
    print('   Current User: $currentUserId');
    
    if (!FCMConfig.isConfigured) {
      print('❌ FCM NOT CONFIGURED!');
      print('❌ Project ID is empty in fcm_config.dart');
    } else {
      print('✅ FCM Configuration looks good');
      print('✅ Real-time notifications via Firestore are active');
      print('✅ Notifications will appear immediately when app is open/background');
    }
    
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
            print('   Token: ${fcmToken.substring(0, 20)}...');
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
  
  // Debug: List all users with FCM tokens
  static Future<void> debugListAllFCMTokens() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      print('🔔 DEBUG: All users with FCM tokens:');
      
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final fcmToken = data['fcmToken'] as String?;
        final displayName = data['displayName'] as String?;
        
        if (fcmToken != null) {
          print('   ${displayName ?? 'Unknown'} (${doc.id}): ${fcmToken.substring(0, 20)}...');
        }
      }
    } catch (e) {
      print('🔔 DEBUG: Error listing FCM tokens: $e');
    }
  }

  // Test notification (for debugging)
  static Future<void> sendTestNotification() async {
    print('🔔 Sending test notification...');
    try {
      await _localNotifications.show(
        999,
        'Test Notification',
        'This is a test message to verify notifications are working',
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
      print('🔔 Test notification sent successfully');
    } catch (e) {
      print('🔔 Error sending test notification: $e');
    }
  }

  // Test sending notification to a specific user (for debugging)
  static Future<void> debugSendNotificationToUser(String userId, String message) async {
    try {
      print('🔔 DEBUG: Testing notification send to user: $userId');
      
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User not found: $userId');
        return;
      }
      
      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;
      final displayName = userData['displayName'] as String? ?? 'Unknown User';
      final isOnline = userData['isOnline'] as bool? ?? false;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        print('❌ No FCM token found for user: $displayName');
        return;
      }
      
      print('✅ Found FCM token for $displayName');
      print('   Token: ${fcmToken.substring(0, 20)}...');
      print('   Online Status: ${isOnline ? "ONLINE" : "OFFLINE"}');
      
      if (isOnline) {
        print('⚠️ User is ONLINE - notification would be SKIPPED in real usage');
        print('⚠️ Sending anyway for debug purposes...');
      }
      
      // Try to send notification (bypass online check for debug)
      await _firestore.collection('notification_requests').add({
        'recipientId': userId,
        'to': fcmToken,
        'notification': {
          'title': 'Debug Test',
          'body': message,
        },
        'data': {
          'chatRoomId': 'debug_room',
          'senderName': 'Debug Test',
          'isGroupChat': 'false',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });
      
      print('✅ Debug notification sent');
      
    } catch (e) {
      print('❌ Error in debug send: $e');
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

  // Helper method to check if user is online
  static Future<bool> _isUserOnline(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final isOnline = userData['isOnline'] as bool? ?? false;
        final lastSeen = userData['lastSeen'] as Timestamp?;
        
        print('🔔 User $userId online status: $isOnline');
        if (lastSeen != null) {
          final lastSeenTime = lastSeen.toDate();
          final timeDiff = DateTime.now().difference(lastSeenTime).inMinutes;
          print('🔔 Last seen: ${timeDiff} minutes ago');
          
          // Consider user offline if last seen > 2 minutes ago, even if isOnline is true
          if (timeDiff > 2) {
            print('🔔 User considered offline due to inactivity');
            return false;
          }
        }
        
        return isOnline;
      }
    } catch (e) {
      print('❌ Error checking user online status: $e');
    }
    
    // Default to offline if we can't determine status
    return false;
  }
}
