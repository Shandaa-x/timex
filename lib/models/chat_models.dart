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
  final String type; // 'text', 'image', 'file'
  final DateTime timestamp;
  final Map<String, bool> readBy;
  final bool isEdited;
  final DateTime? editedAt;
  final String? replyToId;

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
  });

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
