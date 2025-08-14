import 'dart:io';
import 'package:flutter/foundation.dart';

class DebugHelper {
  static void printGoogleSignInDebugInfo() {
    if (kDebugMode) {
      print('🔧 Google Sign-In Debug Information:');
      print('📱 Platform: ${Platform.operatingSystem}');
      print('🔧 Is Android: ${Platform.isAndroid}');
      print('🔧 Is iOS: ${Platform.isIOS}');
      
      if (Platform.isAndroid) {
        print('⚠️ Android Google Sign-In Issues:');
        print('   1. Check SHA-1 fingerprint in Firebase Console');
        print('   2. Ensure google-services.json is in android/app/');
        print('   3. Check package name matches: com.example.timex');
        print('   4. Clear app data and try again');
        print('');
        print('💡 To get SHA-1 fingerprint, run:');
        print('   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android');
        print('');
        print('🔧 Current google-services.json should have:');
        print('   - Package name: com.example.timex');
        print('   - Android client with correct SHA-1');
      }
    }
  }
}
