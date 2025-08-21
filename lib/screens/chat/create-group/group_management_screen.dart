import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/screens/chat/add-member/add_members_screen.dart';
import '../model/chat_models.dart';
import '../services/chat_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const GroupManagementScreen({Key? key, required this.chatRoom}) : super(key: key);

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.chatRoom.name;
    _groupDescriptionController.text = widget.chatRoom.description ?? '';
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isAdmin = widget.chatRoom.createdBy == currentUserId;
  }

  Future<void> _updateGroupInfo() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ChatService.updateGroupInfo(
        widget.chatRoom.id,
        name: _groupNameController.text.trim(),
        description: _groupDescriptionController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group info updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating group info: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String userId) async {
    // Check if current user is admin
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only group admins can remove members')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Use the enhanced method that sends system messages
      await ChatService.removeMemberFromGroup(widget.chatRoom.id, userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMembers() async {
    // Check if current user is admin
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only group admins can add members')),
      );
      return;
    }

    // Get the current participants from the latest stream data
    final chatRoomStream = ChatService.getChatRoomStream(widget.chatRoom.id);
    final currentChatRoom = await chatRoomStream.first;
    if (currentChatRoom == null) return;

    final participants = await ChatService.getParticipantProfiles(currentChatRoom.participants);

    final result = await Navigator.push<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersScreen(
          chatRoom: currentChatRoom,
          currentParticipants: participants,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final participantIds = result.map((user) => user.id).toList();
        // Use the enhanced method that sends system messages
        await ChatService.addMembersToGroup(widget.chatRoom.id, participantIds);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Members added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding members: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        await ChatService.removeFromGroup(widget.chatRoom.id, currentUserId);
        
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left group successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving group: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        actions: [
          if (_isAdmin)
            TextButton(
              onPressed: _isLoading ? null : _updateGroupInfo,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Information',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _groupNameController,
                            decoration: const InputDecoration(
                              labelText: 'Group Name',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _isAdmin,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _groupDescriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            enabled: _isAdmin,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Members Section
                  StreamBuilder<ChatRoom?>(
                    stream: ChatService.getChatRoomStream(widget.chatRoom.id),
                    builder: (context, chatRoomSnapshot) {
                      final currentChatRoom = chatRoomSnapshot.data ?? widget.chatRoom;
                      
                      return StreamBuilder<List<UserProfile>>(
                        stream: ChatService.getParticipantProfilesStream(currentChatRoom.participants),
                        builder: (context, participantsSnapshot) {
                          if (participantsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            );
                          }
                          
                          final participants = participantsSnapshot.data ?? [];
                          
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Members (${participants.length})',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      if (_isAdmin)
                                        TextButton.icon(
                                          onPressed: _addMembers,
                                          icon: const Icon(Icons.person_add),
                                          label: const Text('Add'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: participants.length,
                                    itemBuilder: (context, index) {
                                      final participant = participants[index];
                                      final isCurrentUser = participant.id == FirebaseAuth.instance.currentUser?.uid;
                                      final isCreator = participant.id == currentChatRoom.createdBy;

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Stack(
                                          children: [
                                            CircleAvatar(
                                              backgroundImage: participant.photoURL != null
                                                  ? NetworkImage(participant.photoURL!)
                                                  : null,
                                              child: participant.photoURL == null
                                                  ? Text(
                                                      participant.displayName.isNotEmpty
                                                          ? participant.displayName[0].toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    )
                                                  : null,
                                            ),
                                            if (participant.isOnline)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        title: Text(participant.displayName),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${participant.email ?? 'No email'}'),
                                            if (isCreator)
                                              Text(
                                                'Group Admin',
                                                style: TextStyle(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: _isAdmin && !isCurrentUser && !isCreator
                                            ? IconButton(
                                                onPressed: () => _removeMember(participant.id),
                                                icon: const Icon(Icons.remove_circle_outline),
                                                color: Colors.red,
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Danger Zone
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Danger Zone',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _leaveGroup,
                              icon: const Icon(Icons.exit_to_app, color: Colors.red),
                              label: const Text(
                                'Leave Group',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
