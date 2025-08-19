import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_models.dart';
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
  List<UserProfile> _participants = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.chatRoom.name;
    _groupDescriptionController.text = widget.chatRoom.description ?? '';
    _loadParticipants();
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

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    try {
      final participants = await ChatService.getParticipantProfiles(widget.chatRoom.participants);
      setState(() {
        _participants = participants;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading participants: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
      await ChatService.removeMemberFromGroup(widget.chatRoom.id, userId);
      await _loadParticipants();
      
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
    final result = await Navigator.push<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersScreen(
          chatRoom: widget.chatRoom,
          currentParticipants: _participants,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final participantIds = result.map((user) => user.id).toList();
        await ChatService.addMembersToGroup(widget.chatRoom.id, participantIds);
        await _loadParticipants();
        
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
      await ChatService.leaveGroup(widget.chatRoom.id);
      
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left group successfully')),
        );
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Members (${_participants.length})',
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
                            itemCount: _participants.length,
                            itemBuilder: (context, index) {
                              final participant = _participants[index];
                              final isCurrentUser = participant.id == FirebaseAuth.instance.currentUser?.uid;
                              final isCreator = participant.id == widget.chatRoom.createdBy;

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
                                    Text('${participant.email}'),
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
      print('🔍 Loading users for adding to group...');
      print('   Current group participants: ${widget.currentParticipants.length}');
      for (var p in widget.currentParticipants) {
        print('   - ${p.displayName} (${p.id})');
      }
      
      List<UserProfile> allUsers = [];
      
      try {
        // Try to get all users first
        final userStream = ChatService.getAllUsers();
        allUsers = await userStream.first;
        print('📋 Got ${allUsers.length} total users from database');
        
        for (var user in allUsers) {
          print('   - ${user.displayName} (${user.id}) - ${user.email}');
        }
      } catch (e) {
        print('❌ Error getting all users: $e');
        // Fallback to search with common letters
        final searches = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];
        for (String letter in searches) {
          final searchResults = await ChatService.searchUsers(letter);
          allUsers.addAll(searchResults);
        }
        // Remove duplicates
        allUsers = allUsers.toSet().toList();
        print('📋 Got ${allUsers.length} users from search fallback');
      }

      // Filter out current user and existing group members
      final currentUserId = ChatService.currentUserId;
      final participantIds = widget.currentParticipants.map((p) => p.id).toList();
      
      print('🔍 Filtering users...');
      print('   Current user ID: $currentUserId');
      print('   Group participant IDs: $participantIds');
      
      final availableUsers = allUsers.where((user) {
        final isCurrentUser = user.id == currentUserId;
        final isGroupMember = participantIds.contains(user.id);
        
        print('   Checking ${user.displayName} (${user.id}):');
        print('     - Is current user: $isCurrentUser');
        print('     - Is group member: $isGroupMember');
        print('     - Should include: ${!isCurrentUser && !isGroupMember}');
        
        return !isCurrentUser && !isGroupMember;
      }).toList();
      
      setState(() {
        _availableUsers = availableUsers;
        _filteredUsers = _availableUsers;
      });
      
      print('✅ Final result: ${_availableUsers.length} users available to add');
      for (var user in _availableUsers) {
        print('   ✓ ${user.displayName} (${user.email})');
      }
      
    } catch (e) {
      print('❌ Error loading users: $e');
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
                user.email!.toLowerCase().contains(query.toLowerCase()))
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
                            subtitle: Text('${user.email}'),
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
