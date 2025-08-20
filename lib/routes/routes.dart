import 'package:flutter/material.dart';
import 'package:timex/screens/main/login/google_login_screen.dart';
import 'package:timex/screens/main/main_screen.dart';
import 'package:timex/screens/my_news/my_news_screen.dart';
import 'package:timex/screens/time/time_track/time_tracking_screen.dart';
import 'package:timex/screens/main/auth/auth_wrapper.dart';
import 'package:timex/screens/chat/chat_screen.dart';
import 'package:timex/screens/chat/new_chat_screen.dart';
import 'package:timex/screens/chat/create_group_screen.dart';
import 'package:timex/screens/chat/group_management_screen.dart';
import 'package:timex/screens/chat/services/chat_models.dart';

class Routes {
  static const main = 'MainScreen';
  static const location = 'LocationScreen';
  static const loginScreen = 'LoginScreen';
  static const googleLogin = 'GoogleLoginScreen';
  static const timeTrack = 'TimeTracking';
  static const addEmployee = 'AddEmployeeScreen';
  static const authWrapper = 'AuthWrapper';
  static const myNews = 'MyNewsScreen';
  static const chat = 'ChatScreen';
  static const newChat = 'NewChatScreen';
  static const createGroup = 'CreateGroupScreen';
  static const groupManagement = 'GroupManagementScreen';

  final RouteObserver routeObserver;

  Routes() : routeObserver = AppRouteObserver();

  Route<dynamic> getRoute(RouteSettings settings) {
    Route<dynamic> route;

    switch (settings.name) {
      case Routes.googleLogin:
        route = MaterialPageRoute(
          builder: (context) => const GoogleLoginScreen(),
          settings: settings,
        );
        break;
      case Routes.main:
        route = MaterialPageRoute(
          builder: (context) => const MainScreen(),
          settings: settings,
        );
        break;
      case Routes.authWrapper:
        route = MaterialPageRoute(
          builder: (context) => const AuthWrapper(),
          settings: settings,
        );
        break;
      case Routes.timeTrack:
        route = MaterialPageRoute(
          builder: (context) => const TimeTrackScreen(),
          settings: settings,
        );
        break;
      case Routes.myNews:
        route = MaterialPageRoute(
          builder: (context) => const MyNewsScreen(),
          settings: settings,
        );
        break;
      case Routes.chat:
        route = MaterialPageRoute(
          builder: (context) => const ChatScreen(),
          settings: settings,
        );
        break;
      case Routes.newChat:
        route = MaterialPageRoute(
          builder: (context) => const NewChatScreen(),
          settings: settings,
        );
        break;
      case Routes.createGroup:
        route = MaterialPageRoute(
          builder: (context) => CreateGroupScreen(
            selectedUsers: settings.arguments as List<UserProfile>?,
          ),
          settings: settings,
        );
        break;
      case Routes.groupManagement:
        route = MaterialPageRoute(
          builder: (context) => GroupManagementScreen(
            chatRoom: settings.arguments as ChatRoom,
          ),
          settings: settings,
        );
        break;
      default:
        route = MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
        break;
    }
    return route;
  }
}

class AppRouteObserver extends RouteObserver {
  static Route? last;
  static Route? previous;

  static void saveLastRouteSettings(RouteSettings lastRouteSettings) async {
    last = MaterialPageRoute(
      builder: (context) => Container(),
      settings: lastRouteSettings,
    );
  }

  static void saveLastRoute(
    Route? lastRoute,
    String from, {
    Route? previousRoute,
  }) async {
    last = lastRoute;
    previous = previousRoute;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    saveLastRoute(previousRoute, 'didPop', previousRoute: previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    saveLastRoute(route, 'didPush', previousRoute: previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    saveLastRoute(route, 'didRemove', previousRoute: previousRoute);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    saveLastRoute(newRoute, 'didReplace', previousRoute: oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
