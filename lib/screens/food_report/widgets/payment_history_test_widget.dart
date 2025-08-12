import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Test widget to demonstrate the payment history structure
class PaymentHistoryTestWidget extends StatelessWidget {
  const PaymentHistoryTestWidget({super.key});

  Future<void> _addSamplePayment() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('pNR2EFnrnjqn5KY9RQXQ')
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
