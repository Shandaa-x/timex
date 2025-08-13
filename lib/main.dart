import 'dart:async';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:timex/index.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timex/screens/auth/auth_wrapper.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Load environment variables
      try {
        await dotenv.load(fileName: '.env');
        log('✅ Environment variables loaded successfully');
      } catch (e) {
        log('⚠️ Warning: Could not load .env file: $e');
        // Continue with default values
      }

      Assets.refresh();

      await _initializeNotifications(); // 💡 Notification init here

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        log('✅ Firebase initialized successfully');
      } catch (e, stackTrace) {
        log('❌ Firebase initialization failed: $e');
        log('Stack trace: $stackTrace');
      }

      runApp(const MyApp());
    },
    (error, stackTrace) {
      log('runZonedGuarded: error: $error, stackTrace: $stackTrace');
    },
  );
}

Future<void> _initializeNotifications() async {
  // ✅ Timezone initialization (for scheduled notifications)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Ulaanbaatar')); // or use `local`

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings iosInitSettings =
      DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

  final InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      log("🔔 Notification tapped: ${response.payload}");
      // Handle navigation or logic here
    },
  );

  // 🆕 Request notification permission for Android 13+
  await _requestNotificationPermission();
}

Future<void> _requestNotificationPermission() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hasAskedPermission =
        prefs.getBool('notification_permission_asked') ?? false;

    if (!hasAskedPermission) {
      PermissionStatus status = await Permission.notification.status;

      if (status.isDenied) {
        log('📱 Requesting notification permission...');
        PermissionStatus newStatus = await Permission.notification.request();
        await prefs.setBool('notification_permission_asked', true);

        if (newStatus.isGranted) {
          log('✅ Notification permission granted');
        } else if (newStatus.isDenied) {
          log('❌ Notification permission denied');
        } else if (newStatus.isPermanentlyDenied) {
          log('🚫 Notification permission permanently denied');
        }
      } else if (status.isGranted) {
        log('✅ Notification permission already granted');
      }
    }
  } catch (e) {
    log('❌ Error requesting notification permission: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: Routes.authWrapper,
      onGenerateRoute: (settings) => Routes().getRoute(settings),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('mn'),
      ],
    );
  }
}
