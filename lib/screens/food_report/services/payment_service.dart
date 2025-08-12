import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  static const String _currentUserId = 'pNR2EFnrnjqn5KY9RQXQ'; // Updated with actual user ID
  static const int _pageSize = 10; // Number of documents per page

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

  // Get real-time paginated payment history stream
  static Stream<QuerySnapshot> getPaymentHistoryStream({
    DocumentSnapshot? lastDocument,
    int limit = _pageSize,
  }) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('historyOfPayment')
        .orderBy('timestamp', descending: true) // Most recent first
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots();
  }

  // Get initial payment history page
  static Future<QuerySnapshot> getInitialPaymentHistory({int limit = _pageSize}) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('historyOfPayment')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      print('Error getting initial payment history: $e');
      rethrow;
    }
  }

  // Get next page of payment history
  static Future<QuerySnapshot> getNextPaymentHistoryPage(
    DocumentSnapshot lastDocument, {
    int limit = _pageSize,
  }) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('historyOfPayment')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(lastDocument)
          .limit(limit)
          .get();
    } catch (e) {
      print('Error getting next payment history page: $e');
      rethrow;
    }
  }

  // Convert Firestore document to payment data
  static Map<String, dynamic> convertDocumentToPayment(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return {};

    return {
      'id': doc.id,
      'amount': data['amount'] ?? 0,
      'type': data['type'] ?? 'payment',
      'description': data['description'] ?? '',
      'timestamp': data['timestamp'],
      'date': data['date'] ?? data['timestamp']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'transactionId': data['transactionId'] ?? doc.id,
      'status': data['status'] ?? 'completed',
      'paymentMethod': data['paymentMethod'] ?? 'unknown',
      // Add any other fields that might exist in the document
      ...data,
    };
  }

  // Utility method to add sample payment data for testing
  static Future<void> addSamplePaymentData() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('historyOfPayment');

      // Sample payment data
      final samplePayments = [
        {
          'amount': 15000,
          'type': 'payment',
          'description': 'Сарын хоолны төлбөр',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
          'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch - 86400000}',
          'status': 'completed',
          'paymentMethod': 'card',
        },
        {
          'amount': 50000,
          'type': 'topup',
          'description': 'Данс цэнэглэх',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
          'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch - 172800000}',
          'status': 'completed',
          'paymentMethod': 'bank_transfer',
        },
        {
          'amount': 8500,
          'type': 'payment',
          'description': 'Өдрийн хоолны төлбөр',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
          'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch - 259200000}',
          'status': 'completed',
          'paymentMethod': 'qr_code',
        },
        {
          'amount': 12000,
          'type': 'refund',
          'description': 'Буцаан олголт',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))),
          'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch - 432000000}',
          'status': 'completed',
          'paymentMethod': 'card',
        },
        {
          'amount': 25000,
          'type': 'payment',
          'description': 'Долоо хоногийн хоолны төлбөр',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))),
          'date': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
          'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch - 604800000}',
          'status': 'pending',
          'paymentMethod': 'card',
        },
      ];

      for (final payment in samplePayments) {
        final docRef = collectionRef.doc();
        batch.set(docRef, payment);
      }

      await batch.commit();
      print('Sample payment data added successfully');
    } catch (e) {
      print('Error adding sample payment data: $e');
      rethrow;
    }
  }
}
