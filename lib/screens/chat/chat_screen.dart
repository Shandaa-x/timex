import 'package:flutter/material.dart';
import 'model/chat_models.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'widgets/chat_room_tile.dart';
import 'chatroom/chat_room_screen.dart';
import 'create-group/create_group_screen.dart';

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
    _tabController = TabController(length: 3, vsync: this); // Changed from 2 to 3
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Чат',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF9C27B0), // Purple color from the image
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

              // Manual initialization of notification listeners
              // await NotificationService.manuallyInitializeListeners();

              // Debug current user's FCM token
              await NotificationService.debugCheckFCMToken();

              // Force refresh current user's device token
              print('🔔 Force refreshing current user device token...');
              await NotificationService.forceRefreshDeviceToken();

              // Debug all users with FCM tokens
              await NotificationService.debugListAllFCMTokens();

              // Specifically check the problematic receiver from the logs
              print('🔔 Checking receiver device status: IjLl3CSTwaTN4tM42yRNxakxDYx1');
              await NotificationService.debugCheckReceiverDevices('IjLl3CSTwaTN4tM42yRNxakxDYx1');

              // Try to send a test notification to the receiver
              print('🔔 Testing direct notification to IjLl3CSTwaTN4tM42yRNxakxDYx1...');
              await NotificationService.debugSendNotificationToUser(
                'IjLl3CSTwaTN4tM42yRNxakxDYx1',
                'This is a test notification from debug',
              );

              // Send test local notification on current device
              await NotificationService.sendTestNotification();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Debug complete! Manual listener init + FCM analysis done. Check for notifications!',
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            tooltip: 'Test Notification & Advanced Debug',
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
      floatingActionButton:
          _tabController.index ==
              2 // Show FAB only on Groups tab (index 2)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF8B5CF6),
              child: const Icon(Icons.group_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildAllChatsList() {
    return StreamBuilder<List<ChatRoom>>(
      stream: ChatService.getUserChatRooms(), // Get all chats (already sorted by lastMessageTime)
      builder: (context, chatSnapshot) {
        return StreamBuilder<List<UserProfile>>(
          stream: ChatService.getAllUsers(),
          builder: (context, userSnapshot) {
            // if (chatSnapshot.connectionState == ConnectionState.waiting ||
            //     userSnapshot.connectionState == ConnectionState.waiting) {
            //   return const Center(
            //     child: CircularProgressIndicator(
            //       valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            //     ),
            //   );
            // }

            if (chatSnapshot.hasError || userSnapshot.hasError) {
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

            final List<ChatRoom> existingChatRooms = chatSnapshot.data ?? [];
            final List<UserProfile> allUsers = userSnapshot.data ?? [];

            // Separate chat rooms into those with messages and those without
            final chatRoomsWithMessages = existingChatRooms
                .where((chat) => chat.lastMessage != null && chat.lastMessage!.isNotEmpty)
                .toList();

            final chatRoomsWithoutMessages = existingChatRooms
                .where((chat) => chat.lastMessage == null || chat.lastMessage!.isEmpty)
                .toList();

            // Sort rooms without messages by creation time (or name if no creation time)
            chatRoomsWithoutMessages.sort((a, b) {
              return b.createdAt.compareTo(a.createdAt); // Most recent created first
            });

            // Filter out current user
            final otherUsers = allUsers
                .where((user) => user.id != ChatService.currentUserId)
                .toList();

            // Get users who don't have existing chat rooms yet
            final existingDirectChatUserIds = existingChatRooms
                .where((chat) => chat.type == 'direct')
                .expand((chat) => chat.participants)
                .where((id) => id != ChatService.currentUserId)
                .toSet();

            final usersWithoutChats = otherUsers
                .where((user) => !existingDirectChatUserIds.contains(user.id))
                .toList();

            if (chatRoomsWithMessages.isEmpty && chatRoomsWithoutMessages.isEmpty && usersWithoutChats.isEmpty) {
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

            // Combine all items in order: chats with messages -> chats without messages -> users without chats
            final totalItems = chatRoomsWithMessages.length + chatRoomsWithoutMessages.length + usersWithoutChats.length;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (index < chatRoomsWithMessages.length) {
                  // Show chat rooms with messages first (sorted by lastMessageTime)
                  final chatRoom = chatRoomsWithMessages[index];
                  return _buildChatRoomTile(chatRoom);
                } else if (index < chatRoomsWithMessages.length + chatRoomsWithoutMessages.length) {
                  // Show chat rooms without messages second
                  final chatRoom = chatRoomsWithoutMessages[index - chatRoomsWithMessages.length];
                  return _buildChatRoomTile(chatRoom);
                } else {
                  // Show users without existing chats last
                  final user = usersWithoutChats[index - chatRoomsWithMessages.length - chatRoomsWithoutMessages.length];
                  return _buildUserTile(user);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUserChatsList() {
    return StreamBuilder<List<ChatRoom>>(
      stream: ChatService.getUserDirectChatRooms(), // Get only direct chats (already sorted by lastMessageTime)
      builder: (context, chatSnapshot) {
        return StreamBuilder<List<UserProfile>>(
          stream: ChatService.getAllUsers(),
          builder: (context, userSnapshot) {
            // if (chatSnapshot.connectionState == ConnectionState.waiting ||
            //     userSnapshot.connectionState == ConnectionState.waiting) {
            //   return const Center(
            //     child: CircularProgressIndicator(
            //       valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            //     ),
            //   );
            // }

            if (chatSnapshot.hasError || userSnapshot.hasError) {
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

            final List<ChatRoom> existingDirectChats = chatSnapshot.data ?? [];
            final List<UserProfile> allUsers = userSnapshot.data ?? [];

            // Separate direct chats into those with messages and those without
            final directChatsWithMessages = existingDirectChats
                .where((chat) => chat.lastMessage != null && chat.lastMessage!.isNotEmpty)
                .toList();

            final directChatsWithoutMessages = existingDirectChats
                .where((chat) => chat.lastMessage == null || chat.lastMessage!.isEmpty)
                .toList();

            // Sort chats without messages by creation time
            directChatsWithoutMessages.sort((a, b) {
              return b.createdAt.compareTo(a.createdAt); // Most recent created first
            });

            // Filter out current user
            final otherUsers = allUsers
                .where((user) => user.id != ChatService.currentUserId)
                .toList();

            // Get users who don't have existing direct chats yet
            final existingDirectChatUserIds = existingDirectChats
                .expand((chat) => chat.participants)
                .where((id) => id != ChatService.currentUserId)
                .toSet();

            final usersWithoutDirectChats = otherUsers
                .where((user) => !existingDirectChatUserIds.contains(user.id))
                .toList();

            if (directChatsWithMessages.isEmpty && directChatsWithoutMessages.isEmpty && usersWithoutDirectChats.isEmpty) {
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Combine all items in order: chats with messages -> chats without messages -> users without chats
            final totalItems = directChatsWithMessages.length + directChatsWithoutMessages.length + usersWithoutDirectChats.length;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (index < directChatsWithMessages.length) {
                  // Show direct chats with messages first (sorted by lastMessageTime)
                  final chatRoom = directChatsWithMessages[index];
                  return _buildChatRoomTile(chatRoom);
                } else if (index < directChatsWithMessages.length + directChatsWithoutMessages.length) {
                  // Show direct chats without messages second
                  final chatRoom = directChatsWithoutMessages[index - directChatsWithMessages.length];
                  return _buildChatRoomTile(chatRoom);
                } else {
                  // Show users without existing direct chats last
                  final user = usersWithoutDirectChats[index - directChatsWithMessages.length - directChatsWithoutMessages.length];
                  return _buildUserTile(user);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatRoomTile(ChatRoom chatRoom) {
    return ChatRoomTile(
      chatRoom: chatRoom,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(chatRoom: chatRoom),
          ),
        );
      },
    );
  }

  Widget _buildGroupChatList() {
    return StreamBuilder<List<ChatRoom>>(
      stream: ChatService.getUserGroupChatRooms(),
      builder: (context, snapshot) {
        // if (snapshot.connectionState == ConnectionState.waiting) {
        //   return const Center(
        //     child: CircularProgressIndicator(
        //       valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        //     ),
        //   );
        // }

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
                  style: TextStyle(color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        List<ChatRoom> chatRooms = snapshot.data ?? [];

        // Separate into groups with and without messages
        List<ChatRoom> groupsWithMessages = [];
        List<ChatRoom> groupsWithoutMessages = [];

        // Filter by search query first
        if (_searchQuery.isNotEmpty) {
          chatRooms = chatRooms
              .where(
                (room) =>
                    room.name.toLowerCase().contains(_searchQuery) ||
                    (room.lastMessage?.toLowerCase().contains(_searchQuery) ??
                        false),
              )
              .toList();
          // For search results, show all matching groups regardless of message status
          groupsWithMessages = chatRooms.where((room) => room.lastMessage != null && room.lastMessage!.isNotEmpty).toList();
          groupsWithoutMessages = chatRooms.where((room) => room.lastMessage == null || room.lastMessage!.isEmpty).toList();
        } else {
          // When not searching, separate all groups
          groupsWithMessages = chatRooms.where((room) => room.lastMessage != null && room.lastMessage!.isNotEmpty).toList();
          groupsWithoutMessages = chatRooms.where((room) => room.lastMessage == null || room.lastMessage!.isEmpty).toList();
        }

        // Sort groups without messages by creation time
        groupsWithoutMessages.sort((a, b) {
          return b.createdAt.compareTo(a.createdAt); // Most recent created first
        });

        // Combine the lists: groups with messages first, then groups without messages
        final allGroups = [...groupsWithMessages, ...groupsWithoutMessages];

        if (allGroups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.grey.shade400),
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
                  style: TextStyle(color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: allGroups.length,
          itemBuilder: (context, index) {
            final chatRoom = allGroups[index];
            return _buildChatRoomTile(chatRoom);
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
            const SizedBox(height: 4),
            Text(
              label,
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
