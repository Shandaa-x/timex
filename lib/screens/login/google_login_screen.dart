import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main/main_screen.dart';
import '../../services/firebase_test_service.dart';
import '../../utils/debug_helper.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signOut() async {
    try {
      // Get Firebase Auth instance
      final auth = FirebaseAuth.instance;

      // Get Google Sign In instance
      final googleSignIn = GoogleSignIn();

      // Sign out from Firebase
      await auth.signOut();

      // Sign out from Google
      await googleSignIn.signOut();

      print('User signed out successfully');

      if (mounted) {
        setState(() {
          _error = null;
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logout successful  '),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Sign out error: $e');
      if (mounted) {
        setState(() {
          _error = 'Гарах үед алдаа гарлаа: $e';
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    print('🚀 Starting Google Sign-In process...');
    
    // Print debug information for troubleshooting
    DebugHelper.printGoogleSignInDebugInfo();
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Step 1: Initialize Google Sign In with minimal configuration
      print('📱 Initializing Google Sign-In...');
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );
      
      // Step 2: Check if user is already signed in and sign out first to clear cache
      print('🔄 Clearing previous sign-in state...');
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      
      // Step 3: Start sign-in process
      print('🔐 Starting sign-in flow...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ User cancelled sign-in');
        setState(() => _isLoading = false);
        return; // User cancelled
      }
      
      print('✅ Google account selected: ${googleUser.email}');
      print('📧 Display name: ${googleUser.displayName}');
      
      // Step 4: Get authentication details
      print('🔑 Getting authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('🔑 Access token available: ${googleAuth.accessToken != null}');
      print('🔑 ID token available: ${googleAuth.idToken != null}');
      
      // Step 5: Check if tokens are available
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens from Google');
      }
      
      print('✅ Authentication tokens received');
      
      // Step 6: Create Firebase credential
      print('🔥 Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Step 7: Sign in to Firebase
      print('🔥 Signing in to Firebase...');
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      final user = userCredential.user;
      if (user != null) {
        print('✅ Firebase auth successful: ${user.uid}');
        print('📧 User email: ${user.email}');
        
        // Step 8: Save user profile to Firestore
        try {
          print('💾 Saving user data to Firestore...');
          final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

          // Check if user document exists
          final userSnapshot = await userDoc.get();
          print('📄 User document exists: ${userSnapshot.exists}');

          // Create user data
          final userData = {
            'uid': user.uid,
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'createdAt': userSnapshot.exists ? null : FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'provider': 'google',
            'platform': 'android',
          };

          // Remove null values
          userData.removeWhere((key, value) => value == null);

          // Save to Firestore
          await userDoc.set(userData, SetOptions(merge: true));
          print('✅ User saved to Firestore successfully');
          
        } catch (firestoreError) {
          print('⚠️ Firestore save failed: $firestoreError');
          // Continue anyway - user is authenticated
        }

        // Step 9: Navigate to main screen
        print('🎉 Sign-in complete! Navigating to main screen...');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        throw Exception('Firebase authentication succeeded but user is null');
      }
      
    } catch (e, stackTrace) {
      print('❌ Google Sign-In Error: $e');
      print('📍 Stack trace: $stackTrace');
      
      String errorMessage = 'Нэвтрэх явцад алдаа гарлаа. Дахин оролдоно уу.';
      
      // More specific error handling for Android
      if (e.toString().contains('sign_in_failed')) {
        if (e.toString().contains('10:')) {
          errorMessage = 'Аппыг Google Console дээр тохируулаагүй байна. Та өөрийн SHA-1 fingerprint-ийг Firebase Console дээр нэмнэ үү.';
          print('🔧 SOLUTION: Add SHA-1 fingerprint to Firebase Console');
          print('🔧 Current package: com.example.timex');
          print('🔧 Project: timex-9ce03');
        } else {
          errorMessage = 'Google нэвтрэлт тохиргооны алдаа. Дахин оролдоно уу.';
        }
      } else if (e.toString().contains('network_error') || e.toString().contains('network')) {
        errorMessage = 'Интернет холболтоо шалгаад дахин оролдоно уу.';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMessage = 'Нэвтрэх үйлдэл цуцлагдлаа.';
      } else if (e.toString().contains('firebase')) {
        errorMessage = 'Firebase серверт холбогдохоос алдаа гарлаа.';
      } else if (e.toString().contains('tokens')) {
        errorMessage = 'Google нэвтрэх токен авахад алдаа гарлаа.';
      }
      
      if (mounted) {
        setState(() => _error = errorMessage);
      }
      
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/google_logo.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 32),
              const Text(
                'Google-ээр нэвтрэх',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    width: 24,
                    height: 24,
                  ),
                  label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Google-ээр нэвтрэх'),
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Firebase Test button for debugging
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Test Firebase'),
                  onPressed: () async {
                    print('🧪 Running Firebase tests...');
                    final results = await FirebaseTestService.runAllTests();
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Auth: ${results['auth']! ? "✅" : "❌"} | '
                            'Firestore: ${results['firestore']! ? "✅" : "❌"}'
                          ),
                          backgroundColor: results.values.every((v) => v) 
                              ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Logout button for testing
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Гарах'),
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
