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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // TODO: Open drawer
          },
        ),
        actions: [
          // Test notification button
          IconButton(
            icon: const Icon(Icons.notification_add),
            onPressed: () async {
              print('🔔 Testing notifications and debugging...');

              // Debug current user's FCM token
              await NotificationService.debugCheckFCMToken();

              // Try to send a test notification to mungunshand_6
              print('🔔 Testing direct notification to mungunshand_6...');
              await NotificationService.debugSendNotificationToUser(
                'mungunshand_6',
                'This is a test notification from debug',
              );

              // Send test local notification on current device
              await NotificationService.sendTestNotification();
              
              // FORCE show a notification (for immediate testing)
              await NotificationService.debugForceShowNotification(
                'TEST NOTIFICATION', 
                'This should appear immediately!'
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Debug complete! Check console for FCM status.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Test Notification & Debug',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: const Color.fromARGB(255, 255, 255, 255), // Light purple background
            height: 60,              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(0),
                      child: _buildTopTab('Chats', Icons.chat_bubble_outline, _tabController.index == 0),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      child: _buildTopTab('Messages', Icons.message, _tabController.index == 1),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(2),
                      child: _buildTopTab('Groups', Icons.group, _tabController.index == 2),
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllChatsList(), // Tab 0: "Chats" - Show ALL chats (users + groups)
          _buildUserChatsList(), // Tab 1: "Messages" - Show only user-to-user chats  
          _buildGroupChatList(), // Tab 2: "Groups" - Show group chats only
        ],
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem('Home', Icons.home, false),
              _buildBottomNavItem('Search', Icons.search, false),
              _buildBottomNavItem('Chat', Icons.chat, true), // Active tab
              _buildBottomNavItem('Dates', Icons.calendar_today, false),
            ],
          ),
        ),
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

  Widget _buildAllChatsList() {
    return StreamBuilder<List<UserProfile>>(
      stream: ChatService.getAllUsers(),
      builder: (context, userSnapshot) {
        return StreamBuilder<List<ChatRoom>>(
          stream: ChatService.getUserChatRooms(),
          builder: (context, chatSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting ||
                chatSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              );
            }

            if (userSnapshot.hasError || chatSnapshot.hasError) {
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
                  ],
                ),
              );
            }

            final List<UserProfile> allUsers = userSnapshot.data ?? [];
            final List<ChatRoom> groupChats = (chatSnapshot.data ?? [])
                .where((chat) => chat.type == 'group')
                .toList();

            // Filter out current user
            final otherUsers = allUsers
                .where((user) => user.id != ChatService.currentUserId)
                .toList();

            if (otherUsers.isEmpty && groupChats.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Чат байхгүй байна',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: otherUsers.length + groupChats.length,
              itemBuilder: (context, index) {
                if (index < otherUsers.length) {
                  // Show user
                  final user = otherUsers[index];
                  return _buildUserTile(user);
                } else {
                  // Show group chat
                  final groupChat = groupChats[index - otherUsers.length];
                  return _buildChatRoomTile(groupChat);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUserChatsList() {
    return StreamBuilder<List<UserProfile>>(
      stream: ChatService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          );
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
              ],
            ),
          );
        }

        final List<UserProfile> allUsers = snapshot.data ?? [];
        
        // Filter out current user
        final otherUsers = allUsers
            .where((user) => user.id != ChatService.currentUserId)
            .toList();

        if (otherUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Хэрэглэгч байхгүй байна',
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
          itemCount: otherUsers.length,
          itemBuilder: (context, index) {
            final user = otherUsers[index];
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

  Widget _buildTopTab(String text, IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: isActive ? const Color(0xFF9C27B0) : Colors.black
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF9C27B0) : Colors.black,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(String label, IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () {
        // Handle navigation
        print('Tapped $label');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFF9C27B0) : Colors.grey,
            ),
            subtitle: Text(
              displayMessage,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF9C27B0) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(UserProfile user) {
    return StreamBuilder<ChatRoom?>(
      stream: ChatService.getOrCreateDirectChat(user.id).asStream(),
      builder: (context, chatSnapshot) {
        final chatRoom = chatSnapshot.data;
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                    ? NetworkImage(user.photoURL!)
                    : null,
                backgroundColor: const Color(0xFF8B5CF6),
                child: user.photoURL == null || user.photoURL!.isEmpty
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              // Online indicator
              if (user.isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
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
              color: Color(0xFF1F2937),
            ),
          ),
          subtitle: chatRoom?.lastMessage != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (chatRoom!.lastMessageSender == ChatService.currentUserId)
                          const Text(
                            'You: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            chatRoom.lastMessage ?? '',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Text(
                  user.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: user.isOnline ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (chatRoom?.lastMessageTime != null)
                Text(
                  _formatTime(chatRoom!.lastMessageTime!),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 4),
              // TODO: Add unread count when available in ChatRoom model
            ],
          ),
          onTap: () async {
            // Get or create direct chat
            final directChatRoom = await ChatService.getOrCreateDirectChat(user.id);
            if (directChatRoom != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatRoomScreen(chatRoom: directChatRoom),
                ),
              );
            }
          },
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${timestamp.day}/${timestamp.month}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
