// Screen for adding new members to a group
import 'package:flutter/material.dart';
import 'package:timex/screens/chat/model/chat_models.dart';
import 'package:timex/screens/chat/services/chat_service.dart';
import '../../../widgets/text/text.dart';

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
          SnackBar(
            content: txt(
              'Error loading users: $e',
              style: TxtStl.bodyText2(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: txt(
          'Add Members',
          style: TxtStl.titleText2(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _selectedUsers.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selectedUsers),
              style: TextButton.styleFrom(
                backgroundColor: _selectedUsers.isEmpty 
                    ? const Color(0xFFE2E8F0) 
                    : const Color(0xFF10B981),
                foregroundColor: _selectedUsers.isEmpty 
                    ? const Color(0xFF94A3B8) 
                    : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: txt(
                'Add (${_selectedUsers.length})',
                style: TxtStl.bodyText1(
                  color: _selectedUsers.isEmpty 
                      ? const Color(0xFF94A3B8) 
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    txt(
                      'Search Users',
                      style: TxtStl.bodyText1(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users to add...',
                    hintStyle: TxtStl.bodyText3(color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _filterUsers,
                ),
              ],
            ),
          ),

          // Selected Users Summary
          if (_selectedUsers.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: txt(
                      '${_selectedUsers.length} user${_selectedUsers.length == 1 ? '' : 's'} selected to add',
                      style: TxtStl.bodyText1(
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Users List
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        if (_filteredUsers.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.people,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                txt(
                                  '${_filteredUsers.length} user${_filteredUsers.length == 1 ? '' : 's'} available',
                                  style: TxtStl.bodyText3(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Users List or Empty State
                        Expanded(
                          child: _filteredUsers.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      txt(
                                        _searchQuery.isEmpty 
                                            ? 'No users available to add' 
                                            : 'No users match your search',
                                        style: TxtStl.bodyText1(
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      txt(
                                        _searchQuery.isEmpty 
                                            ? 'All available users are already group members'
                                            : 'Try a different search term',
                                        style: TxtStl.bodyText3(
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    final isSelected = _selectedUsers.any((u) => u.id == user.id);

                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF10B981).withOpacity(0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? const Color(0xFF10B981).withOpacity(0.3)
                                              : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        leading: Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected 
                                                      ? const Color(0xFF10B981)
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                                                    ? NetworkImage(user.photoURL!)
                                                    : null,
                                                backgroundColor: const Color(0xFF8B5CF6),
                                                child: user.photoURL == null || user.photoURL!.isEmpty
                                                    ? txt(
                                                        user.displayName.isNotEmpty
                                                            ? user.displayName[0].toUpperCase()
                                                            : 'U',
                                                        style: TxtStl.bodyText1(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            if (user.isOnline)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        title: txt(
                                          user.displayName,
                                          style: TxtStl.bodyText1(
                                            color: const Color(0xFF1E293B),
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: txt(
                                          user.email ?? 'No email',
                                          style: TxtStl.bodyText3(
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        trailing: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            size: 16,
                                            color: isSelected ? Colors.white : Colors.transparent,
                                          ),
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
          ),
        ],
      ),
    );
  }
}
