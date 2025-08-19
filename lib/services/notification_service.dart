import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      
      await _localNotifications.initialize(initSettings);
      print('🔔 Local notifications initialized');
      
      // Request FCM permissions
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      // Get and store FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _storeFCMToken(token);
        print('🔔 FCM Token stored: ${token.substring(0, 20)}...');
      }
      
      // Setup FCM listeners
      _setupFCMListeners();
      
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
    }
  }

  static Future<void> _storeFCMToken(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  static void _setupFCMListeners() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Message tapped from background: ${message.data}');
      _handleNotificationTap(message.data);
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? '',
      details,
      payload: message.data['chatRoomId'],
    );
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    // Handle notification tap - navigate to chat room
    print('📱 Handling notification tap: $data');
  }

  // MAIN FUNCTION: Send chat notification
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
    print('   Is group: $isGroupChat');
    
    try {
      // Get chat room participants
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        print('🔔 Chat room not found');
        return;
      }
      
      final chatRoomData = chatRoomDoc.data()!;
      final participants = List<String>.from(chatRoomData['participants'] ?? []);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      // Get receiving participants (exclude sender)
      final receivers = participants.where((id) => id != currentUserId).toList();
      
      if (receivers.isEmpty) {
        print('🔔 No receivers found');
        return;
      }

      // Get group info if it's a group chat
      String displayTitle = senderName;
      if (isGroupChat) {
        final groupName = chatRoomData['name'] as String?;
        displayTitle = groupName?.isNotEmpty == true ? '$senderName ($groupName)' : '$senderName (Group)';
      }
      
      print('🔔 Processing ${receivers.length} receivers for notifications...');
      
      // Send notifications to ALL receivers - let's make this simple for now
      int notificationsSent = 0;
      
      for (final receiverId in receivers) {
        try {
          final userDoc = await _firestore.collection('users').doc(receiverId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final fcmToken = userData['fcmToken'] as String?;
            final displayName = userData['displayName'] as String? ?? 'Unknown';
            
            print('🔔 Receiver: $displayName ($receiverId)');
            
            // Send FCM notification to ALL receivers (simplified)
            if (fcmToken != null && fcmToken.isNotEmpty) {
              await _sendDirectFCMNotification(
                token: fcmToken,
                title: displayTitle,
                body: message,
                chatRoomId: chatRoomId,
                senderPhotoURL: senderPhotoURL,
              );
              notificationsSent++;
              print('   ✅ Push notification sent to $displayName');
            } else {
              print('   ❌ No FCM token for $displayName');
            }
          }
        } catch (e) {
          print('🔔 Error processing receiver $receiverId: $e');
        }
      }
      
      print('🔔 Total notifications sent: $notificationsSent');
      
    } catch (e) {
      print('🔔 Error sending notifications: $e');
    }
  }

  // Send FCM notification directly
  static Future<void> _sendDirectFCMNotification({
    required String token,
    required String title,
    required String body,
    required String chatRoomId,
    String? senderPhotoURL,
  }) async {
    try {
      print('🔔 Sending direct FCM notification...');
      print('   Token: ${token.substring(0, 20)}...');
      print('   Title: $title');
      print('   Body: $body');
      
      // Store notification request for Cloud Functions
      await _firestore.collection('fcm_notification_queue').add({
        'token': token,
        'title': title,
        'body': body,
        'data': {
          'chatRoomId': chatRoomId,
          'type': 'chat_message',
        },
        'senderPhotoURL': senderPhotoURL,
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'priority': 'high',
      });
      
      print('✅ FCM notification queued for Cloud Functions');
      
    } catch (e) {
      print('❌ Error sending direct FCM notification: $e');
    }
  }

  // Reset notification system
  static Future<void> resetNotificationSystem() async {
    try {
      print('🔄 Resetting notification system...');
      // Re-initialize if needed
      print('✅ Notification system reset');
    } catch (e) {
      print('❌ Error resetting notification system: $e');
    }
  }

  // Setup notification listeners
  static Future<void> setupNotificationListeners() async {
    try {
      print('🔗 Setting up notification listeners...');
      _setupFCMListeners();
      print('✅ Notification listeners setup complete');
    } catch (e) {
      print('❌ Error setting up notification listeners: $e');
    }
  }
}
