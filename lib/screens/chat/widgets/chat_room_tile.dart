import 'package:flutter/material.dart';
import '../../../models/chat_models.dart';
import '../../../services/chat_service.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom chatRoom;
  final VoidCallback onTap;

  const ChatRoomTile({
    Key? key,
    required this.chatRoom,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: _buildAvatar(),
        title: Text(
          chatRoom.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
      ),
    );
  }

  Widget _buildAvatar() {
    if (chatRoom.type == 'group') {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Icon(
          Icons.group,
          color: Colors.white,
          size: 24,
        ),
      );
    } else {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            chatRoom.name.isNotEmpty ? chatRoom.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSubtitle() {
    if (chatRoom.lastMessage == null || chatRoom.lastMessage!.isEmpty) {
      return Text(
        chatRoom.type == 'group'
            ? '${chatRoom.participants.length} гишүүн'
            : 'Мессеж байхгүй',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
      );
    }

    return Row(
      children: [
        if (chatRoom.lastMessageSender == ChatService.currentUserId)
          const Icon(
            Icons.done_all,
            size: 16,
            color: Color(0xFF10B981),
          ),
        if (chatRoom.lastMessageSender == ChatService.currentUserId)
          const SizedBox(width: 4),
        Expanded(
          child: Text(
            chatRoom.lastMessage!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (chatRoom.lastMessageTime != null)
          Text(
            _formatTime(chatRoom.lastMessageTime!),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 4),
        // Unread indicator (you can implement unread count logic later)
        if (chatRoom.lastMessage != null && 
            chatRoom.lastMessageSender != ChatService.currentUserId)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'өчигдөр';
      if (difference.inDays < 7) return '${difference.inDays} өдрийн өмнө';
      return '${time.day}/${time.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}ц';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}м';
    } else {
      return 'одоо';
    }
  }
}
