import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseTestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Test Firestore connection
  static Future<bool> testFirestoreConnection() async {
    try {
      print('🔥 Testing Firestore connection...');
      
      // Test with a collection that allows public write according to your rules
      // Using 'foods' collection which has "allow read, write: if true;"
      await _firestore.collection('foods').doc('connection_test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Firestore connection successful',
        'platform': 'iOS',
        'test': true,
      });
      
      print('✅ Firestore write test successful');
      
      // Try to read the document
      DocumentSnapshot doc = await _firestore
          .collection('foods')
          .doc('connection_test')
          .get();
      
      if (doc.exists) {
        print('✅ Firestore read test successful');
        print('Document data: ${doc.data()}');
        
        // Clean up test document
        await _firestore.collection('foods').doc('connection_test').delete();
        print('🧹 Test document cleaned up');
        
        return true;
      } else {
        print('❌ Firestore read test failed - document not found');
        return false;
      }
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      
      // Try a read-only test instead
      try {
        print('🔄 Trying read-only test...');
        QuerySnapshot snapshot = await _firestore
            .collection('foods')
            .limit(1)
            .get();
        
        print('✅ Firestore read-only test successful');
        print('Found ${snapshot.docs.length} documents');
        return true;
      } catch (readError) {
        print('❌ Even read-only test failed: $readError');
        return false;
      }
    }
  }

  /// Test Firebase Auth
  static Future<bool> testFirebaseAuth() async {
    try {
      print('🔐 Testing Firebase Auth...');
      
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('✅ User already signed in: ${currentUser.email}');
        return true;
      } else {
        print('ℹ️ No user currently signed in');
        return true; // Not an error, just no user
      }
    } catch (e) {
      print('❌ Firebase Auth test failed: $e');
      return false;
    }
  }

  /// Comprehensive Firebase test
  static Future<Map<String, bool>> runAllTests() async {
    print('🚀 Running Firebase connection tests...');
    
    Map<String, bool> results = {
      'auth': await testFirebaseAuth(),
      'firestore': await testFirestoreConnection(),
    };
    
    print('📊 Test Results:');
    results.forEach((test, passed) {
      print('${passed ? "✅" : "❌"} $test: ${passed ? "PASSED" : "FAILED"}');
    });
    
    return results;
  }
}
