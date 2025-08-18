import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import 'widgets/chat_room_tile.dart';
import 'chat_room_screen.dart';
import 'create_group_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB based on current tab
    });
    WidgetsBinding.instance.addObserver(this);
    _updateOnlineStatus(true);
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _updateOnlineStatus(state == AppLifecycleState.resumed);
  }

  void _updateOnlineStatus(bool isOnline) {
    ChatService.updateOnlineStatus(isOnline);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Чат',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Чат хайх...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                tabs: const [
                  Tab(text: 'Бүгд'),
                  Tab(text: 'Бүлэг'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(), // Show all users in "Бүгд" tab
          _buildGroupChatList(), // Show group chats in "Бүлэг" tab
        ],
      ),
      floatingActionButton: _tabController.index == 1 // Show FAB only on Group tab
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF3B82F6),
              child: const Icon(Icons.group_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<UserProfile>>(
      stream: ChatService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Алдаа гарлаа',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        List<UserProfile> users = snapshot.data ?? [];

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          users = users.where((user) =>
              user.displayName.toLowerCase().contains(_searchQuery) ||
              (user.email?.toLowerCase().contains(_searchQuery) ?? false)
          ).toList();
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Хэрэглэгч олдсонгүй'
                      : 'Хэрэглэгч байхгүй байна',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Өөр түлхүүр үг оруулж хайж үзээрэй'
                      : 'Одоогоор хэрэглэгч байхгүй байна',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserTile(user);
          },
        );
      },
    );
  }

  Widget _buildGroupChatList() {
    return StreamBuilder<List<ChatRoom>>(
      stream: ChatService.getUserGroupChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Алдаа гарлаа',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        List<ChatRoom> chatRooms = snapshot.data ?? [];

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          chatRooms = chatRooms.where((room) =>
              room.name.toLowerCase().contains(_searchQuery) ||
              (room.lastMessage?.toLowerCase().contains(_searchQuery) ?? false)
          ).toList();
        }

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Чат олдсонгүй'
                      : 'Бүлгийн чат байхгүй байна',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Өөр түлхүүр үг оруулж хайж үзээрэй'
                      : 'Шинэ бүлгийн чат үүсгэхийн тулд + товчийг дарна уу',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_searchQuery.isEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CreateGroupScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Бүлэг үүсгэх'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = chatRooms[index];
            return ChatRoomTile(
              chatRoom: chatRoom,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatRoomScreen(
                      chatRoom: chatRoom,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile(UserProfile user) {
    return FutureBuilder<ChatRoom?>(
      future: _getExistingDirectChat(user.id),
      builder: (context, chatSnapshot) {
        final chatRoom = chatSnapshot.data;
        final hasConversation = chatRoom != null;
        final lastMessage = chatRoom?.lastMessage;
        final lastMessageSender = chatRoom?.lastMessageSender;
        
        String displayMessage = '';
        if (hasConversation && lastMessage != null && lastMessage.isNotEmpty) {
          if (lastMessageSender == ChatService.currentUserId) {
            displayMessage = 'You: $lastMessage';
          } else {
            displayMessage = '${user.displayName}: $lastMessage';
          }
        } else if (hasConversation) {
          displayMessage = 'Зураг илгээсэн';
        } else {
          displayMessage = 'Чат эхлүүлэх';
        }
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                      ? NetworkImage(user.photoURL!)
                      : null,
                  backgroundColor: const Color(0xFF3B82F6),
                  child: user.photoURL == null || user.photoURL!.isEmpty
                      ? Text(
                          user.displayName.isNotEmpty 
                              ? user.displayName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
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
            ),
            title: Text(
              user.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              displayMessage,
              style: TextStyle(
                color: hasConversation 
                    ? Colors.grey.shade600 
                    : Colors.grey.shade500,
                fontSize: 14,
                fontStyle: !hasConversation ? FontStyle.italic : FontStyle.normal,
                fontWeight: lastMessageSender == ChatService.currentUserId && hasConversation
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chatRoom?.lastMessageTime != null)
                  Text(
                    _formatMessageTime(chatRoom!.lastMessageTime!),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  hasConversation ? Icons.chat : Icons.chat_bubble_outline,
                  color: hasConversation 
                      ? const Color(0xFF3B82F6) 
                      : Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
            onTap: () => _startChatWithUser(user),
          ),
        );
      },
    );
  }

  Future<ChatRoom?> _getExistingDirectChat(String userId) async {
    try {
      return await ChatService.findExistingDirectChat(userId);
    } catch (e) {
      return null;
    }
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      // Today: show time
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Өчигдөр';
    } else if (now.difference(messageDate).inDays < 7) {
      // This week: show day name
      const days = ['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'];
      return days[time.weekday - 1];
    } else {
      // Older: show date
      return '${time.day}/${time.month}';
    }
  }

  void _startChatWithUser(UserProfile user) async {
    try {
      // Check if a direct chat already exists
      final existingChatRoom = await ChatService.getOrCreateDirectChat(user.id);
      
      if (existingChatRoom != null) {
        // Navigate to existing chat
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoom: existingChatRoom,
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Чат эхлүүлэхэд алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
