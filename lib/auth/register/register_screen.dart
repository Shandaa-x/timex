import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../login/user_type.dart';

class RegisterScreen extends StatefulWidget {
  final UserType userType;

  const RegisterScreen({super.key, required this.userType});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _organizationCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  late UserType _selectedUserType;

  @override
  void initState() {
    super.initState();
    _selectedUserType = widget.userType ?? UserType.employee;
  }

  Future<void> _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords don't match")),
      );
      return;
    }

    if (_selectedUserType == UserType.employee && _organizationCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization code is required for employees")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        if (_selectedUserType == UserType.organization) {
          await _registerOrganization(user);
        } else {
          await _registerEmployee(user);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${_selectedUserType.name} registered successfully!")),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      print('wefwefwefwefwefwef $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerOrganization(User user) async {
    final organizationCode = _generateOrganizationCode();

    await FirebaseFirestore.instance.collection('organizations').doc(user.uid).set({
      'uid': user.uid,
      'organizationName': _nameController.text.trim(),
      'email': user.email,
      'organizationCode': organizationCode,
      'createdAt': FieldValue.serverTimestamp(),
      'totalEmployees': 0,
      'isActive': true,
    });
  }

  Future<void> _registerEmployee(User user) async {
    final organizationCode = _organizationCodeController.text.trim();

    // Find organization by code
    final orgQuery = await FirebaseFirestore.instance
        .collection('organizations')
        .where('organizationCode', isEqualTo: organizationCode)
        .limit(1)
        .get();

    if (orgQuery.docs.isEmpty) {
      throw Exception('Invalid organization code');
    }

    final organizationId = orgQuery.docs.first.id;
    final organizationName = orgQuery.docs.first.data()['organizationName'];

    await FirebaseFirestore.instance.collection('employees').doc(user.uid).set({
      'uid': user.uid,
      'name': _nameController.text.trim(),
      'email': user.email,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'organizationCode': organizationCode,
      'joinedAt': FieldValue.serverTimestamp(),
      'totalWorkedHours': 0.0,
      'totalSalary': 0.0,
      'hourlyRate': 0.0,
      'isActive': true,
      'currentlyWorking': false,
    });

    // Update organization's total employees count
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(organizationId)
        .update({
      'totalEmployees': FieldValue.increment(1),
    });
  }

  String _generateOrganizationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Create ${_selectedUserType.name} Account"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

            // User Type Selection (only show if not passed from login)
            if (widget.userType == null) ...[
              const Text("Register as:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<UserType>(
                      title: const Text("Organization"),
                      value: UserType.organization,
                      groupValue: _selectedUserType,
                      onChanged: (UserType? value) {
                        setState(() {
                          _selectedUserType = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<UserType>(
                      title: const Text("Employee"),
                      value: UserType.employee,
                      groupValue: _selectedUserType,
                      onChanged: (UserType? value) {
                        setState(() {
                          _selectedUserType = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Name/Organization Name Field
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: _selectedUserType == UserType.organization
                      ? "Organization Name"
                      : "Full Name",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Organization Code (for employees only)
            if (_selectedUserType == UserType.employee) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _organizationCodeController,
                  decoration: const InputDecoration(
                    hintText: "Organization Code",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  "Enter the code provided by your organization",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Password
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Confirm Password',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Register button
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3556AB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                "Register as ${_selectedUserType.name}",
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            // Back to login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Login here"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}