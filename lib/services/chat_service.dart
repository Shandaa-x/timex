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
      final chatRoomId = docRef.id;
      
      // Send system message for group creation
      await _sendSystemMessage(
        chatRoomId: chatRoomId,
        content: 'You created the group',
        targetUserId: currentUserId,
      );
      
      // Send system messages to added members
      for (String participantId in participantIds) {
        await _sendSystemMessage(
          chatRoomId: chatRoomId,
          content: '${currentUser.displayName} added you to the group',
          targetUserId: participantId,
        );
      }
      
      return chatRoomId;
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
        .asyncMap((snapshot) async {
          // Check if current user is still a member of the chat room
          final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
          if (!chatRoomDoc.exists) return <Message>[];
          
          final chatRoomData = chatRoomDoc.data()!;
          final participants = List<String>.from(chatRoomData['participants'] ?? []);
          
          // If current user is not a participant, they can't see messages
          if (!participants.contains(currentUserId)) {
            return <Message>[];
          }
          
          return snapshot.docs.map((doc) {
            final message = Message.fromMap(doc.data(), doc.id);
            return {'message': message, 'data': doc.data()};
          }).where((item) {
            final message = item['message'] as Message;
            
            // Show all non-system messages
            if (message.senderId != 'system') return true;
            
            // For system messages, check visibility rules
            return message.canUserSeeMessage(currentUserId);
          }).map((item) => item['message'] as Message).toList();
        });
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String chatRoomId) async {
    // Use the new method to mark all messages as read
    await markAllMessagesAsRead(chatRoomId);
  }

  // Mark messages as read up to a specific message
  static Future<void> markMessagesAsReadUpTo(String chatRoomId, String messageId) async {
    try {
      // Get all messages in the chat room ordered by timestamp
      final messagesQuery = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      final messages = messagesQuery.docs;
      final batch = _firestore.batch();
      
      // Find the target message and mark all messages up to it as read
      bool foundTarget = false;
      final readTimestamp = DateTime.now();
      
      for (var doc in messages) {
        // Mark this message as read by current user with timestamp
        batch.update(doc.reference, {
          'readBy.$currentUserId': true,
          'readTimestamp.$currentUserId': readTimestamp,
        });
        
        // If this is the target message, stop here
        if (doc.id == messageId) {
          foundTarget = true;
          break;
        }
      }

      if (foundTarget || messages.isNotEmpty) {
        await batch.commit();
        
        // Update the chat room's last read message for this user
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'lastReadBy.$currentUserId': messageId.isEmpty ? messages.last.id : messageId,
        });
      }
    } catch (e) {
      print('Error marking messages as read up to $messageId: $e');
    }
  }

  // Mark all messages as read (when user enters chat room)
  static Future<void> markAllMessagesAsRead(String chatRoomId) async {
    try {
      // Get the latest message ID
      final latestMessageQuery = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latestMessageQuery.docs.isNotEmpty) {
        final latestMessageId = latestMessageQuery.docs.first.id;
        await markMessagesAsReadUpTo(chatRoomId, latestMessageId);
      }
    } catch (e) {
      print('Error marking all messages as read: $e');
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

  // Edit message
  static Future<bool> editMessage({
    required String chatRoomId,
    required String messageId,
    required String newContent,
  }) async {
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

      // Update chat room's last message if it's the most recent one
      final latestMessage = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latestMessage.docs.isNotEmpty && 
          latestMessage.docs.first.id == messageId) {
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'lastMessage': newContent,
        });
      }

      return true;
    } catch (e) {
      print('Error editing message: $e');
      return false;
    }
  }

  // Delete message (mark as deleted instead of removing)
  static Future<bool> deleteMessage({
    required String chatRoomId,
    required String messageId,
  }) async {
    try {
      // Mark message as deleted instead of removing it
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'content': '', // Clear the original content for privacy
      });

      // Update chat room's last message if it was the most recent one
      final messages = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messages.docs.isNotEmpty) {
        final latestMessage = Message.fromMap(messages.docs.first.data(), messages.docs.first.id);
        
        String lastMessage;
        if (latestMessage.isDeleted) {
          // Store deleted message with both sender ID and name for proper display
          lastMessage = '${latestMessage.senderId}|${latestMessage.senderName}:DELETED_MESSAGE';
        } else {
          lastMessage = latestMessage.content;
        }
        
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'lastMessage': lastMessage,
          'lastMessageTime': latestMessage.timestamp,
          'lastMessageSender': latestMessage.senderId,
        });
      } else {
        // No messages left
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'lastMessage': null,
          'lastMessageTime': null,
          'lastMessageSender': null,
        });
      }

      return true;
    } catch (e) {
      print('Error deleting message: $e');
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

  // Get user profile by ID
  static Future<UserProfile?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      print('Error getting user profile: $e');
    }
    return null;
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

  // Send system message for group events
  static Future<void> _sendSystemMessage({
    required String chatRoomId,
    required String content,
    String? targetUserId, // For messages sent to specific users
  }) async {
    try {
      final message = {
        'content': content,
        'senderId': 'system',
        'senderName': 'System',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'isDeleted': false,
        'isEdited': false,
        'targetUserId': targetUserId, // Only this user will see the message
      };

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(message);

      // Update chat room's last message
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(), // Fixed: use lastMessageTime instead of lastMessageTimestamp
        'lastMessageSender': 'system', // Fixed: use lastMessageSender instead of lastMessageSenderId
      });
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  // Send system message excluding a specific user
  static Future<void> _sendSystemMessageExcludingUser({
    required String chatRoomId,
    required String content,
    required String excludeUserId,
  }) async {
    try {
      final message = {
        'content': content,
        'senderId': 'system',
        'senderName': 'System',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'isDeleted': false,
        'isEdited': false,
        'excludeUserId': excludeUserId, // This user won't see the message
      };

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(message);

      // Update chat room's last message
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(), // Fixed: use lastMessageTime instead of lastMessageTimestamp
        'lastMessageSender': 'system', // Fixed: use lastMessageSender instead of lastMessageSenderId
      });
    } catch (e) {
      print('Error sending system message excluding user: $e');
    }
  }

  // Leave group
  static Future<void> leaveGroup(String chatRoomId) async {
    try {
      final currentUser = await getUserProfile(currentUserId);
      final userName = currentUser?.displayName ?? 'User';
      
      // Remove user from participants
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'participants': FieldValue.arrayRemove([currentUserId]),
      });

      // Send system message
      await _sendSystemMessage(
        chatRoomId: chatRoomId,
        content: '$userName left the group',
      );
    } catch (e) {
      print('Error leaving group: $e');
      throw Exception('Failed to leave group');
    }
  }

  // Add members to group with system messages
  static Future<void> addMembersToGroup(String chatRoomId, List<String> userIds) async {
    try {
      final currentUser = await getUserProfile(currentUserId);
      final currentUserName = currentUser?.displayName ?? 'Admin';
      
      // Add users to participants
      await addToGroup(chatRoomId, userIds);

      // Send system messages
      for (String userId in userIds) {
        final addedUser = await getUserProfile(userId);
        final addedUserName = addedUser?.displayName ?? 'User';
        
        // Message for the added user (only they will see this)
        await _sendSystemMessage(
          chatRoomId: chatRoomId,
          content: '$currentUserName added you to the group',
          targetUserId: userId,
        );
        
        // General message for the group (everyone EXCEPT the added user will see this)
        await _sendSystemMessageExcludingUser(
          chatRoomId: chatRoomId,
          content: '$currentUserName added $addedUserName to the group',
          excludeUserId: userId,
        );
      }
    } catch (e) {
      print('Error adding members to group: $e');
      throw Exception('Failed to add members to group');
    }
  }

  // Remove member from group with system messages
  static Future<void> removeMemberFromGroup(String chatRoomId, String userId) async {
    try {
      final currentUser = await getUserProfile(currentUserId);
      final removedUser = await getUserProfile(userId);
      final currentUserName = currentUser?.displayName ?? 'Admin';
      final removedUserName = removedUser?.displayName ?? 'User';
      
      // Remove user from participants
      await removeFromGroup(chatRoomId, userId);

      // Message for the removed user
      await _sendSystemMessage(
        chatRoomId: chatRoomId,
        content: '$currentUserName removed you from the group',
        targetUserId: userId,
      );
      
      // General message for the group
      await _sendSystemMessage(
        chatRoomId: chatRoomId,
        content: '$currentUserName removed $removedUserName from the group',
      );
    } catch (e) {
      print('Error removing member from group: $e');
      throw Exception('Failed to remove member from group');
    }
  }

  // Get chat room stream for real-time updates
  static Stream<ChatRoom?> getChatRoomStream(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return ChatRoom.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  // Get all users for adding to groups (excludes current user and existing group members)
  static Future<List<UserProfile>> getAllUsersForGroupAdd([List<String>? existingMemberIds]) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .get();

      final allUsers = querySnapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
          .where((user) => user.id != currentUserId) // Exclude current user
          .toList();

      if (existingMemberIds != null && existingMemberIds.isNotEmpty) {
        // Also exclude existing group members
        return allUsers.where((user) => !existingMemberIds.contains(user.id)).toList();
      }

      return allUsers;
    } catch (e) {
      print('Error getting all users for group add: $e');
      return [];
    }
  }

  // Get the last message read by each user in a chat room
  static Stream<Map<String, String>> getLastReadMessages(String chatRoomId) {
    return _firestore.collection('chatRooms').doc(chatRoomId).snapshots().map((doc) {
      final data = doc.data();
      if (data?['lastReadBy'] != null) {
        return Map<String, String>.from(data!['lastReadBy']);
      }
      return <String, String>{};
    });
  }

  // Check if a user has read up to a specific message
  static Future<bool> hasUserReadUpToMessage(String chatRoomId, String userId, String messageId) async {
    try {
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      final lastReadBy = chatRoomDoc.data()?['lastReadBy'] as Map<String, dynamic>?;
      
      if (lastReadBy == null || !lastReadBy.containsKey(userId)) {
        return false;
      }

      final lastReadMessageId = lastReadBy[userId] as String;
      
      // Get the timestamps of both messages to compare
      final messages = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .where(FieldPath.documentId, whereIn: [lastReadMessageId, messageId])
          .get();

      if (messages.docs.length < 2) return false;

      final lastReadMessage = messages.docs.firstWhere((doc) => doc.id == lastReadMessageId);
      final targetMessage = messages.docs.firstWhere((doc) => doc.id == messageId);

      final lastReadTimestamp = lastReadMessage.data()['timestamp'] as Timestamp;
      final targetTimestamp = targetMessage.data()['timestamp'] as Timestamp;

      // User has read up to this message if their last read message is this message or later
      return lastReadTimestamp.compareTo(targetTimestamp) >= 0;
    } catch (e) {
      print('Error checking if user read up to message: $e');
      return false;
    }
  }

  // Get real-time message read status
  static Stream<Map<String, dynamic>> getMessageReadStatus(String chatRoomId, String messageId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return {};
      
      final data = snapshot.data() as Map<String, dynamic>;
      
      // Extract read timestamps
      Map<String, dynamic> readTimestamps = {};
      data.forEach((key, value) {
        if (key.startsWith('readTimestamp.')) {
          final userId = key.substring('readTimestamp.'.length);
          readTimestamps[userId] = value;
        }
      });
      
      return {
        'readBy': data['readBy'] ?? {},
        'readTimestamps': readTimestamps,
        'timestamp': data['timestamp'],
      };
    });
  }

  // Vote/react on a message
  static Future<bool> voteOnMessage({
    required String chatRoomId,
    required String messageId,
    required String reaction, // '👍', '❤️', '😂', etc.
  }) async {
    try {
      final currentUser = ChatService.currentUserId;
      if (currentUser.isEmpty) return false;

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'votes.$currentUser': reaction,
      });

      return true;
    } catch (e) {
      print('Error voting on message: $e');
      return false;
    }
  }

  // Remove vote/reaction from a message
  static Future<bool> removeVoteFromMessage({
    required String chatRoomId,
    required String messageId,
  }) async {
    try {
      final currentUser = ChatService.currentUserId;
      if (currentUser.isEmpty) return false;

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'votes.$currentUser': FieldValue.delete(),
      });

      return true;
    } catch (e) {
      print('Error removing vote from message: $e');
      return false;
    }
  }
}
