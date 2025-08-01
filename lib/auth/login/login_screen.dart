// lib/auth/login/login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timex/auth/login/user_type.dart';
import 'package:timex/index.dart';
import '../../organization/home/organization_home_screen.dart';
import '../register/register_screen.dart';
import 'package:timex/employee/index.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserType _selectedUserType = UserType.employee;

  Future<void> _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection(_selectedUserType == UserType.organization ? 'organizations' : 'employees').doc(user.uid).get();

        if (!userDoc.exists) {
          throw Exception('User not found as ${_selectedUserType.name}. Please check your account type.');
        }

        await _saveUserToFirestore(user);
        _navigateToHome(user, userDoc.data()!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  void _navigateToHome(User user, Map<String, dynamic> userData) {
    if (_selectedUserType == UserType.organization) {
      // get loginMethod from user.providerData (if any)
      final loginMethod = user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email';

      // get userName from organizationData or fallback to email
      final userName = userData['organizationName'] ?? user.email ?? 'Organization';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrganizationMainScreen(loginMethod: loginMethod, userName: userName, organizationData: userData, userImage: user.photoURL, user: user),
        ),
      );
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(userName: '')));
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    final collection = _selectedUserType == UserType.organization ? 'organizations' : 'employees';
    final usersRef = FirebaseFirestore.instance.collection(collection);

    await usersRef.doc(user.uid).set({'uid': user.uid, 'email': user.email, 'lastLogin': FieldValue.serverTimestamp(), 'loginMethod': user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email'}, SetOptions(merge: true));
  }

  void _loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection(_selectedUserType == UserType.organization ? 'organizations' : 'employees').doc(user.uid).get();

        if (!userDoc.exists) {
          throw Exception('Google account not registered as ${_selectedUserType.name}. Please register first.');
        }

        await _saveUserToFirestore(user);
        _navigateToHome(user, userDoc.data()!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Google login failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightGray = const Color(0xFFF7F7F7);
    final borderColor = Colors.grey.shade300;

    return Scaffold(
      backgroundColor: lightGray,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome back 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Please log in to continue", style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 32),

              const Text("Login as:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Login as ${_selectedUserType.name.toUpperCase()}"),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loginWithGoogle,
                  icon: Image.network('https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRZLqb_feGWX3FhWcRDcDJDVDLHXjptbGsITg&s', width: 20),
                  label: Text("Login with Google as ${_selectedUserType.name}"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: borderColor),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(userType: _selectedUserType)));
                    },
                    child: const Text("Register here"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
