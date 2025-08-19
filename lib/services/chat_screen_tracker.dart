import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';

class ChatScreenTracker {
  static bool _isInChatScreens = false;
  static String? _currentChatScreen;
  
  // Chat-related screens that should mark user as "online"
  static const Set<String> _chatScreens = {
    'chat_screen',
    'chat_room_screen', 
    'create_group_screen',
    'group_management_screen',
    'add_members_screen',
  };

  static bool get isInChatScreens => _isInChatScreens;
  static String? get currentChatScreen => _currentChatScreen;

  // Call this when entering a chat screen
  static Future<void> enterChatScreen(String screenName) async {
    if (_chatScreens.contains(screenName)) {
      _isInChatScreens = true;
      _currentChatScreen = screenName;
      
      print('📱 Entered chat screen: $screenName');
      print('📱 User is now in chat screens - should NOT receive notifications');
      
      // Update user's chat online status in Firestore
      await _updateChatOnlineStatus(true);
    }
  }

  // Call this when leaving a chat screen
  static Future<void> exitChatScreen(String screenName) async {
    if (_chatScreens.contains(screenName) && _currentChatScreen == screenName) {
      _isInChatScreens = false;
      _currentChatScreen = null;
      
      print('📱 Exited chat screen: $screenName');
      print('📱 User is now OUT of chat screens - should receive notifications');
      
      // Update user's chat online status in Firestore
      await _updateChatOnlineStatus(false);
    }
  }

  // Update chat-specific online status in Firestore
  static Future<void> _updateChatOnlineStatus(bool isInChatScreens) async {
    try {
      final userId = ChatService.currentUserId;
      if (userId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isChatOnline': isInChatScreens,
        'lastChatActivity': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      print('✅ Updated chat online status: $isInChatScreens');
    } catch (e) {
      print('❌ Error updating chat online status: $e');
    }
  }

  // Check if a specific user is in chat screens
  static Future<bool> isUserInChatScreens(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final isChatOnline = data['isChatOnline'] as bool? ?? false;
        final lastChatActivity = data['lastChatActivity'] as Timestamp?;
        
        if (isChatOnline && lastChatActivity != null) {
          // Consider user offline if no activity in last 30 seconds
          final timeDiff = DateTime.now().difference(lastChatActivity.toDate()).inSeconds;
          if (timeDiff > 30) {
            print('🕐 User $userId considered offline due to inactivity (${timeDiff}s ago)');
            return false;
          }
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking user chat online status: $e');
      return false;
    }
  }

  // Initialize chat screen tracking (call this once in app)
  static Future<void> initialize() async {
    _isInChatScreens = false;
    _currentChatScreen = null;
    await _updateChatOnlineStatus(false);
    print('📱 Chat screen tracker initialized');
  }
}
