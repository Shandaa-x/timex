import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/chat_models.dart';
import '../../services/chat_service.dart';

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

// Screen for adding new members to a group
class AddMembersScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final List<UserProfile> currentParticipants;

  const AddMembersScreen({
    Key? key,
    required this.chatRoom,
    required this.currentParticipants,
  }) : super(key: key);

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _selectedUsers = [];
  List<UserProfile> _availableUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      // Use the stream-based getAllUsers method and convert to Future
      final usersStream = ChatService.getAllUsers();
      final users = await usersStream.first;
      
      final participantIds = widget.currentParticipants.map((p) => p.id).toList();
      final currentUserId = ChatService.currentUserId;
      setState(() {
        // Exclude current group members AND current user
        _availableUsers = users.where((user) => !participantIds.contains(user.id) && user.id != currentUserId).toList();
        _filteredUsers = _availableUsers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = _availableUsers;
      } else {
        _filteredUsers = _availableUsers
            .where((user) =>
                user.displayName.toLowerCase().contains(query.toLowerCase()) ||
                (user.email?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  void _toggleUserSelection(UserProfile user) {
    setState(() {
      if (_selectedUsers.any((u) => u.id == user.id)) {
        _selectedUsers.removeWhere((u) => u.id == user.id);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        actions: [
          TextButton(
            onPressed: _selectedUsers.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedUsers),
            child: Text('Add (${_selectedUsers.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onChanged: _filterUsers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty 
                              ? 'No users available to add' 
                              : 'No users match your search',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isSelected = _selectedUsers.any((u) => u.id == user.id);

                          return CheckboxListTile(
                            secondary: CircleAvatar(
                              backgroundImage: user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              child: user.photoURL == null
                                  ? Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(user.displayName),
                            subtitle: Text('${user.email ?? 'No email'}'),
                            value: isSelected,
                            onChanged: (_) => _toggleUserSelection(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
