import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import 'notification_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static String get currentUserId => _auth.currentUser?.uid ?? '';

  // Get current user profile
  static Future<UserProfile?> getCurrentUserProfile() async {
    if (currentUserId.isEmpty) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      print('Error getting current user profile: $e');
    }
    return null;
  }

  // Search users for chat
  static Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
          .where((user) => user.id != currentUserId)
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Create or get direct chat room
  static Future<String?> createDirectChatRoom(String otherUserId) async {
    try {
      final currentUser = await getCurrentUserProfile();
      if (currentUser == null) return null;

      // Check if chat room already exists
      final existingRoom = await _firestore
          .collection('chatRooms')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in existingRoom.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(otherUserId) && participants.length == 2) {
          return doc.id;
        }
      }

      // Create new direct chat room
      final otherUser = await _firestore.collection('users').doc(otherUserId).get();
      if (!otherUser.exists) return null;

      final otherUserData = UserProfile.fromMap(otherUser.data()!, otherUser.id);
      
      final chatRoom = ChatRoom(
        id: '',
        type: 'direct',
        name: otherUserData.displayName,
        participants: [currentUserId, otherUserId],
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      final docRef = await _firestore.collection('chatRooms').add(chatRoom.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating direct chat room: $e');
      return null;
    }
  }

  // Create group chat room
  static Future<String?> createGroupChatRoom({
    required String name,
    String? description,
    required List<String> participantIds,
  }) async {
    try {
      final currentUser = await getCurrentUserProfile();
      if (currentUser == null) return null;

      final allParticipants = [currentUserId, ...participantIds].toSet().toList();

      final chatRoom = ChatRoom(
        id: '',
        type: 'group',
        name: name,
        description: description,
        participants: allParticipants,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
        groupSettings: {
          'admins': [currentUserId],
          'canMembersAddOthers': false,
          'canMembersEditInfo': false,
        },
      );

      final docRef = await _firestore.collection('chatRooms').add(chatRoom.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating group chat room: $e');
      return null;
    }
  }

  // Get chat rooms for current user
  static Stream<List<ChatRoom>> getUserChatRooms() {
    if (currentUserId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        // Removed .orderBy('lastMessageTime', descending: true) temporarily to avoid index requirement
        .snapshots()
        .map((snapshot) {
          final chatRooms = snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort in memory instead of in query
          chatRooms.sort((a, b) => (b.lastMessageTime ?? DateTime.now())
              .compareTo(a.lastMessageTime ?? DateTime.now()));
          
          return chatRooms;
        });
  }

  // Get only group chat rooms for the current user
  static Stream<List<ChatRoom>> getUserGroupChatRooms() {
    if (currentUserId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
            .where((room) => room.type == 'group') // Filter in app instead of query
            .toList());
  }

  // Send message
  static Future<bool> sendMessage({
    required String chatRoomId,
    required String content,
    String type = 'text',
    String? replyToId,
  }) async {
    try {
      final currentUser = await getCurrentUserProfile();
      if (currentUser == null) return false;

      final message = Message(
        id: '',
        chatRoomId: chatRoomId,
        senderId: currentUserId,
        senderName: currentUser.displayName,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        readBy: {currentUserId: true},
        replyToId: replyToId,
      );

      // Add message to messages subcollection
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(message.toMap());

      // Update chat room's last message info
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': content,
        'lastMessageTime': DateTime.now(),
        'lastMessageSender': currentUserId,
      });

      // Get chat room info for notification
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (chatRoomDoc.exists) {
        final chatRoom = ChatRoom.fromMap(chatRoomDoc.data()!, chatRoomDoc.id);
        
        // Send notification to other participants (not the sender)
        print('🔔 Sending notification for chat room: ${chatRoom.id}');
        print('🔔 Message: $content');
        print('🔔 Sender: ${currentUser.displayName}');
        
        await NotificationService.sendChatNotification(
          chatRoomId: chatRoomId,
          senderName: currentUser.displayName,
          senderPhotoURL: currentUser.photoURL ?? '',
          message: content,
          timestamp: DateTime.now(),
          isGroupChat: chatRoom.type == 'group',
        );
      }

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get messages for a chat room
  static Stream<List<Message>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      final unreadMessages = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('readBy.$currentUserId', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readBy.$currentUserId': true,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get chat room details
  static Future<ChatRoom?> getChatRoom(String chatRoomId) async {
    try {
      final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (doc.exists) {
        return ChatRoom.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      print('Error getting chat room: $e');
    }
    return null;
  }

  // Get user profiles for participants
  static Future<List<UserProfile>> getParticipantProfiles(List<String> participantIds) async {
    if (participantIds.isEmpty) return [];

    try {
      final profiles = <UserProfile>[];
      for (String id in participantIds) {
        final doc = await _firestore.collection('users').doc(id).get();
        if (doc.exists) {
          profiles.add(UserProfile.fromMap(doc.data()!, doc.id));
        }
      }
      return profiles;
    } catch (e) {
      print('Error getting participant profiles: $e');
      return [];
    }
  }

  // Update user online status
  static Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUserId.isEmpty) return;

    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now(),
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Delete message
  static Future<bool> deleteMessage(String chatRoomId, String messageId) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Edit message
  static Future<bool> editMessage(String chatRoomId, String messageId, String newContent) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': newContent,
        'isEdited': true,
        'editedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('Error editing message: $e');
      return false;
    }
  }

  // Update group information
  static Future<void> updateGroupInfo(String chatRoomId, {String? name, String? description}) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;

      if (updateData.isNotEmpty) {
        await _firestore
            .collection('chatRooms')
            .doc(chatRoomId)
            .update(updateData);
      }
    } catch (e) {
      print('Error updating group info: $e');
      throw Exception('Failed to update group info');
    }
  }

  // Add members to group
  static Future<void> addToGroup(String chatRoomId, List<String> userIds) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'participants': FieldValue.arrayUnion(userIds),
      });
    } catch (e) {
      print('Error adding members to group: $e');
      throw Exception('Failed to add members to group');
    }
  }

  // Remove member from group
  static Future<void> removeFromGroup(String chatRoomId, String userId) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'participants': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print('Error removing member from group: $e');
      throw Exception('Failed to remove member from group');
    }
  }

  // Get all users from the users collection
  static Stream<List<UserProfile>> getAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
          .where((user) => user.id != currentUserId) // Exclude current user
          .toList();
    });
  }

  // Get or create direct chat with a user
  static Future<ChatRoom?> getOrCreateDirectChat(String otherUserId) async {
    try {
      // Check if direct chat already exists
      final existingChats = await _firestore
          .collection('chatRooms')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: currentUserId)
          .get();

      // Find existing direct chat with the other user
      for (var doc in existingChats.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId) && participants.length == 2) {
          return ChatRoom.fromMap(doc.data(), doc.id);
        }
      }

      // Create new direct chat if none exists
      final chatRoomId = await createDirectChatRoom(otherUserId);
      if (chatRoomId != null) {
        final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
        if (doc.exists) {
          return ChatRoom.fromMap(doc.data()!, doc.id);
        }
      }
    } catch (e) {
      print('Error getting or creating direct chat: $e');
    }
    return null;
  }

  // Get direct chat stream for real-time updates
  static Stream<ChatRoom?> getDirectChatStream(String otherUserId) {
    if (currentUserId.isEmpty) return Stream.value(null);

    return _firestore
        .collection('chatRooms')
        .where('type', isEqualTo: 'direct')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          // Find the direct chat with the specific user
          for (var doc in snapshot.docs) {
            final participants = List<String>.from(doc.data()['participants'] ?? []);
            if (participants.contains(otherUserId) && participants.length == 2) {
              return ChatRoom.fromMap(doc.data(), doc.id);
            }
          }
          return null;
        });
  }

  // Find existing direct chat without creating one
  static Future<ChatRoom?> findExistingDirectChat(String otherUserId) async {
    try {
      // Check if direct chat already exists
      final existingChats = await _firestore
          .collection('chatRooms')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: currentUserId)
          .get();

      // Find existing direct chat with the other user
      for (var doc in existingChats.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId) && participants.length == 2) {
          return ChatRoom.fromMap(doc.data(), doc.id);
        }
      }
    } catch (e) {
      print('Error finding existing direct chat: $e');
    }
    return null;
  }

  // Get unread message count across all chats
  static Stream<int> getUnreadMessageCount() {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUnread = 0;
      
      for (var doc in snapshot.docs) {
        final chatRoom = ChatRoom.fromMap(doc.data(), doc.id);
        
        // Count unread messages in this chat room
        final unreadQuery = await _firestore
            .collection('chatRooms')
            .doc(chatRoom.id)
            .collection('messages')
            .where('readBy.$currentUserId', isEqualTo: false)
            .where('senderId', isNotEqualTo: currentUserId)
            .get();
            
        totalUnread += unreadQuery.docs.length;
      }
      
      return totalUnread;
    });
  }

  // Get unread message count for a specific chat room
  static Stream<int> getUnreadMessageCountForChat(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('readBy.$currentUserId', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
