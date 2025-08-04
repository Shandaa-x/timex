import 'package:flutter/material.dart';
import 'package:timex/index.dart';

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

    final args = settings.arguments;

    switch (settings.name) {
      case Routes.main:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        route = MaterialPageRoute(
          builder: (context) => MainScreen(
            userName: args['userName'] ?? 'Guest',
            userImage: args['userImage'],
          ),
          settings: settings,
        );
        break;
      case Routes.location:
        route = MaterialPageRoute(builder: (context) => const LocationScreen(), settings: settings);
        break;
      case Routes.loginScreen:
        route = MaterialPageRoute(builder: (context) => const LoginScreen(), settings: settings);
        break;
      case Routes.timeTrack:
        route = MaterialPageRoute(builder: (context) => const TimeTrackingScreen(), settings: settings);
        break;
      case Routes.addEmployee:
      // Attempt to cast the arguments to Map<String, dynamic> for organizationData
        if (args is Map<String, dynamic>) {
          route = MaterialPageRoute(
            builder: (context) => AddEmployeeScreen(organizationData: args),
            settings: settings,
          );
        } else {
          // Handle the case where organizationData is missing or of the wrong type
          route = MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: Text(
                  'Error: Organization data not provided for AddEmployeeScreen.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }
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
    last = MaterialPageRoute(builder: (context) => Container(), settings: lastRouteSettings);
  }

  static void saveLastRoute(Route? lastRoute, String from, {Route? previousRoute}) async {
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
