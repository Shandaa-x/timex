import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';

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
      List<UserProfile> users = [];

      try {
        // Try to get all users first - direct approach
        final userStream = ChatService.getAllUsers();
        final allUsers = await userStream.first;
        print('📋 Got ${allUsers.length} total users from database');
        
        // Filter out current user and existing group members
        final currentUserId = ChatService.currentUserId;
        final participantIds = widget.currentParticipants.map((p) => p.id).toList();
        
        print('🔍 Filtering users...');
        print('   Current user ID: $currentUserId');
        print('   Group participant IDs: $participantIds');
        
        users = allUsers.where((user) {
          final isCurrentUser = user.id == currentUserId;
          final isGroupMember = participantIds.contains(user.id);
          
          print('   Checking ${user.displayName} (${user.id}):');
          print('     - Is current user: $isCurrentUser');
          print('     - Is group member: $isGroupMember');
          print('     - Should include: ${!isCurrentUser && !isGroupMember}');
          
          return !isCurrentUser && !isGroupMember;
        }).toList();
        
        print('🔍 Got ${users.length} users after filtering');
      } catch (e) {
        print('⚠️ getAllUsersForGroupAdd failed, trying getAllUsers: $e');
        try {
          users = await ChatService.getAllUsers().first;
          print('🔍 Got users from getAllUsers: ${users.length}');
          
          // Filter manually if the service method failed
          final participantIds = widget.currentParticipants.map((p) => p.id).toList();
          final currentUserId = ChatService.currentUserId;
          
          users = users.where((user) {
            return user.id != currentUserId && !participantIds.contains(user.id);
          }).toList();
        } catch (e2) {
          print('⚠️ getAllUsers failed, trying searchUsers fallback: $e2');
          // Last fallback: try searchUsers with various letters
          final searches = [
            'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
            'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
          ];
          for (String letter in searches) {
            final searchResults = await ChatService.searchUsers(letter);
            users.addAll(searchResults);
          }
          // Remove duplicates and filter
          users = users.toSet().toList();
          
          final participantIds = widget.currentParticipants.map((p) => p.id).toList();
          final currentUserId = ChatService.currentUserId;
          
          users = users.where((user) {
            return user.id != currentUserId && !participantIds.contains(user.id);
          }).toList();
          
          print('� Got users from searchUsers fallback: ${users.length}');
        }
      }

      setState(() {
        _availableUsers = users;
        _filteredUsers = _availableUsers;

        print('✅ Available users to add: ${_availableUsers.length}');
        for (var user in _availableUsers) {
          print('   - ${user.displayName} (${user.email})');
        }
      });
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
            .where(
              (user) =>
                  user.displayName.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (user.email?.toLowerCase().contains(query.toLowerCase()) ??
                      false),
            )
            .toList();
      }
      print('🔍 Search query: "$query" - Found ${_filteredUsers.length} users');
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
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _selectedUsers.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedUsers),
            child: Text(
              _selectedUsers.isEmpty ? 'Add' : 'Add (${_selectedUsers.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select users to add to "${widget.chatRoom.name}"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current members: ${widget.currentParticipants.length}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9C27B0)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF9C27B0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(
                    color: Color(0xFF9C27B0),
                    width: 2,
                  ),
                ),
              ),
              onChanged: _filterUsers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF9C27B0),
                      ),
                    ),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.group_add
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users available to add\nAll users are already in this group'
                              : 'No users match your search',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Results count
                      if (_filteredUsers.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            '${_filteredUsers.length} user${_filteredUsers.length != 1 ? 's' : ''} available to add',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      // User list
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final isSelected = _selectedUsers.any(
                              (u) => u.id == user.id,
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected
                                    ? const Color(0xFF9C27B0).withOpacity(0.05)
                                    : Colors.white,
                              ),
                              child: CheckboxListTile(
                                secondary: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage:
                                          user.photoURL != null &&
                                              user.photoURL!.isNotEmpty
                                          ? NetworkImage(user.photoURL!)
                                          : null,
                                      backgroundColor: const Color(0xFF9C27B0),
                                      child:
                                          user.photoURL == null ||
                                              user.photoURL!.isEmpty
                                          ? Text(
                                              user.displayName.isNotEmpty
                                                  ? user.displayName[0]
                                                        .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                    // Online status indicator
                                    if (user.isOnline)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.email ?? 'No email',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      user.isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                        color: user.isOnline
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                value: isSelected,
                                activeColor: const Color(0xFF9C27B0),
                                onChanged: (_) => _toggleUserSelection(user),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
