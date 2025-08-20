import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timex/screens/chat/group_management_screen.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomScreen({Key? key, required this.chatRoom}) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<UserProfile> _participants = [];
  Message? _replyToMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadParticipants();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    final participants = await ChatService.getParticipantProfiles(
      widget.chatRoom.participants,
    );
    setState(() {
      _participants = participants;
    });
  }

  void _markAsRead() {
    ChatService.markMessagesAsRead(widget.chatRoom.id);
    // Clear notifications for this chat
    NotificationService.clearChatNotifications(widget.chatRoom.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mark messages as read when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('📤 Sending message: $content');

      final success = await ChatService.sendMessage(
        chatRoomId: widget.chatRoom.id,
        content: content,
        replyToId: _replyToMessage?.id,
      );

      if (success) {
        _messageController.clear();
        _replyToMessage = null;
        _scrollToBottom();
      } else {
        _showError('Мессеж илгээхэд алдаа гарлаа');
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      _showError('Мессеж илгээхэд алдаа гарлаа: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  Widget _buildTopTab(String text, IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? const Color(0xFF9C27B0) : Colors.black,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF9C27B0) : Colors.black,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (widget.chatRoom.type == 'group') {
      return FutureBuilder<List<UserProfile>>(
        future: ChatService.getParticipantProfiles(
          widget.chatRoom.participants,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF8B5CF6),
                  child: const Icon(Icons.group, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chatRoom.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Group Chat',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final participants = snapshot.data ?? [];
          final otherParticipants = participants
              .where((p) => p.id != ChatService.currentUserId)
              .take(2)
              .toList();

          Widget groupAvatar;
          if (otherParticipants.length >= 2) {
            // Show first 2 users' images overlapping
            groupAvatar = SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage:
                            otherParticipants[0].photoURL != null &&
                                otherParticipants[0].photoURL!.isNotEmpty
                            ? NetworkImage(otherParticipants[0].photoURL!)
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child:
                            otherParticipants[0].photoURL == null ||
                                otherParticipants[0].photoURL!.isEmpty
                            ? Text(
                                otherParticipants[0].displayName.isNotEmpty
                                    ? otherParticipants[0].displayName
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage:
                            otherParticipants[1].photoURL != null &&
                                otherParticipants[1].photoURL!.isNotEmpty
                            ? NetworkImage(otherParticipants[1].photoURL!)
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child:
                            otherParticipants[1].photoURL == null ||
                                otherParticipants[1].photoURL!.isNotEmpty
                            ? Text(
                                otherParticipants[1].displayName.isNotEmpty
                                    ? otherParticipants[1].displayName
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Fallback to group icon
            groupAvatar = CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF8B5CF6),
              child: const Icon(Icons.group, color: Colors.white, size: 20),
            );
          }

          return Row(
            children: [
              groupAvatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatRoom.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.chatRoom.participants.length} members',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } else {
      // For direct chats, show the other user's avatar
      final otherParticipant = _participants.firstWhere(
        (p) => p.id != ChatService.currentUserId,
        orElse: () => UserProfile(
          id: '',
          displayName: widget.chatRoom.name,
          email: '',
          isOnline: false,
        ),
      );

      return Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: otherParticipant.isOnline
                    ? const Color(0xFF10B981)
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundImage:
                  otherParticipant.photoURL != null &&
                      otherParticipant.photoURL!.isNotEmpty
                  ? NetworkImage(otherParticipant.photoURL!)
                  : null,
              backgroundColor: const Color(0xFF8B5CF6),
              child:
                  otherParticipant.photoURL == null ||
                      otherParticipant.photoURL!.isEmpty
                  ? Text(
                      otherParticipant.displayName.isNotEmpty
                          ? otherParticipant.displayName
                                .substring(0, 1)
                                .toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherParticipant.displayName.isNotEmpty
                      ? otherParticipant.displayName
                      : widget.chatRoom.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    if (otherParticipant.isOnline)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (otherParticipant.isOnline) const SizedBox(width: 6),
                    Text(
                      otherParticipant.isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: const Color(
          0xFF9C27B0,
        ), // Purple color like in the image
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.chatRoom.type == 'group')
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        GroupManagementScreen(chatRoom: widget.chatRoom),
                  ),
                );
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Go back to chats tab
                      _tabController.animateTo(0);
                    },
                    child: _buildTopTab(
                      'Chats',
                      Icons.chat_bubble_outline,
                      true,
                    ), // Active since we're in chat
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Go back to messages tab
                      _tabController.animateTo(1);
                    },
                    child: _buildTopTab('Messages', Icons.message, false),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Go back to groups tab
                      _tabController.animateTo(2);
                    },
                    child: _buildTopTab('Groups', Icons.group, false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: ChatService.getChatMessages(widget.chatRoom.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8B5CF6),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Мессеж ачаалахад алдаа гарлаа',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Мессеж байхгүй байна',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Эхний мессежийг илгээгээрэй',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == ChatService.currentUserId;
                    final isLastMessage =
                        index == 0; // Since reversed, first item is the latest

                    // Check if this is a system message
                    if (message.isSystemMessage) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSystemMessageBubble(message),
                      );
                    }

                    // Check if this is a deleted message
                    if (message.isDeleted) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDeletedMessageBubble(message, isMe),
                      );
                    }

                    // Find the sender's profile for avatar and name
                    final senderProfile = _participants.firstWhere(
                      (p) => p.id == message.senderId,
                      orElse: () => UserProfile(
                        id: message.senderId,
                        displayName: message.senderName,
                        email: '',
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          _buildMessageBubble(message, isMe, senderProfile),
                          // Show read receipt under the last message from current user
                          if (isMe && isLastMessage)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 16),
                              child: _buildReadReceiptStatus(message),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Reply Preview
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyToMessage!.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyToMessage!.content,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _cancelReply,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Message message,
    bool isMe,
    UserProfile senderProfile,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  senderProfile.photoURL != null &&
                      senderProfile.photoURL!.isNotEmpty
                  ? NetworkImage(senderProfile.photoURL!)
                  : null,
              backgroundColor: const Color(0xFF8B5CF6),
              child:
                  senderProfile.photoURL == null ||
                      senderProfile.photoURL!.isEmpty
                  ? Text(
                      senderProfile.displayName.isNotEmpty
                          ? senderProfile.displayName
                                .substring(0, 1)
                                .toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Show sender name in group chats (not for current user)
                if (!isMe && widget.chatRoom.type == 'group') ...[
                  Text(
                    senderProfile.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () => _showMessageOptions(message),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.isEdited
                                  ? '${message.content} (edited)'
                                  : message.content,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                                fontSize: 15,
                                fontStyle: message.isEdited
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.spaceBetween
                                  : MainAxisAlignment.start,
                              children: [
                                if (!isMe &&
                                    message.votes.isNotEmpty &&
                                    widget.chatRoom.type == 'group') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      message.votes.length.toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _formatMessageTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                if (isMe &&
                                    message.votes.isNotEmpty &&
                                    widget.chatRoom.type == 'group') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      message.votes.length.toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Show vote display for group chats - removed as it's now inside the bubble
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildSystemMessageBubble(Message message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDeletedMessageBubble(Message message, bool isMe) {
    final currentUserId = ChatService.currentUserId;
    final deletedByCurrentUser = message.senderId == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                deletedByCurrentUser
                    ? 'You deleted a message'
                    : '${message.senderName} deleted a message',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(Message message) {
    final currentUserId = ChatService.currentUserId;
    final isMe = message.senderId == currentUserId;
    final hasVoted = message.votes.containsKey(currentUserId);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show vote/unvote option for group chats
            if (widget.chatRoom.type == 'group')
              ListTile(
                leading: Icon(
                  hasVoted ? Icons.thumb_down : Icons.thumb_up,
                  color: const Color(0xFF8B5CF6),
                ),
                title: Text(hasVoted ? 'Unvote' : 'Vote'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleVote(message);
                },
              ),
            // Show edit/delete options only for own messages
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editMessage(Message message) {
    final TextEditingController editController = TextEditingController(
      text: message.content,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                Navigator.pop(context);

                final success = await ChatService.editMessage(
                  chatRoomId: widget.chatRoom.id,
                  messageId: message.id,
                  newContent: newContent,
                );

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message edited successfully'),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to edit message')),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ChatService.deleteMessage(
                chatRoomId: widget.chatRoom.id,
                messageId: message.id,
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete message')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleVote(Message message) async {
    final currentUserId = ChatService.currentUserId;
    final hasVoted = message.votes.containsKey(currentUserId);

    if (hasVoted) {
      // Remove vote if already voted
      await ChatService.removeVoteFromMessage(
        chatRoomId: widget.chatRoom.id,
        messageId: message.id,
      );
    } else {
      // Add vote (using 'vote' as the reaction type)
      await ChatService.voteOnMessage(
        chatRoomId: widget.chatRoom.id,
        messageId: message.id,
        reaction: 'vote',
      );
    }
  }

  Widget _buildReadReceiptStatus(Message message) {
    if (widget.chatRoom.type == 'group') {
      // Group chat: show "Seen by name1, name2, +X"
      final readByUsers = message.readBy.entries
          .where(
            (entry) => entry.key != ChatService.currentUserId && entry.value,
          )
          .map((entry) => entry.key)
          .toList();

      if (readByUsers.isEmpty) {
        return const Text(
          'Not seen',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        );
      }

      final readByNames = readByUsers
          .take(2)
          .map((userId) {
            final participant = _participants.firstWhere(
              (p) => p.id == userId,
              orElse: () =>
                  UserProfile(id: userId, displayName: 'Unknown', email: ''),
            );
            return participant.displayName;
          })
          .where((name) => name != 'Unknown')
          .toList();

      String displayText = 'Seen by ${readByNames.join(', ')}';
      if (readByUsers.length > 2) {
        displayText += ', +${readByUsers.length - 2}';
      }

      return Text(
        displayText,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    } else {
      // Direct chat: show "Seen X ago" or "Not seen"
      final otherUserId = widget.chatRoom.participants.firstWhere(
        (id) => id != ChatService.currentUserId,
      );

      if (message.readBy[otherUserId] == true) {
        // Calculate time ago - this is simplified, in a real app you'd store read timestamps
        return const Text(
          'Seen',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        );
      } else {
        return const Text(
          'Not seen',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        );
      }
    }
  }
}
