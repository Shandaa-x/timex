import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/text/text.dart';
import '../model/chat_models.dart';
import '../services/chat_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            txt(
              'Create Group',
              style: TxtStl.titleText2(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedUsers.isNotEmpty)
              txt(
                '${_selectedUsers.length} members selected',
                style: TxtStl.bodyText3(
                  color: const Color(0xFF64748B),
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _createGroup,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : txt(
                      'Create',
                      style: TxtStl.bodyText1(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Group Info Section
            Container(
            padding: const EdgeInsets.all(20),
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
                txt(
                  'Group Information',
                  style: TxtStl.titleText2(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter group name',
                    labelStyle: TxtStl.bodyText2(color: const Color(0xFF64748B)),
                    hintStyle: TxtStl.bodyText3(color: const Color(0xFF94A3B8)),
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
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _groupDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter group description',
                    labelStyle: TxtStl.bodyText2(color: const Color(0xFF64748B)),
                    hintStyle: TxtStl.bodyText3(color: const Color(0xFF94A3B8)),
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
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.group,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      txt(
                        'Selected Members (${_selectedUsers.length})',
                        style: TxtStl.bodyText1(
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 70,
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
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF8B5CF6),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 22,
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
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () => _toggleUserSelection(user),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 50,
                                child: txt(
                                  user.displayName,
                                  style: TxtStl.labelText2(
                                    color: const Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
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
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        Icons.person_add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    txt(
                      'Add Members',
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

          // Users List
          Container(
            height: 400, // Fixed height for the users list
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
                        // Users count header
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
                                    color: const Color(0xFF10B981),
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
                                  '${_filteredUsers.where((user) => user.id != FirebaseAuth.instance.currentUser?.uid).length} users available',
                                  style: TxtStl.bodyText3(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
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
                                            ? 'No users found' 
                                            : 'No users match your search',
                                        style: TxtStl.bodyText1(
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      txt(
                                        _searchQuery.isEmpty 
                                            ? 'Try refreshing or check your connection'
                                            : 'Try a different search term',
                                        style: TxtStl.bodyText3(
                                          color: const Color(0xFF94A3B8),
                                        ),
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
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    final isCurrentUser = user.id == currentUser?.uid;

                                    if (isCurrentUser) {
                                      return const SizedBox.shrink();
                                    }

                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF8B5CF6).withOpacity(0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? const Color(0xFF8B5CF6).withOpacity(0.3)
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
                                                      ? const Color(0xFF8B5CF6)
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
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFD1D5DB),
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
        ],
        ),
      ),
    );
  }
}
