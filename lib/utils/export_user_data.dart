import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Add this function to your app to export user data
Future<void> exportUserData(BuildContext context, String userId) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Exporting user data...'),
          ],
        ),
      ),
    );

    final Map<String, dynamic> userData = {};

    print('🔍 Starting to download data for user: $userId');

    // Get user document from users collection
    print('📄 Fetching user document...');
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (userDoc.exists) {
      userData['users'] = {
        'id': userDoc.id,
        'data': _convertTimestamps(userDoc.data()!),
      };
      print('✅ User document fetched');
    } else {
      print('❌ User document not found');
    }

    // Get all payments subcollection
    print('💰 Fetching payments subcollection...');
    final paymentsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('payments')
        .get();

    userData['payments'] = paymentsQuery.docs.map((doc) => {
      'id': doc.id,
      'data': _convertTimestamps(doc.data()),
    }).toList();
    print('✅ Found ${paymentsQuery.docs.length} payment documents');

    // Get food records subcollection
    print('🍽️ Fetching food records subcollection...');
    final foodQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('foodRecords')
        .get();

    userData['foodRecords'] = foodQuery.docs.map((doc) => {
      'id': doc.id,
      'data': _convertTimestamps(doc.data()),
    }).toList();
    print('✅ Found ${foodQuery.docs.length} food record documents');

    // Get userPaymentInfo subcollection
    print('💳 Fetching user payment info...');
    final paymentInfoQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('userPaymentInfo')
        .get();

    userData['userPaymentInfo'] = paymentInfoQuery.docs.map((doc) => {
      'id': doc.id,
      'data': _convertTimestamps(doc.data()),
    }).toList();
    print('✅ Found ${paymentInfoQuery.docs.length} user payment info documents');

    // Check legacy collections that might have user data
    print('🔍 Checking legacy collections...');
    
    // Check payments collection (legacy format)
    try {
      final legacyPaymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();

      if (legacyPaymentsQuery.docs.isNotEmpty) {
        userData['legacyPayments'] = legacyPaymentsQuery.docs.map((doc) => {
          'id': doc.id,
          'data': _convertTimestamps(doc.data()),
        }).toList();
        print('✅ Found ${legacyPaymentsQuery.docs.length} legacy payment documents');
      }
    } catch (e) {
      print('⚠️ Error checking legacy payments: $e');
    }

    // Check mealPayments collection
    try {
      final mealPaymentsQuery = await FirebaseFirestore.instance
          .collection('mealPayments')
          .where('userId', isEqualTo: userId)
          .get();

      if (mealPaymentsQuery.docs.isNotEmpty) {
        userData['mealPayments'] = mealPaymentsQuery.docs.map((doc) => {
          'id': doc.id,
          'data': _convertTimestamps(doc.data()),
        }).toList();
        print('✅ Found ${mealPaymentsQuery.docs.length} meal payment documents');
      }
    } catch (e) {
      print('⚠️ Error checking meal payments: $e');
    }

    // Add metadata
    userData['metadata'] = {
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': userId,
      'totalCollections': userData.keys.length - 1, // Exclude metadata
    };

    // Convert to JSON and save
    final jsonString = JsonEncoder.withIndent('  ').convert(userData);
    
    // For mobile, we'll save to app documents directory
    // You can also copy this to share or save elsewhere
    print('📄 User data JSON:');
    print(jsonString);

    Navigator.of(context).pop(); // Close loading dialog

    // Show success dialog with option to copy data
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User data exported successfully!'),
            const SizedBox(height: 10),
            Text('Export summary:'),
            ...userData.entries.where((e) => e.key != 'metadata').map((entry) {
              if (entry.value is List) {
                return Text('  - ${entry.key}: ${(entry.value as List).length} documents');
              } else if (entry.value is Map && entry.key == 'users') {
                return Text('  - ${entry.key}: 1 document');
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 10),
            const Text('Check the console/debug output for the full JSON data.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

  } catch (e) {
    Navigator.of(context).pop(); // Close loading dialog
    print('❌ Error during export: $e');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Error'),
        content: Text('Error during export: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Helper function to convert Timestamps to ISO strings for JSON serialization
Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
  final Map<String, dynamic> converted = {};
  
  data.forEach((key, value) {
    if (value is Timestamp) {
      converted[key] = {
        '_timestamp': true,
        'seconds': value.seconds,
        'nanoseconds': value.nanoseconds,
        'iso8601': value.toDate().toIso8601String(),
      };
    } else if (value is List) {
      converted[key] = value.map((item) {
        if (item is Map<String, dynamic>) {
          return _convertTimestamps(item);
        } else if (item is Timestamp) {
          return {
            '_timestamp': true,
            'seconds': item.seconds,
            'nanoseconds': item.nanoseconds,
            'iso8601': item.toDate().toIso8601String(),
          };
        }
        return item;
      }).toList();
    } else if (value is Map<String, dynamic>) {
      converted[key] = _convertTimestamps(value);
    } else {
      converted[key] = value;
    }
  });
  
  return converted;
}
