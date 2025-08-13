import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Test widget to demonstrate the payment history structure
class PaymentHistoryTestWidget extends StatelessWidget {
  const PaymentHistoryTestWidget({super.key});

  Future<void> _addSamplePayment() async {
    try {
      // Use the current user's ID from FirebaseAuth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('historyOfPayment')
          .add({
        'amount': 15000,
        'type': 'payment',
        'description': 'Сарын хоолны төлбөр',
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'paymentMethod': 'card',
      });
      print('Sample payment added successfully');
    } catch (e) {
      print('Error adding sample payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test payment history collection',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addSamplePayment,
              child: const Text('Add Sample Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
