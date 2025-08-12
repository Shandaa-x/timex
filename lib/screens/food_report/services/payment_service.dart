import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  static const String _currentUserId = 'current_user'; // Replace with actual user ID

  // Load payment history from Firestore
  static Future<List<Map<String, dynamic>>> loadPaymentHistory(DateTime selectedMonth) async {
    try {
      final monthKey = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

      final docSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .doc('$_currentUserId-$monthKey')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return List<Map<String, dynamic>>.from(data['payments'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print('Error loading payment history: $e');
      return [];
    }
  }

  // Load meal payment status from Firestore
  static Future<Map<String, bool>> loadMealPaymentStatus(DateTime selectedMonth) async {
    try {
      final monthKey = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

      final docSnapshot = await FirebaseFirestore.instance
          .collection('mealPayments')
          .doc('$_currentUserId-$monthKey')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return Map<String, bool>.from(data['paidMeals'] ?? {});
      } else {
        return {};
      }
    } catch (e) {
      print('Error loading meal payment status: $e');
      return {};
    }
  }

  // Save meal payment status to Firestore
  static Future<bool> saveMealPaymentStatus(
    DateTime selectedMonth,
    String mealKey,
    bool isPaid,
  ) async {
    try {
      final monthKey = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

      final docRef = FirebaseFirestore.instance
          .collection('mealPayments')
          .doc('$_currentUserId-$monthKey');

      await docRef.set({
        'userId': _currentUserId,
        'year': selectedMonth.year,
        'month': selectedMonth.month,
        'paidMeals.$mealKey': isPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error saving meal payment status: $e');
      return false;
    }
  }

  // Save payment to Firestore
  static Future<Map<String, dynamic>?> savePaymentToHistory(
    DateTime selectedMonth,
    String type,
    int amount,
  ) async {
    try {
      final monthKey = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
      final paymentData = {
        'type': type,
        'amount': amount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'date': DateTime.now().toIso8601String(),
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      };

      final docRef = FirebaseFirestore.instance
          .collection('payments')
          .doc('$_currentUserId-$monthKey');

      await docRef.set({
        'userId': _currentUserId,
        'year': selectedMonth.year,
        'month': selectedMonth.month,
        'payments': FieldValue.arrayUnion([paymentData]),
      }, SetOptions(merge: true));

      return paymentData;
    } catch (e) {
      print('Error saving payment: $e');
      return null;
    }
  }
}
