import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import 'notification_service.dart';

class ChatService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  
  static String get currentUserId => _auth.currentUser?.uid ?? '';
  
  // Send a message
  static Future<bool> sendMessage(String chatRoomId, String content) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      print('💬 Sending message to chat room: $chatRoomId');
      print('💬 Message content: $content');

      // Add message to Firestore
      await _firestore.collection('chatRooms').doc(chatRoomId).collection('messages').add({
        'content': content,
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Unknown User',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'isDeleted': false,
        'readBy': {currentUser.uid: true}, // Mark as read by sender
      });

      // Update last message in chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'lastMessageSenderName': currentUser.displayName ?? 'Unknown User',
      });

      // Get chat room info for notification
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (chatRoomDoc.exists) {
        final chatRoom = chatRoomDoc.data()!;
        final isGroupChat = chatRoom['type'] == 'group';
        
        // Send notification to other participants
        print('🔔 Sending notification for chat room: $chatRoomId');
        print('🔔 Message: $content');
        print('🔔 Sender: ${currentUser.displayName}');
        print('🔔 Is group chat: $isGroupChat');
        
        await NotificationService.sendChatNotification(
          chatRoomId: chatRoomId,
          senderName: currentUser.displayName ?? 'Unknown User',
          senderPhotoURL: currentUser.photoURL ?? '',
          message: content,
          timestamp: DateTime.now(),
          isGroupChat: isGroupChat,
        );
        
        print('✅ Notification sent successfully');
      }

      return true;
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  // Update online status
  static Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final userId = currentUserId;
      if (userId.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print('✅ Updated online status: $isOnline for user: $userId');
      }
    } catch (e) {
      print('❌ Error updating online status: $e');
    }
  }
}
