import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timex/auth/login/user_type.dart';
import '../../auth/register/register_screen.dart';
import '../home/organization_home_screen.dart';
import '../main/organization_main_screen.dart';

class OrganizationLoginScreen extends StatefulWidget {
  const OrganizationLoginScreen({super.key});

  @override
  State<OrganizationLoginScreen> createState() => _OrganizationLoginScreenState();
}

class _OrganizationLoginScreenState extends State<OrganizationLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showErrorSnackBar('Имэйл хаяг болон нууц үгээ оруулна уу!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw Exception('Байгууллагын бүртгэл олдсонгүй. Эхлээд бүртгүүлнэ үү.');
        }

        await _saveUserToFirestore(user);
        _navigateToHome(user, userDoc.data()!);
      }
    } catch (e) {
      String errorMessage = 'Нэвтрэхэд алдаа гарлаа';

      if (e.toString().contains('user-not-found')) {
        errorMessage = 'Имэйл хаяг олдсонгүй';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Нууц үг буруу байна';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Имэйл хаягийн формат буруу байна';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Хэт олон удаа оролдлоо. Хэсэг хугацааны дараа дахин оролдоно уу';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome(User user, Map<String, dynamic> userData) {
    final loginMethod = user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email';
    final userName = userData['organizationName'] ?? user.email ?? 'Organization';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrganizationMainScreen(
          loginMethod: loginMethod,
          userName: userName,
          organizationData: userData,
          userImage: user.photoURL,
          user: user,
        ),
      ),
    );
  }

  Future<void> _saveUserToFirestore(User user) async {
    final usersRef = FirebaseFirestore.instance.collection('organizations');
    await usersRef.doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'lastLogin': FieldValue.serverTimestamp(),
      'loginMethod': user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email'
    }, SetOptions(merge: true));
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw Exception('Google бүртгэл байгууллагын системд бүртгэлгүй байна. Эхлээд бүртгүүлнэ үү.');
        }

        await _saveUserToFirestore(user);
        _navigateToHome(user, userDoc.data()!);
      }
    } catch (e) {
      _showErrorSnackBar('Google-ээр нэвтрэхэд алдаа гарлаа: ${e.toString()}');
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
                      Icons.business,
                      size: 40,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Байгууллагын нэвтрэх",
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
                  "Байгууллагынхаа бүртгэлээр нэвтэрнэ үү",
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
                    hintText: "organization@email.com",
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
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 32),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                const SizedBox(height: 20),

                // Google login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: Image.network(
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRZLqb_feGWX3FhWcRDcDJDVDLHXjptbGsITg&s',
                      width: 20,
                      height: 20,
                    ),
                    label: const Text(
                      "Google-ээр нэвтрэх",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: borderColor),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Бүртгэл байхгүй юу?",
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(userType: UserType.organization),
                          ),
                        );
                      },
                      child: const Text(
                        "Бүртгүүлэх",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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