import 'package:flutter/material.dart';
import 'package:timex/screens/main/main_screen.dart';
import 'package:timex/screens/time_track/time_tracking_screen.dart';

class Routes {
  static const main = 'MainScreen';
  static const location = 'LocationScreen';
  static const loginScreen = 'LoginScreen';
  static const timeTrack = 'TimeTracking';
  static const addEmployee = 'AddEmployeeScreen';

  final RouteObserver routeObserver;

  Routes() : routeObserver = AppRouteObserver();

  Route<dynamic> getRoute(RouteSettings settings) {
    Route<dynamic> route;

    switch (settings.name) {
      case Routes.main:
        route = MaterialPageRoute(
          builder: (context) => const MainScreen(),
          settings: settings,
        );
        break;
      case Routes.timeTrack:
        route = MaterialPageRoute(
          builder: (context) => const TimeTrackScreen(),
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
