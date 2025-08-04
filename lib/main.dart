import 'dart:async';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:timex/index.dart';

import 'firebase_options.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized(); // <-- Moved inside the zone
    Assets.refresh();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      log('✅ Firebase initialized successfully');
    } catch (e, stackTrace) {
      log('❌ Firebase initialization failed: $e');
      log('Stack trace: $stackTrace');
    }

    runApp(const MyApp()); // Same zone as initialization
  }, (error, stackTrace) {
    log('runZonedGuarded: error: $error, stackTrace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: Routes.main,
      onGenerateRoute: (settings) => Routes().getRoute(settings),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}
