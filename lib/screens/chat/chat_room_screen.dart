import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import 'widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomScreen({Key? key, required this.chatRoom}) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<UserProfile> _participants = [];
  Message? _replyToMessage;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    final participants = await ChatService.getParticipantProfiles(widget.chatRoom.participants);
    setState(() {
      _participants = participants;
    });
  }

  void _markAsRead() {
    ChatService.markMessagesAsRead(widget.chatRoom.id);
    // Clear notifications for this chat
    NotificationService.clearChatNotifications(widget.chatRoom.id);
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setReplyMessage(Message message) {
    setState(() {
      _replyToMessage = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  String _getChatTitle() {
    if (widget.chatRoom.type == 'group') {
      return widget.chatRoom.name;
    } else {
      // For direct chats, show the other participant's name
      final otherParticipant = _participants.firstWhere(
        (p) => p.id != ChatService.currentUserId,
        orElse: () => UserProfile(
          id: '',
          displayName: 'Unknown User',
          email: '',
        ),
      );
      return otherParticipant.displayName;
    }
  }

  String _getChatSubtitle() {
    if (widget.chatRoom.type == 'group') {
      return '${widget.chatRoom.participants.length} гишүүн';
    } else {
      final otherParticipant = _participants.firstWhere(
        (p) => p.id != ChatService.currentUserId,
        orElse: () => UserProfile(
          id: '',
          displayName: '',
          email: '',
          isOnline: false,
        ),
      );
      return otherParticipant.isOnline ? 'Онлайн' : 'Оффлайн';
    }
  }

  Widget _buildAppBarTitle() {
    if (widget.chatRoom.type == 'group') {
      return Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.group,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getChatTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getChatSubtitle(),
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
    } else {
      // For direct chats, show the other participant's image and name
      final otherParticipant = _participants.firstWhere(
        (p) => p.id != ChatService.currentUserId,
        orElse: () => UserProfile(
          id: '',
          displayName: 'Unknown User',
          email: '',
        ),
      );
      
      return Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: otherParticipant.isOnline ? const Color(0xFF10B981) : Colors.white24, 
                width: 2.5
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: otherParticipant.photoURL != null && otherParticipant.photoURL!.isNotEmpty
                  ? NetworkImage(otherParticipant.photoURL!)
                  : null,
              backgroundColor: const Color(0xFF8B5CF6),
              child: otherParticipant.photoURL == null || otherParticipant.photoURL!.isEmpty
                  ? Text(
                      otherParticipant.displayName.isNotEmpty
                          ? otherParticipant.displayName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
                  _getChatTitle(),
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
                    if (otherParticipant.isOnline) const SizedBox(width: 6),                      Text(
                        _getChatSubtitle(),
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
        backgroundColor: const Color(0xFF8B5CF6), // Purple color like in the image
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.chatRoom.type == 'group')
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // TODO: Show group info
              },
            ),
        ],
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
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
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == ChatService.currentUserId;
                    
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
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MessageBubble(
                        message: message,
                        isMe: isMe,
                        showAvatar: !isMe,
                        senderName: senderProfile.displayName,
                        senderPhotoURL: senderProfile.photoURL,
                        onReply: () => _setReplyMessage(message),
                        onDelete: () async {
                          if (isMe) {
                            await ChatService.deleteMessage(widget.chatRoom.id, message.id);
                          }
                        },
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(25),
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
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 50,
                    width: 50,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                      onPressed: _isLoading ? null : _sendMessage,
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
}
