import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'fcm_config.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  static FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  
  // Add subscription tracking to prevent duplicates
  static StreamSubscription? _pushNotificationSubscription;
  static StreamSubscription? _messageNotificationSubscription;
  static bool _listenersInitialized = false;
  
  // Add deduplication tracking
  static final Set<String> _processedNotificationIds = {};
  static Timer? _cleanupTimer;

  static Future<void> initialize() async {
    try {
      print('🔔 Initializing NotificationService...');

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
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
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidImplementation != null) {
          final granted = await androidImplementation
              .requestNotificationsPermission();
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
        print(
          '⚠️ Continuing without FCM - notifications may not work properly',
        );
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
              AndroidFlutterLocalNotificationsPlugin
            >()
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

    // Note: Notification listeners will be initialized after user login
    // Do NOT start listeners here as user might not be logged in yet
    print('🔔 FCM initialized - notification listeners will start after login');
  }

  // Save FCM token to user profile (DEVICE-SPECIFIC)
  static Future<void> _saveUserFCMToken(String token) async {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) {
      print('⚠️ Cannot save FCM token: no current user ID');
      print('   Token will be saved after user login');
      return;
    }

    try {
      // Generate a unique device ID based on the token (for device identification)
      final deviceId = token.substring(
        token.length - 10,
      ); // Use last 10 chars as device ID

      print('🔔 Saving FCM token for device-specific storage...');
      print('   User ID: $currentUserId');
      print('   Device ID: $deviceId');

      // Store token in a device-specific subcollection
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('devices')
          .doc(deviceId)
          .set({
            'fcmToken': token,
            'deviceId': deviceId,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'isActive': true,
            'loginTime': FieldValue.serverTimestamp(),
            'platform': 'android', // You can detect this dynamically
          }, SetOptions(merge: true));

      // Also update the main user document for backward compatibility
      await _firestore.collection('users').doc(currentUserId).update({
        'lastActiveDevice': deviceId,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ Device-specific FCM token saved');
      print('   Device: $deviceId for user: $currentUserId');
    } catch (e) {
      print('❌ Error saving device-specific FCM token: $e');
    }
  }

  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 Received foreground FCM message');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');

    final chatRoomId = message.data['chatRoomId'];
    final senderId = message.data['senderId'];
    final currentUserId = ChatService.currentUserId;

    // CRITICAL: Skip notifications from ourselves
    if (senderId == currentUserId) {
      print('🔔 Skipping foreground self-notification from sender: $senderId');
      return;
    }

    // Only show notification if it's from another user and has chat room data
    if (chatRoomId != null) {
      print(
        '🔔 Showing foreground notification from: $senderId to: $currentUserId',
      );
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
    final chatRoomId = message.data['chatRoomId'];
    
    if (notification != null && chatRoomId != null) {
      // Use consistent notification ID based on chat room
      final notificationId = _generateNotificationId(chatRoomId);
      
      await _localNotifications.show(
        notificationId,
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
    String? messageId,
  }) async {
    print('🔔 sendChatNotification called');
    print('   Chat room: $chatRoomId');
    print('   Sender: $senderName');
    print('   Message: $message');

    try {
      // Get chat room participants
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      if (!chatRoomDoc.exists) {
        print('🔔 Chat room not found');
        return;
      }

      final chatRoomData = chatRoomDoc.data()!;
      final participants = List<String>.from(
        chatRoomData['participants'] ?? [],
      );
      final currentUserId = ChatService.currentUserId;

      // Get receiving participants (exclude sender)
      final receivers = participants
          .where((id) => id != currentUserId)
          .toList();

      if (receivers.isEmpty) {
        print('🔔 No receivers found');
        return;
      }

      print('🔔 Checking ${receivers.length} receivers for device tokens...');
      print('🔔 SENDER EXCLUSION: Current user $currentUserId will NOT receive notifications');

      // Send ONE notification PER RECEIVER (not per device)
      for (final receiverId in receivers) {
        try {
          print('🔔 Processing receiver: $receiverId');

          // CRITICAL: Double-check sender exclusion
          if (receiverId == currentUserId) {
            print('❌ SKIPPING SENDER: $receiverId (this should not happen)');
            continue;
          }

          // Get all active devices for this user
          final devicesSnapshot = await _firestore
              .collection('users')
              .doc(receiverId)
              .collection('devices')
              .where('isActive', isEqualTo: true)
              .get();

          // Collect all tokens for this receiver
          final List<String> allTokens = [];
          
          if (devicesSnapshot.docs.isEmpty) {
            print('⚠️ No active devices found for user: $receiverId');
            
            // FALLBACK: Check for old format FCM token
            final userDoc = await _firestore
                .collection('users')
                .doc(receiverId)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final oldFcmToken = userData['fcmToken'] as String?;

              if (oldFcmToken != null && oldFcmToken.isNotEmpty) {
                print('✅ Found old format FCM token');
                allTokens.add(oldFcmToken);
              }
            }
          } else {
            print('✅ Found ${devicesSnapshot.docs.length} active device(s) for user: $receiverId');
            
            // Collect all unique tokens
            for (final deviceDoc in devicesSnapshot.docs) {
              final deviceData = deviceDoc.data();
              final fcmToken = deviceData['fcmToken'] as String?;
              
              if (fcmToken != null && fcmToken.isNotEmpty && !allTokens.contains(fcmToken)) {
                allTokens.add(fcmToken);
              }
            }
          }

          // Now create ONLY ONE notification document with ALL tokens
          if (allTokens.isNotEmpty) {
            final title = isGroupChat ? 'Group: $senderName' : senderName;
            
            // Create a SINGLE notification document with the primary token
            // Store additional tokens in an array field if needed
            final notificationRef = await _firestore.collection('push_notifications').add({
              'recipientId': receiverId,
              'token': allTokens.first, // Primary token
              'additionalTokens': allTokens.length > 1 ? allTokens.sublist(1) : [], // Other tokens
              'title': title,
              'body': message,
              'senderName': senderName,
              'senderId': currentUserId,
              'senderPhotoURL': senderPhotoURL,
              'chatRoomId': chatRoomId,
              'messageId': messageId, // Include messageId for cleanup
              'isGroupChat': isGroupChat,
              'timestamp': FieldValue.serverTimestamp(),
              'delivered': false,
              'deviceCount': allTokens.length, // Track how many devices this user has
            });

            print('✅ Created ONE notification document (${notificationRef.id}) for ${allTokens.length} device(s)');
          } else {
            print('⚠️ No tokens found for receiver: $receiverId');
          }
        } catch (e) {
          print('❌ Error processing receiver $receiverId: $e');
        }
      }
    } catch (e) {
      print('🔔 Error sending notifications: $e');
    }
  }

  // Send direct FCM push notification - DEVICE-SPECIFIC VERSION
  static Future<void> _sendSingleFCMNotification({
    required String token,
    required String chatRoomId,
    required String senderName,
    required String message,
    required bool isGroupChat,
    String? senderPhotoURL,
    String? receiverId,
    String? messageId,
  }) async {
    try {
      final currentUserId = ChatService.currentUserId;

      // CRITICAL: Ensure we never send notification to sender
      if (receiverId == currentUserId) {
        print('❌ BLOCKED: Attempted to send notification to sender ($currentUserId)');
        return;
      }

      final title = isGroupChat ? 'Group: $senderName' : senderName;
      
      // Create ONLY ONE Firestore document for this notification
      final notificationRef = await _firestore.collection('push_notifications').add({
        'recipientId': receiverId,
        'token': token,
        'title': title,
        'body': message,
        'senderName': senderName,
        'senderId': currentUserId,
        'senderPhotoURL': senderPhotoURL,
        'chatRoomId': chatRoomId,
        'messageId': messageId, // Include messageId for cleanup
        'isGroupChat': isGroupChat,
        'timestamp': FieldValue.serverTimestamp(),
        'delivered': false,
      });

      print('✅ Single notification document created: ${notificationRef.id} (messageId: $messageId)');
    } catch (e) {
      print('❌ Error creating push notification: $e');
    }
  }

  // Send notification via Firestore trigger (no authentication issues)
  static Future<void> _sendViaFirestoreTrigger({
    required String recipientId,
    required String token,
    required String title,
    required String body,
    required String chatRoomId,
    String? senderName,
    String? senderPhotoURL,
  }) async {
    try {
      print('🔔 Sending notification via Firestore trigger...');

      // Create a document in chat_notifications collection
      // This will trigger the Cloud Function automatically
      final docRef = await _firestore.collection('chat_notifications').add({
        'recipientId': recipientId,
        'recipientToken': token,
        'title': title,
        'body': body,
        'chatRoomId': chatRoomId,
        'senderName': senderName ?? 'Unknown',
        'senderId': ChatService.currentUserId,
        'senderPhotoURL': senderPhotoURL,
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });

      print('✅ Firestore notification trigger created: ${docRef.id}');
    } catch (e) {
      print('❌ Error creating Firestore notification trigger: $e');
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
    try {
      print('🧹 Clearing local notifications for chat room: $chatRoomId');
      
      // Generate the base notification ID for this chat room
      final baseNotificationId = _generateNotificationId(chatRoomId);
      
      // Cancel the main chat notification
      await _localNotifications.cancel(baseNotificationId);
      
      // Also try to cancel with the old hash method for backward compatibility
      await _localNotifications.cancel(chatRoomId.hashCode);
      
      // Cancel a range of potential notification IDs for this chat room
      // (in case multiple messages created multiple notifications)
      for (int i = 0; i < 10; i++) {
        await _localNotifications.cancel(baseNotificationId + i);
      }
      
      print('✅ Local notifications cleared for chat room: $chatRoomId');
    } catch (e) {
      print('❌ Error clearing chat notifications: $e');
    }
  }

  // Clear all chat notifications from the phone
  static Future<void> clearAllChatNotifications() async {
    try {
      print('🧹 Clearing ALL local chat notifications');
      await _localNotifications.cancelAll();
      print('✅ All local notifications cleared');
    } catch (e) {
      print('❌ Error clearing all notifications: $e');
    }
  }

  // Generate consistent notification ID for a chat room
  static int _generateNotificationId(String chatRoomId) {
    return chatRoomId.hashCode.abs() % 1000000; // Keep within reasonable range
  }

  static void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (_processedNotificationIds.length > 100) {
        print('🧹 Cleaning up processed notification IDs');
        _processedNotificationIds.clear();
      }
    });
  }

  // Listen for push notifications in Firestore (SIMPLIFIED APPROACH)
  static void _listenForPushNotifications() {
    // CRITICAL: Cancel any existing subscription first
    if (_pushNotificationSubscription != null) {
      print('⚠️ Cancelling existing push notification subscription');
      _pushNotificationSubscription?.cancel();
      _pushNotificationSubscription = null;
    }
    
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) {
      print('❌ No current user ID - cannot listen for notifications');
      return;
    }
    
    print('🔔 Setting up push notification listener for user: $currentUserId');
    
    // Start cleanup timer for processed notifications
    _startCleanupTimer();
    
    // Listen for push notifications where current user is the recipient
    _pushNotificationSubscription = _firestore.collection('push_notifications')
        .where('recipientId', isEqualTo: currentUserId)
        .where('delivered', isEqualTo: false)
        .limit(5) // Reduced limit since we have fewer documents now
        .snapshots()
        .listen(
          (snapshot) {
            print('🔔 Push notifications snapshot received: ${snapshot.docChanges.length} changes');
            
            for (final doc in snapshot.docChanges) {
              if (doc.type == DocumentChangeType.added) {
                final docId = doc.doc.id;
                
                // CRITICAL: Check if we've already processed this notification
                if (_processedNotificationIds.contains(docId)) {
                  print('⚠️ Skipping already processed notification: $docId');
                  continue;
                }
                
                final data = doc.doc.data() as Map<String, dynamic>;
                final senderId = data['senderId'] as String?;
                
                // CRITICAL: Skip notifications from ourselves
                if (senderId == currentUserId) {
                  print('🔔 Skipping self-notification from sender: $senderId');
                  _firestore.collection('push_notifications').doc(docId).update({
                    'delivered': true,
                    'deliveredAt': FieldValue.serverTimestamp(),
                    'skippedReason': 'self-notification',
                  }).catchError((e) => print('Error updating doc: $e'));
                  continue;
                }
                
                // Add to processed set to prevent duplicates
                _processedNotificationIds.add(docId);
                
                print('🔔 Processing notification: ${docId}');
                print('   Sender: $senderId, Recipient: $currentUserId');
                
                // Show the notification ONCE
                _showPushNotification(data, docId);
              }
            }
          },
          onError: (error) {
            print('❌ Error in push notification listener: $error');
          },
        );
  }

  // Show push notification immediately
  static Future<void> _showPushNotification(
    Map<String, dynamic> data,
    String docId,
  ) async {
    try {
      final title = data['title'] as String?;
      final body = data['body'] as String?;
      final chatRoomId = data['chatRoomId'] as String?;
      
      if (title != null && body != null) {
        print('🔔 Showing push notification: $title - $body');
        
        // Use a unique but consistent ID for the notification
        final notificationId = docId.hashCode.abs() % 1000000; // Keep it within reasonable range
        
        // Show local notification immediately
        await _localNotifications.show(
          notificationId, // Use consistent ID instead of random
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
          payload: chatRoomId,
        );
        
        // Mark as delivered in Firestore
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

  // Restart notification listener after login
  static Future<void> restartNotificationListener() async {
    final currentUserId = ChatService.currentUserId;
    print('🔔 Restarting notification listener for user: $currentUserId');

    if (currentUserId.isNotEmpty) {
      // Stop existing listeners first
      await stopNotificationListener();

      // Restart the listener for the new user
      _listenForPushNotifications();
      _listenersInitialized = true;
      print('✅ Notification listener restarted for user: $currentUserId');
    } else {
      print('❌ Cannot restart notification listener - no current user');
    }
  }

  // Stop notification listener (for logout)
  static Future<void> stopNotificationListener() async {
    print('🔔 Stopping notification listeners...');
    
    // Cancel push notification subscription
    if (_pushNotificationSubscription != null) {
      await _pushNotificationSubscription!.cancel();
      _pushNotificationSubscription = null;
      print('✅ Push notification subscription cancelled');
    }
    
    // Cancel message notification subscription if exists
    if (_messageNotificationSubscription != null) {
      await _messageNotificationSubscription!.cancel();
      _messageNotificationSubscription = null;
      print('✅ Message notification subscription cancelled');
    }
    
    // Cancel cleanup timer
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    
    // Clear processed IDs
    _processedNotificationIds.clear();
    
    _listenersInitialized = false;
    print('✅ All notification listeners stopped');
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
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUserId)
            .get();
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

  // Test sending FCM notification to a specific user (DEVICE-SPECIFIC VERSION)
  static Future<void> debugSendNotificationToUser(
    String userId,
    String message,
  ) async {
    try {
      print(
        '🔔 DEBUG: Testing device-specific FCM notification send to user: $userId',
      );

      final currentUserId = ChatService.currentUserId;
      if (userId == currentUserId) {
        print(
          '❌ BLOCKED: Cannot send debug notification to self ($currentUserId)',
        );
        return;
      }

      // Get user's info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User not found: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final displayName = userData['displayName'] as String? ?? 'Unknown User';
      final photoURL = userData['photoURL'] as String?;

      // Get all active devices for this user
      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .where('isActive', isEqualTo: true)
          .get();

      if (devicesSnapshot.docs.isEmpty) {
        print('❌ No active devices found for user: $displayName');
        return;
      }

      print(
        '✅ Found ${devicesSnapshot.docs.length} active device(s) for $displayName',
      );

      // Send notification to all active devices
      for (final deviceDoc in devicesSnapshot.docs) {
        final deviceData = deviceDoc.data();
        final fcmToken = deviceData['fcmToken'] as String?;
        final deviceId = deviceData['deviceId'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          print('📱 Sending debug notification to device: $deviceId');
          print('   Token: ${fcmToken.substring(0, 20)}...');

          // Send test notification using the same method as real messages
          await _sendSingleFCMNotification(
            token: fcmToken,
            chatRoomId: 'debug_test_room',
            senderName: 'Debug Test',
            message: message,
            isGroupChat: false,
            senderPhotoURL: photoURL,
            receiverId: userId, // Explicitly set recipient ID
          );
        }
      }

      print('✅ Debug FCM notification sent to all active devices');
    } catch (e) {
      print('❌ Error in debug send: $e');
    }
  }

  // Manual force notification for testing
  static Future<void> debugForceShowNotification(
    String title,
    String body,
  ) async {
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

  // Refresh FCM token on login
  static Future<void> refreshFCMTokenOnLogin() async {
    try {
      print('🔔 Refreshing FCM token on login...');

      // Get fresh FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveUserFCMToken(token);
        print('✅ FCM token refreshed and saved on login');
      } else {
        print('❌ Failed to get FCM token on login');
      }
    } catch (e) {
      print('❌ Error refreshing FCM token on login: $e');
    }
  }

  // Clear FCM token on logout (DEVICE-SPECIFIC VERSION)
  static Future<void> clearFCMTokenOnLogout() async {
    try {
      print('🔔 Clearing device-specific FCM token on logout...');
      final currentUserId = ChatService.currentUserId;

      if (currentUserId.isNotEmpty) {
        // Get current device FCM token
        final currentToken = await _firebaseMessaging.getToken();
        if (currentToken != null) {
          final deviceId = currentToken.substring(currentToken.length - 10);

          print('📱 Deactivating device: $deviceId for user: $currentUserId');

          // Mark current device as inactive
          await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('devices')
              .doc(deviceId)
              .update({
                'isActive': false,
                'logoutTime': FieldValue.serverTimestamp(),
              });

          print('✅ Device $deviceId marked as inactive');
        }

        // Clear local FCM token
        await _firebaseMessaging.deleteToken();
        print('✅ Local FCM token deleted');

        // Stop notification listener
        await stopNotificationListener();
      } else {
        print('❌ No current user ID for logout');
      }
    } catch (e) {
      print('❌ Error clearing device-specific FCM token on logout: $e');
    }
  }

  // Handle app lifecycle changes for proper notification management
  static void handleAppLifecycleChange(String state) {
    print('🔄 App lifecycle changed to: $state');

    switch (state) {
      case 'resumed':
        print('📱 App resumed - notifications active');
        // App is in foreground, notifications should show as local notifications
        break;
      case 'paused':
        print('📱 App paused - background notifications enabled');
        // App is in background, FCM push notifications will be handled by system
        break;
      case 'inactive':
        print('📱 App inactive');
        break;
      case 'detached':
        print('📱 App detached');
        break;
      case 'hidden':
        print('📱 App hidden');
        break;
      default:
        print('📱 Unknown app state: $state');
    }
  }

  // Helper method to get user ID by FCM token (DEVICE-SPECIFIC VERSION)
  static Future<String?> _getUserIdByToken(String token) async {
    try {
      // Search in device-specific collections
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final devicesSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('devices')
            .where('fcmToken', isEqualTo: token)
            .limit(1)
            .get();

        if (devicesSnapshot.docs.isNotEmpty) {
          return userDoc.id;
        }
      }

      // Fallback: Check old format for backward compatibility
      final oldFormatSnapshot = await _firestore
          .collection('users')
          .where('fcmToken', isEqualTo: token)
          .limit(1)
          .get();

      if (oldFormatSnapshot.docs.isNotEmpty) {
        return oldFormatSnapshot.docs.first.id;
      }
    } catch (e) {
      print('❌ Error getting user by token: $e');
    }
    return null;
  }

  // Simple debug method to trace notification flow
  static void debugNotificationFlow(String step, Map<String, dynamic> data) {
    final currentUserId = ChatService.currentUserId;
    print('🔔 NOTIFICATION FLOW DEBUG: $step');
    print('   Current User: $currentUserId');
    print('   Sender ID: ${data['senderId']}');
    print('   Recipient ID: ${data['recipientId']}');
    print('   Title: ${data['title']}');
    print('   Body: ${data['body']}');
    print('   Should show notification: ${data['senderId'] != currentUserId}');
    print('   ---');
  }

  // Enhanced debug: List all users with FCM tokens (old and new format)
  static Future<void> debugListAllFCMTokens() async {
    try {
      print('\n' + '=' * 60);
      print('� DEBUG: ALL FCM TOKENS IN DATABASE');
      print('=' * 60);

      final usersSnapshot = await _firestore.collection('users').get();

      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final userId = doc.id;
        final displayName = userData['displayName'] as String? ?? 'Unknown';
        final isOnline = userData['isOnline'] as bool? ?? false;
        final lastSeen = userData['lastSeen'] as Timestamp?;

        print('\n👤 User: $displayName ($userId)');
        print('   Status: ${isOnline ? "🟢 Online" : "🔴 Offline"}');
        if (lastSeen != null) {
          print('   Last Seen: ${lastSeen.toDate()}');
        }

        // Check for old format FCM token
        final oldFcmToken = userData['fcmToken'] as String?;
        if (oldFcmToken != null && oldFcmToken.isNotEmpty) {
          print('   📱 OLD FORMAT TOKEN: ${oldFcmToken.substring(0, 30)}...');
        } else {
          print('   📱 OLD FORMAT TOKEN: None');
        }

        // Check device-specific tokens
        final devicesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .get();

        if (devicesSnapshot.docs.isEmpty) {
          print('   🔧 NEW FORMAT DEVICES: None');
        } else {
          print(
            '   🔧 NEW FORMAT DEVICES: ${devicesSnapshot.docs.length} found',
          );
          for (final deviceDoc in devicesSnapshot.docs) {
            final deviceData = deviceDoc.data();
            final deviceId = deviceDoc.id;
            final fcmToken = deviceData['fcmToken'] as String?;
            final isActive = deviceData['isActive'] as bool? ?? false;
            final platform = deviceData['platform'] as String? ?? 'unknown';
            final lastUpdate = deviceData['lastTokenUpdate'] as Timestamp?;
            final migrated =
                deviceData['migratedFromOldFormat'] as bool? ?? false;

            print('      📱 Device: $deviceId');
            print('         Status: ${isActive ? "🟢 Active" : "🔴 Inactive"}');
            print('         Platform: $platform');
            if (fcmToken != null) {
              print('         Token: ${fcmToken.substring(0, 30)}...');
            } else {
              print('         Token: None');
            }
            if (lastUpdate != null) {
              print('         Last Update: ${lastUpdate.toDate()}');
            }
            if (migrated) {
              print('         ⚡ Migrated from old format');
            }
          }
        }
        print('   ---');
      }

      print('\n' + '=' * 60);
    } catch (e) {
      print('❌ Error listing FCM tokens: $e');
    }
  }

  // Debug function to specifically check a single user's tokens
  static Future<void> debugCheckUserTokens(String userId) async {
    try {
      print('\n' + '=' * 60);
      print('🔍 DEBUG: FCM TOKENS FOR SPECIFIC USER');
      print('=' * 60);

      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document does not exist: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final displayName = userData['displayName'] as String? ?? 'Unknown';
      final isOnline = userData['isOnline'] as bool? ?? false;
      final lastSeen = userData['lastSeen'] as Timestamp?;

      print('👤 User: $displayName ($userId)');
      print('   Status: ${isOnline ? "🟢 Online" : "🔴 Offline"}');
      if (lastSeen != null) {
        print('   Last Seen: ${lastSeen.toDate()}');
      }

      // Check for old format FCM token
      final oldFcmToken = userData['fcmToken'] as String?;
      if (oldFcmToken != null && oldFcmToken.isNotEmpty) {
        print('   📱 OLD FORMAT TOKEN: ${oldFcmToken.substring(0, 50)}...');
        print('      Full token available for migration');
      } else {
        print('   📱 OLD FORMAT TOKEN: None');
      }

      // Check for new format device-specific tokens
      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .get();

      if (devicesSnapshot.docs.isEmpty) {
        print('   🔧 NEW FORMAT DEVICES: None');
        if (oldFcmToken != null && oldFcmToken.isNotEmpty) {
          print(
            '\n💡 SOLUTION: This user has old format token but no devices.',
          );
          print('   Next notification will auto-migrate the token.');
        } else {
          print('\n💡 SOLUTION: User needs to log out and log back in');
          print('   to register their device and get notifications.');
        }
      } else {
        print('   🔧 NEW FORMAT DEVICES: ${devicesSnapshot.docs.length} found');
        int activeDevices = 0;
        for (final deviceDoc in devicesSnapshot.docs) {
          final deviceData = deviceDoc.data();
          final deviceId = deviceDoc.id;
          final fcmToken = deviceData['fcmToken'] as String?;
          final isActive = deviceData['isActive'] as bool? ?? false;
          final platform = deviceData['platform'] as String? ?? 'unknown';
          final lastUpdate = deviceData['lastTokenUpdate'] as Timestamp?;
          final migrated =
              deviceData['migratedFromOldFormat'] as bool? ?? false;

          if (isActive) activeDevices++;

          print('      📱 Device: $deviceId');
          print('         Status: ${isActive ? "🟢 Active" : "🔴 Inactive"}');
          print('         Platform: $platform');
          if (fcmToken != null) {
            print('         Token: ${fcmToken.substring(0, 50)}...');
          } else {
            print('         Token: None');
          }
          if (lastUpdate != null) {
            print('         Last Update: ${lastUpdate.toDate()}');
          }
          if (migrated) {
            print('         ⚡ Migrated from old format');
          }
        }

        if (activeDevices == 0) {
          print('\n⚠️ WARNING: No active devices found!');
          print('   User needs to log in to activate their device.');
        } else {
          print(
            '\n✅ READY: $activeDevices active device(s) will receive notifications',
          );
        }
      }

      print('=' * 60);
    } catch (e) {
      print('❌ Error in debugCheckUserTokens: $e');
    }
  }

  // Force refresh and save current device token (for debugging)
  static Future<void> forceRefreshDeviceToken() async {
    try {
      print('🔔 FORCE REFRESH: Getting current device token...');
      final currentUserId = ChatService.currentUserId;

      if (currentUserId.isEmpty) {
        print('❌ No current user for force refresh');
        return;
      }

      // Get fresh token
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        print('❌ Failed to get FCM token for force refresh');
        return;
      }

      print('✅ Got fresh FCM token: ${token.substring(0, 20)}...');

      // Force save with device-specific logic
      await _saveUserFCMToken(token);

      // Also restart the notification listener
      await restartNotificationListener();

      print('✅ Force refresh complete - device should now be active');
    } catch (e) {
      print('❌ Error in force refresh: $e');
    }
  }

  // Debug method to check if current user's receiving user has active devices
  static Future<void> debugCheckReceiverDevices(String receiverId) async {
    try {
      print('🔔 DEBUG: Checking receiver devices for: $receiverId');

      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(receiverId)
          .collection('devices')
          .get();

      if (devicesSnapshot.docs.isEmpty) {
        print('❌ NO DEVICES AT ALL for receiver: $receiverId');
        print('❌ This user needs to login again to register device tokens');
        return;
      }

      print('📱 Found ${devicesSnapshot.docs.length} device(s) for receiver:');

      for (final deviceDoc in devicesSnapshot.docs) {
        final deviceData = deviceDoc.data();
        final deviceId = deviceData['deviceId'] as String? ?? 'Unknown';
        final isActive = deviceData['isActive'] as bool? ?? false;
        final fcmToken = deviceData['fcmToken'] as String?;
        final loginTime = deviceData['loginTime'] as Timestamp?;

        print('   Device: $deviceId');
        print('   Active: $isActive');
        print('   Has Token: ${fcmToken != null}');
        if (loginTime != null) {
          print('   Login Time: ${loginTime.toDate()}');
        }
        print('   ---');
      }

      final activeDevices = devicesSnapshot.docs
          .where((doc) => (doc.data()['isActive'] as bool?) == true)
          .length;

      print(
        '📊 Summary: $activeDevices active devices out of ${devicesSnapshot.docs.length} total',
      );

      if (activeDevices == 0) {
        print('❌ PROBLEM: No active devices found');
        print('💡 SOLUTION: Receiver needs to login again to activate device');
      }
    } catch (e) {
      print('❌ Error checking receiver devices: $e');
    }
  }

  // Listen for new messages in real-time and show notifications immediately
  static void _listenForNewMessages() {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) {
      print('❌ No current user ID - cannot listen for new messages');
      return;
    }

    print('🔔 Setting up real-time message listener for notifications...');

    // Listen for new messages in all chat rooms where current user is a participant
    _firestore
        .collectionGroup('messages')
        .where(
          'timestamp',
          isGreaterThan: DateTime.now().subtract(Duration(seconds: 10)),
        ) // Only recent messages
        .orderBy('timestamp', descending: true)
        .limit(1) // Only get the latest message
        .snapshots()
        .listen(
          (snapshot) async {
            for (final doc in snapshot.docChanges) {
              if (doc.type == DocumentChangeType.added) {
                final messageData = doc.doc.data() as Map<String, dynamic>;
                final senderId = messageData['senderId'] as String?;
                final chatRoomId = doc.doc.reference.parent.parent?.id;

                print('🔔 New message detected in chat room: $chatRoomId');
                print('   Sender: $senderId');
                print('   Current user: $currentUserId');

                // CRITICAL: Skip messages from current user
                if (senderId == currentUserId) {
                  print('🔔 Skipping message from current user');
                  continue;
                }

                if (chatRoomId == null) {
                  print('❌ Could not determine chat room ID for message');
                  continue;
                }

                // Check if current user is a participant in this chat room
                try {
                  final chatRoomDoc = await _firestore
                      .collection('chatRooms')
                      .doc(chatRoomId)
                      .get();
                  if (!chatRoomDoc.exists) {
                    print('❌ Chat room not found: $chatRoomId');
                    continue;
                  }

                  final chatRoomData = chatRoomDoc.data()!;
                  final participants = List<String>.from(
                    chatRoomData['participants'] ?? [],
                  );

                  if (!participants.contains(currentUserId)) {
                    print(
                      '🔔 Current user not a participant in chat room: $chatRoomId',
                    );
                    continue;
                  }

                  // Get sender information
                  final senderDoc = await _firestore
                      .collection('users')
                      .doc(senderId!)
                      .get();
                  final senderName = senderDoc.exists
                      ? (senderDoc.data()?['displayName'] as String? ??
                            'Unknown User')
                      : 'Unknown User';

                  final content =
                      messageData['content'] as String? ?? 'New message';
                  final isGroupChat = chatRoomData['type'] == 'group';

                  final title = isGroupChat ? 'Group: $senderName' : senderName;

                  print('🔔 Showing instant notification for new message');
                  print('   Title: $title');
                  print('   Content: $content');

                  // Show local notification immediately
                  await _localNotifications.show(
                    chatRoomId.hashCode + DateTime.now().millisecondsSinceEpoch,
                    title,
                    content,
                    NotificationDetails(
                      android: AndroidNotificationDetails(
                        'chat_messages',
                        'Chat Messages',
                        channelDescription: 'Notifications for chat messages',
                        importance: Importance.high,
                        priority: Priority.high,
                        styleInformation: BigTextStyleInformation(
                          content,
                          contentTitle: title,
                        ),
                        icon: '@drawable/notification_icon',
                      ),
                      iOS: DarwinNotificationDetails(
                        presentAlert: true,
                        presentBadge: true,
                        presentSound: true,
                      ),
                    ),
                    payload: chatRoomId,
                  );
                } catch (e) {
                  print('❌ Error processing new message for notification: $e');
                }
              }
            }
          },
          onError: (error) {
            print('❌ Error in real-time message listener: $error');
          },
        );
  }

  // Send immediate notification when message arrives - DIRECT APPROACH
  static Future<void> sendImmediateMessageNotification({
    required String chatRoomId,
    required String senderName,
    required String senderPhotoURL,
    required String message,
    required String senderId,
    required bool isGroupChat,
  }) async {
    try {
      final currentUserId = ChatService.currentUserId;

      print('🔔 sendImmediateMessageNotification called');
      print('   Chat room: $chatRoomId');
      print('   Sender: $senderName ($senderId)');
      print('   Current user: $currentUserId');
      print('   Message: $message');

      // CRITICAL: Never send notification to sender
      if (senderId == currentUserId) {
        print('❌ BLOCKED: Not sending notification to sender');
        return;
      }

      // Get chat room participants
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      if (!chatRoomDoc.exists) {
        print('❌ Chat room not found: $chatRoomId');
        return;
      }

      final chatRoomData = chatRoomDoc.data()!;
      final participants = List<String>.from(
        chatRoomData['participants'] ?? [],
      );

      // Check if current user is a participant
      if (!participants.contains(currentUserId)) {
        print('❌ Current user not a participant in this chat');
        return;
      }

      final title = isGroupChat ? 'Group: $senderName' : senderName;

      print('✅ Showing immediate local notification');
      print('   Title: $title');
      print('   Body: $message');

      // Show local notification immediately for current user
      await _localNotifications.show(
        chatRoomId.hashCode + DateTime.now().millisecondsSinceEpoch,
        title,
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Instant chat message notifications',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              message,
              contentTitle: title,
            ),
            icon: '@drawable/notification_icon',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
          ),
        ),
        payload: chatRoomId,
      );

      print('✅ Immediate notification shown successfully');
    } catch (e) {
      print('❌ Error sending immediate notification: $e');
    }
  }

  // Listen for new messages and show notifications in real-time
  static void startMessageNotificationListener() {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) {
      print(
        '❌ No current user ID - cannot start message notification listener',
      );
      return;
    }

    print('🔔 Starting message notification listener for user: $currentUserId');

    // Listen for new messages in chat rooms where current user participates
    _firestore
        .collectionGroup('messages')
        .where('timestamp', isGreaterThan: DateTime.now())
        .snapshots()
        .listen(
          (snapshot) async {
            for (final doc in snapshot.docChanges) {
              if (doc.type == DocumentChangeType.added) {
                final messageData = doc.doc.data() as Map<String, dynamic>;
                final senderId = messageData['senderId'] as String?;
                final content =
                    messageData['content'] as String? ?? 'New message';
                final chatRoomId = doc.doc.reference.parent.parent?.id;

                print('🔔 New message listener triggered');
                print('   Chat room: $chatRoomId');
                print('   Sender: $senderId');
                print('   Current user: $currentUserId');
                print('   Content: $content');

                // CRITICAL: Skip messages from current user
                if (senderId == currentUserId) {
                  print('🔔 Skipping notification for own message');
                  continue;
                }

                if (chatRoomId == null || senderId == null) {
                  print('❌ Missing chat room ID or sender ID');
                  continue;
                }

                try {
                  // Verify current user is participant in this chat room
                  final chatRoomDoc = await _firestore
                      .collection('chatRooms')
                      .doc(chatRoomId)
                      .get();
                  if (!chatRoomDoc.exists) {
                    print('❌ Chat room not found: $chatRoomId');
                    continue;
                  }

                  final chatRoomData = chatRoomDoc.data()!;
                  final participants = List<String>.from(
                    chatRoomData['participants'] ?? [],
                  );

                  if (!participants.contains(currentUserId)) {
                    print(
                      '🔔 Current user not a participant in chat room: $chatRoomId',
                    );
                    continue;
                  }

                  // Get sender information
                  final senderDoc = await _firestore
                      .collection('users')
                      .doc(senderId)
                      .get();
                  final senderName = senderDoc.exists
                      ? (senderDoc.data()?['displayName'] as String? ??
                            'Unknown User')
                      : 'Unknown User';

                  final isGroupChat = chatRoomData['type'] == 'group';
                  final title = isGroupChat ? 'Group: $senderName' : senderName;

                  print('✅ Showing notification for new message');
                  print('   Title: $title');
                  print('   Content: $content');

                  // Show notification immediately
                  await _localNotifications.show(
                    chatRoomId.hashCode + DateTime.now().millisecondsSinceEpoch,
                    title,
                    content,
                    NotificationDetails(
                      android: AndroidNotificationDetails(
                        'chat_messages',
                        'Chat Messages',
                        channelDescription:
                            'Real-time chat message notifications',
                        importance: Importance.high,
                        priority: Priority.high,
                        styleInformation: BigTextStyleInformation(
                          content,
                          contentTitle: title,
                        ),
                        icon: '@drawable/notification_icon',
                        enableVibration: true,
                        playSound: true,
                        showWhen: true,
                      ),
                      iOS: DarwinNotificationDetails(
                        presentAlert: true,
                        presentBadge: true,
                        presentSound: true,
                        badgeNumber: 1,
                      ),
                    ),
                    payload: chatRoomId,
                  );

                  print('✅ Real-time notification shown successfully');
                } catch (e) {
                  print('❌ Error processing new message notification: $e');
                }
              }
            }
          },
          onError: (error) {
            print('❌ Error in message notification listener: $error');
          },
        );
  }

  // Test local notification - for debugging
  static Future<void> showTestNotification() async {
    try {
      print('🧪 Showing test notification...');

      await _localNotifications.show(
        999999, // Unique test ID
        'Test Notification',
        'This is a test notification to verify the system is working!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Test notification channel',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              'This is a test notification to verify the system is working!',
              contentTitle: 'Test Notification',
            ),
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test',
      );

      print('✅ Test notification shown successfully');
    } catch (e) {
      print('❌ Error showing test notification: $e');
    }
  }

  // Initialize notification listeners after user login
  static Future<void> initializeAfterLogin() async {
    final currentUserId = ChatService.currentUserId;
    if (currentUserId.isEmpty) {
      print('❌ Cannot initialize notification listeners: no current user');
      return;
    }
    
    // CRITICAL: Prevent duplicate initialization
    if (_listenersInitialized) {
      print('⚠️ Notification listeners already initialized, skipping...');
      return;
    }
    
    print('🔔 Initializing notification listeners after login for user: $currentUserId');
    
    try {
      // Cancel any existing listeners first
      await stopNotificationListener();
      
      // Clear any old processed IDs
      _processedNotificationIds.clear();
      
      // Ensure FCM token is saved for current device
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveUserFCMToken(token);
      }
      
      // Start only ONE notification listener
      _listenForPushNotifications();
      
      _listenersInitialized = true;
      print('✅ Notification listener initialized successfully (single instance)');
      
    } catch (e) {
      print('❌ Error initializing notification listeners: $e');
      _listenersInitialized = false;
    }
  }

}
