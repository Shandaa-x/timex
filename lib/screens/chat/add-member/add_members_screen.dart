// Screen for adding new members to a group
import 'package:flutter/material.dart';
import 'package:timex/screens/chat/model/chat_models.dart';
import 'package:timex/screens/chat/services/chat_service.dart';

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
