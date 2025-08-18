import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<UserProfile>? selectedUsers;

  const CreateGroupScreen({Key? key, this.selectedUsers}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _selectedUsers = [];
  List<UserProfile> _availableUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedUsers = List.from(widget.selectedUsers ?? []);
    _loadUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      // Listen to the stream of all users
      ChatService.getAllUsers().listen((users) {
        if (mounted) {
          setState(() {
            _availableUsers = users;
            _filteredUsers = users;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 member')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final participantIds = [currentUser.uid, ..._selectedUsers.map((u) => u.id)];

      final chatRoomId = await ChatService.createGroupChatRoom(
        name: _groupNameController.text.trim(),
        description: _groupDescriptionController.text.trim().isEmpty 
            ? null 
            : _groupDescriptionController.text.trim(),
        participantIds: participantIds,
      );

      if (mounted) {
        Navigator.pop(context, chatRoomId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Group'),
            if (_selectedUsers.isNotEmpty)
              Text(
                '${_selectedUsers.length} members selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group Info Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter group name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _groupDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter group description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),

          // Selected Members Section
          if (_selectedUsers.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Selected Members (${_selectedUsers.length})',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _selectedUsers[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: user.photoURL != null
                                        ? NetworkImage(user.photoURL!)
                                        : null,
                                    child: user.photoURL == null
                                        ? Text(
                                            user.displayName.isNotEmpty
                                                ? user.displayName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () => _toggleUserSelection(user),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  user.displayName,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Search Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Members',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users to add...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onChanged: _filterUsers,
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Users count header
                      if (_filteredUsers.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          child: Text(
                            '${_filteredUsers.where((user) => user.id != FirebaseAuth.instance.currentUser?.uid).length} users available',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      
                      Expanded(
                        child: _filteredUsers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty 
                                          ? 'No users found' 
                                          : 'No users match your search',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  final isSelected = _selectedUsers.any((u) => u.id == user.id);
                                  final currentUser = FirebaseAuth.instance.currentUser;
                                  final isCurrentUser = user.id == currentUser?.uid;

                                  if (isCurrentUser) {
                                    return const SizedBox.shrink();
                                  }

                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    elevation: isSelected ? 2 : 0,
                                    color: isSelected 
                                        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                                        : null,
                                    child: ListTile(
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
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
                                          if (user.isOnline)
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
                                      title: Text(
                                        user.displayName,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        user.email ?? 'No email',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => _toggleUserSelection(user),
                                        activeColor: theme.colorScheme.primary,
                                      ),
                                      onTap: () => _toggleUserSelection(user),
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
