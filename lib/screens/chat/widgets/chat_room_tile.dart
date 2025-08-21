import 'package:flutter/material.dart';
import '../../../widgets/text/text.dart';
import '../model/chat_models.dart';
import '../services/chat_service.dart';

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
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
      ),
    );
  }

  Widget _buildAvatar() {
    if (chatRoom.type == 'group') {
      return StreamBuilder<List<UserProfile>>(
        stream: ChatService.getParticipantProfilesStream(chatRoom.participants),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.group,
                color: Colors.white,
                size: 24,
              ),
            );
          }
          
          final participants = snapshot.data ?? [];
          final otherParticipants = participants
              .where((p) => p.id != ChatService.currentUserId)
              .take(2)
              .toList();
          
          // Check if any group member (except current user) is online
          final hasOnlineMembers = participants
              .where((p) => p.id != ChatService.currentUserId)
              .any((p) => p.isOnline);
          
          Widget avatarWidget;
          if (otherParticipants.length >= 2) {
            // Show first 2 users' images overlapping
            avatarWidget = SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: otherParticipants[0].photoURL != null && 
                                         otherParticipants[0].photoURL!.isNotEmpty
                            ? NetworkImage(otherParticipants[0].photoURL!)
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: otherParticipants[0].photoURL == null || 
                               otherParticipants[0].photoURL!.isEmpty
                            ? txt(
                                otherParticipants[0].displayName.isNotEmpty
                                    ? otherParticipants[0].displayName.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: TxtStl.labelText3(
                                  color: Colors.white,
                                  fontSize: 10,
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: otherParticipants[1].photoURL != null && 
                                         otherParticipants[1].photoURL!.isNotEmpty
                            ? NetworkImage(otherParticipants[1].photoURL!)
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: otherParticipants[1].photoURL == null || 
                               otherParticipants[1].photoURL!.isEmpty
                            ? txt(
                                otherParticipants[1].displayName.isNotEmpty
                                    ? otherParticipants[1].displayName.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: TxtStl.labelText3(
                                  color: Colors.white,
                                  fontSize: 10,
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
            // Fallback to group icon if less than 2 other participants
            avatarWidget = Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.group,
                color: Colors.white,
                size: 24,
              ),
            );
          }
          
          // Wrap with online indicator for groups
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.transparent,
                    width: 2,
                  ),
                ),
                child: avatarWidget,
              ),
              // Online indicator dot for group
              if (hasOnlineMembers)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      // For direct chats, show the other user's avatar with real-time status
      final otherParticipantId = chatRoom.participants
          .firstWhere((id) => id != ChatService.currentUserId, orElse: () => '');
      
      if (otherParticipantId.isEmpty) {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 24,
          ),
        );
      }

      return StreamBuilder<UserProfile?>(
        stream: ChatService.getUserProfileStream(otherParticipantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            );
          }
          
          final otherParticipant = snapshot.data ?? UserProfile(
            id: otherParticipantId,
            displayName: chatRoom.name,
            email: '',
            isOnline: false,
          );
          
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundImage: otherParticipant.photoURL != null && 
                                   otherParticipant.photoURL!.isNotEmpty
                      ? NetworkImage(otherParticipant.photoURL!)
                      : null,
                  backgroundColor: const Color(0xFF8B5CF6),
                  child: otherParticipant.photoURL == null || 
                         otherParticipant.photoURL!.isEmpty
                      ? txt(
                          otherParticipant.displayName.isNotEmpty
                              ? otherParticipant.displayName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: TxtStl.titleText2(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              // Online indicator dot for direct chat
              if (otherParticipant.isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
  }

  Widget _buildTitle() {
    if (chatRoom.type == 'direct') {
      // For direct chats, show the other participant's name
      final otherParticipantId = chatRoom.participants
          .firstWhere((id) => id != ChatService.currentUserId, orElse: () => '');
      
      if (otherParticipantId.isEmpty) {
        // Fallback to chat room name if no other participant found
        return txt(
          chatRoom.name,
          style: TxtStl.bodyText4(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      return StreamBuilder<UserProfile?>(
        stream: ChatService.getUserProfileStream(otherParticipantId),
        builder: (context, snapshot) {
          final otherParticipant = snapshot.data ?? UserProfile(
            id: otherParticipantId,
            displayName: chatRoom.name,
            email: '',
            isOnline: false,
          );
          
          return txt(
            otherParticipant.displayName.isNotEmpty 
                ? otherParticipant.displayName 
                : chatRoom.name,
            style: TxtStl.bodyText4(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    } else {
      // For group chats, use the chat room name
      return txt(
        chatRoom.name,
        style: TxtStl.bodyText4(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: const Color(0xFF1E293B),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  Widget _buildSubtitle() {
    if (chatRoom.lastMessage == null || chatRoom.lastMessage!.isEmpty) {
      return txt(
        chatRoom.type == 'group'
            ? '${chatRoom.participants.length} гишүүн'
            : 'Мессеж байхгүй',
        style: TxtStl.bodyText3(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
      );
    }

    // Check if this is a system message by checking the lastMessageSender
    final isSystemMessage = chatRoom.lastMessageSender == 'system';

    return Row(
      children: [
        // Don't show "You sent" icon for system messages
        if (!isSystemMessage && chatRoom.lastMessageSender == ChatService.currentUserId)
          const Icon(
            Icons.done_all,
            size: 16,
            color: Color(0xFF10B981),
          ),
        if (!isSystemMessage && chatRoom.lastMessageSender == ChatService.currentUserId)
          const SizedBox(width: 4),
        Expanded(
          child: txt(
            chatRoom.lastMessage!,
            style: TxtStl.bodyText3(
              color: isSystemMessage 
                  ? Colors.grey.shade500  // Make system messages slightly more muted
                  : Colors.grey.shade600,
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
          txt(
            _formatTime(chatRoom.lastMessageTime!),
            style: TxtStl.labelText2(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 4),
        // Unread indicator - don't show for system messages or messages sent by current user
        if (chatRoom.lastMessage != null && 
            chatRoom.lastMessageSender != ChatService.currentUserId &&
            chatRoom.lastMessageSender != 'system')
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
