import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final String? senderName;
  final String? senderPhotoURL;
  final String? replyToMessage;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = false,
    this.senderName,
    this.senderPhotoURL,
    this.replyToMessage,
    this.onReply,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: senderPhotoURL != null && senderPhotoURL!.isNotEmpty
                  ? NetworkImage(senderPhotoURL!)
                  : null,
              backgroundColor: const Color(0xFF3B82F6),
              child: senderPhotoURL == null || senderPhotoURL!.isEmpty
                  ? Text(
                      senderName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(context),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && senderName != null && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        senderName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomRight: isMe ? const Radius.circular(4) : null,
                        bottomLeft: !isMe ? const Radius.circular(4) : null,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyToId != null && replyToMessage != null)
                          _buildReplyIndicator(context),
                        if (message.type == 'text')
                          _buildTextMessage(context)
                        else if (message.type == 'image')
                          _buildImageMessage(context)
                        else
                          _buildFileMessage(context),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe 
                                  ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                            if (isMe && message.readBy.containsKey('currentUserId')) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: theme.colorScheme.onPrimary.withOpacity(0.7),
                              ),
                            ] else if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done,
                                size: 14,
                                color: theme.colorScheme.onPrimary.withOpacity(0.7),
                              ),
                            ],
                            if (message.isEdited) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(edited)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: isMe 
                                    ? theme.colorScheme.onPrimary.withOpacity(0.5)
                                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe && showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              child: Text(
                senderName?.substring(0, 1).toUpperCase() ?? 'M',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isMe 
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurfaceVariant).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.secondary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        replyToMessage!,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isMe 
            ? theme.colorScheme.onPrimary.withOpacity(0.8)
            : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTextMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 14,
        color: isMe 
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // For now, we'll show a placeholder since attachmentUrl doesn't exist in our model
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 48),
                SizedBox(height: 8),
                Text('Image Message'),
              ],
            ),
          ),
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              fontSize: 14,
              color: isMe 
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isMe 
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurfaceVariant).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file,
            size: 20,
            color: isMe 
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.content.isNotEmpty ? message.content : 'File attachment',
              style: TextStyle(
                fontSize: 14,
                color: isMe 
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  onReply?.call();
                },
              ),
            if (isMe && onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
            if (isMe && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}
