import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/screens/main/login/google_login_screen.dart';
import '../main_screen.dart';
import 'package:timex/index.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, show main screen
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }

        // If user is not logged in, show login screen
        return const GoogleLoginScreen();
      },
    );
  }
}
