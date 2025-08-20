class ChatRoom {
  final String id;
  final String type; // 'direct' or 'group'
  final String name;
  final String? description;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSender;
  final Map<String, dynamic>? groupSettings;
  final Map<String, String>? lastReadBy; // userId -> messageId mapping
  final DateTime createdAt;
  final String createdBy;

  ChatRoom({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSender,
    this.groupSettings,
    this.lastReadBy,
    required this.createdAt,
    required this.createdBy,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: id,
      type: map['type'] ?? 'direct',
      name: map['name'] ?? '',
      description: map['description'],
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime']?.toDate(),
      lastMessageSender: map['lastMessageSender'],
      groupSettings: map['groupSettings'],
      lastReadBy: map['lastReadBy'] != null 
          ? Map<String, String>.from(map['lastReadBy']) 
          : null,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'description': description,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastMessageSender': lastMessageSender,
      'groupSettings': groupSettings,
      'lastReadBy': lastReadBy,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}

class Message {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String content;
  final String type; // 'text', 'image', 'file', 'system'
  final DateTime timestamp;
  final Map<String, bool> readBy;
  final bool isEdited;
  final DateTime? editedAt;
  final String? replyToId;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? targetUserId; // For system messages visible to specific users only
  final String? excludeUserId; // For system messages excluding specific users
  final Map<String, String> votes; // userId -> emoji/reaction type

  Message({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.type = 'text',
    required this.timestamp,
    this.readBy = const {},
    this.isEdited = false,
    this.editedAt,
    this.replyToId,
    this.isDeleted = false,
    this.deletedAt,
    this.targetUserId,
    this.excludeUserId,
    this.votes = const {},
  });

  // Check if current user can see this message
  bool canUserSeeMessage(String userId) {
    // If message is deleted, don't show it
    if (isDeleted) return false;
    
    // If it's a targeted message, only show to target user
    if (targetUserId != null) {
      return targetUserId == userId;
    }
    
    // If it excludes a user, don't show to that user
    if (excludeUserId != null) {
      return excludeUserId != userId;
    }
    
    // Otherwise, show to all users
    return true;
  }
  
  // Check if this is a system message
  bool get isSystemMessage => senderId == 'system' || type == 'system';

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      chatRoomId: map['chatRoomId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      readBy: Map<String, bool>.from(map['readBy'] ?? {}),
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt']?.toDate(),
      replyToId: map['replyToId'],
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: map['deletedAt']?.toDate(),
      targetUserId: map['targetUserId'],
      excludeUserId: map['excludeUserId'],
      votes: Map<String, String>.from(map['votes'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type,
      'timestamp': timestamp,
      'readBy': readBy,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'replyToId': replyToId,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'targetUserId': targetUserId,
      'excludeUserId': excludeUserId,
      'votes': votes,
    };
  }
}

class UserProfile {
  final String id;
  final String displayName;
  final String? email;
  final String? photoURL;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.photoURL,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      displayName: map['displayName'] ?? map['profile']?['displayName'] ?? '',
      email: map['email'] ?? map['profile']?['email'],
      photoURL: map['photoURL'] ?? map['profile']?['photoURL'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen']?.toDate(),
    );
  }
}
