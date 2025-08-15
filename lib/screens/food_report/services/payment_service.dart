import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
  static const int _pageSize = 10; // Number of documents per page

  // Load payment history from Firestore
  static Future<List<Map<String, dynamic>>> loadPaymentHistory(
    DateTime selectedMonth,
  ) async {
    try {
      final monthKey =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

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
  static Future<Map<String, bool>> loadMealPaymentStatus(
    DateTime selectedMonth,
  ) async {
    try {
      final monthKey =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

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
      final monthKey =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

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
      final monthKey =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
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
    print(
      '🔴 Setting up real-time payment stream for: users/$_currentUserId/payments',
    );

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('payments')
        .orderBy('createdAt', descending: true) // Most recent first
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots();
  }

  // Get initial payment history page
  static Future<QuerySnapshot> getInitialPaymentHistory({
    int limit = _pageSize,
  }) async {
    try {
      print('🔍 Loading payment history from: users/$_currentUserId/payments');
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      print('📊 Found ${result.docs.length} payment documents');
      for (var doc in result.docs) {
        print('📄 Payment doc: ${doc.id} - ${doc.data()}');
      }

      return result;
    } catch (e) {
      print('❌ Error getting initial payment history: $e');
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
          .collection('payments')
          .orderBy('createdAt', descending: true)
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

    // Handle the specific structure you described
    final amount = data['amount'] ?? data['requestedAmount'] ?? 0;
    final createdAt = data['createdAt'] ?? data['date'];
    final status = data['status'] ?? 'completed';
    final method = data['method'] ?? 'unknown';
    final invoiceId = data['invoiceId'] ?? '';

    // Determine the type based on available data
    String type = 'payment';
    if (data['remainingBalance'] != null &&
        (data['remainingBalance'] as num) > 0) {
      type = 'topup'; // Account balance increase
    } else if (status == 'refund') {
      type = 'refund';
    }

    // Convert timestamp to proper format
    DateTime dateTime;
    if (createdAt is Timestamp) {
      dateTime = createdAt.toDate();
    } else if (createdAt is String) {
      dateTime = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      dateTime = DateTime.now();
    }

    return {
      'id': doc.id,
      'amount': amount,
      'type': type,
      'description': _generateDescription(data),
      'timestamp': Timestamp.fromDate(dateTime),
      'date': dateTime.toIso8601String(),
      'transactionId': invoiceId.isNotEmpty ? invoiceId : doc.id,
      'status': status,
      'paymentMethod': method,
      'originalData': data, // Keep original data for debugging
    };
  }

  // Generate description based on payment data
  static String _generateDescription(Map<String, dynamic> data) {
    final method = data['method'] ?? 'unknown';
    final foodCount = data['foodCount'] ?? 0;
    final totalPaymentsMade = data['totalPaymentsMade'] ?? 0;
    final originalFoodAmount = data['originalFoodAmount'] ?? 0;

    if (foodCount > 0) {
      return 'Food Payment ($foodCount items)';
    } else if (totalPaymentsMade > originalFoodAmount) {
      return 'Account Top-up';
    } else {
      return 'Payment ($method)';
    }
  }
}
