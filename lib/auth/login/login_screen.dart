// lib/auth/login/login_screen.dart
import 'package:flutter/material.dart';
import 'login_selection_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to the new login selection screen
    return const LoginSelectionScreen();
  }
}
