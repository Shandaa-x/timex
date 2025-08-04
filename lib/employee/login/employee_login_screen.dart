import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../routes/routes.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _loginEmployee() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showErrorSnackBar('Имэйл хаяг болон нууц үгээ оруулна уу!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Starting employee login for: ${_emailController.text.trim()}');

      // First, search for employee in Firestore to get employee data
      final querySnapshot = await _firestore
          .collectionGroup('employees')
          .where('employeeEmail', isEqualTo: _emailController.text.trim())
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showErrorSnackBar('Имэйл хаяг буруу байна!');
        return;
      }

      // Get the employee document
      final employeeDoc = querySnapshot.docs.first;
      final employeeData = employeeDoc.data();

      // Hash the entered password and compare
      final hashedPassword = sha256.convert(utf8.encode(_passwordController.text)).toString();

      if (employeeData['hashedPassword'] != hashedPassword) {
        _showErrorSnackBar('Нууц үг буруу байна!');
        return;
      }

      // Now sign in with Firebase Auth using the same credentials
      try {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        debugPrint('Firebase Auth login successful');
      } catch (authError) {
        debugPrint('Firebase Auth error: $authError');
        // If Firebase Auth fails, try to create the user account
        try {
          await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          debugPrint('Firebase Auth account created and logged in');
        } catch (createError) {
          debugPrint('Failed to create Firebase Auth account: $createError');
          _showErrorSnackBar('Системд нэвтрэхэд алдаа гарлаа. Дахин оролдоно уу.');
          return;
        }
      }

      // Login successful - navigate to employee main screen
      _showSuccessSnackBar('Амжилттай нэвтэрлээ!');

      // Extract organization ID from the document reference path
      final organizationId = employeeDoc.reference.parent.parent!.id;

      // Navigate to employee main screen
      Navigator.pushReplacementNamed(
        context,
        Routes.main,
        arguments: {
          'employeeId': employeeDoc.id,
          'organizationId': organizationId,
          'employeeData': employeeData,
          'isFirstLogin': employeeData['isFirstLogin'] ?? false,
        },
      );

    } catch (e) {
      debugPrint('Employee login error: $e');
      _showErrorSnackBar('Нэвтрэхэд алдаа гарлаа: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Rest of your build method stays the same...
  @override
  Widget build(BuildContext context) {
    final lightGray = const Color(0xFFF7F7F7);
    final borderColor = Colors.grey.shade300;

    return Scaffold(
      backgroundColor: lightGray,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Icon(
                      Icons.work,
                      size: 40,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Ажилтны нэвтрэх",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Өөрийн имэйл болон нууц үгээр нэвтэрнэ үү",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // Email field
                const Text(
                  "Имэйл хаяг",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: "example@email.com",
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password field
                const Text(
                  "Нууц үг",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: "Нууц үгээ оруулна уу",
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _loginEmployee(),
                ),
                const SizedBox(height: 32),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginEmployee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      "Нэвтрэх",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Forgot password link
                Center(
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Нууц үг сэргээх функц удахгүй нэмэгдэнэ'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    child: const Text(
                      "Нууц үгээ мартсан уу?",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Help text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Хэрэв та шинэ ажилтан бол байгууллагынхаа админ танд имэйл илгээсэн байх ёстой.",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}