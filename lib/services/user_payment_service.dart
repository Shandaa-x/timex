import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Service for handling user payment status and food amount updates in Firestore
class UserPaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Process payment and update user's balance with partial payment support
  static Future<Map<String, dynamic>> processPayment({
    required String userId,
    required double paidAmount,
    required String paymentMethod,
    required String invoiceId,
    String? orderId,
  }) async {
    try {
      AppLogger.info('Processing payment for user: $userId, amount: ₮$paidAmount');
      
      final userDocRef = _firestore.collection('users').doc(userId);
      final paymentsRef = userDocRef.collection('payments');
      
      return await _firestore.runTransaction((transaction) async {
        // Get current user document
        final userDoc = await transaction.get(userDocRef);
        
        if (!userDoc.exists) {
          throw Exception('User document not found');
        }
        
        final userData = userDoc.data()!;
        final dynamic rawTotalFoodAmount = userData['totalFoodAmount'] ?? 0.0;
        final double currentTotalFoodAmount = rawTotalFoodAmount is String 
            ? double.tryParse(rawTotalFoodAmount) ?? 0.0 
            : (rawTotalFoodAmount as num).toDouble();
        
        // Calculate new balance after payment
        final double newTotalFoodAmount = (currentTotalFoodAmount - paidAmount).clamp(0.0, double.infinity);
        
        // Determine payment status based on remaining balance
        String paymentStatus;
        if (newTotalFoodAmount == 0.0) {
          paymentStatus = 'paid';  // Fully paid
        } else if (newTotalFoodAmount < currentTotalFoodAmount) {
          paymentStatus = 'partial';  // Partial payment made
        } else {
          paymentStatus = 'pending';  // No effective payment (edge case)
        }
        
        // Create payment record
        final paymentDocRef = paymentsRef.doc();
        final paymentRecord = {
          'amount': paidAmount,
          'status': 'completed',
          'date': FieldValue.serverTimestamp(),
          'method': paymentMethod,
          'invoiceId': invoiceId,
          'orderId': orderId,
          'previousBalance': currentTotalFoodAmount,
          'newBalance': newTotalFoodAmount,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        transaction.set(paymentDocRef, paymentRecord);
        
        // Update user document
        Map<String, dynamic> updateData = {
          'totalFoodAmount': newTotalFoodAmount,
          'qpayStatus': paymentStatus,
          'lastPaymentAmount': paidAmount,
          'lastPaymentDate': FieldValue.serverTimestamp(),
          'lastPaymentStatusUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        transaction.update(userDocRef, updateData);
        
        AppLogger.success(
          'Payment processed: ₮$paidAmount deducted. '
          'Previous: ₮$currentTotalFoodAmount, New: ₮$newTotalFoodAmount, Status: $paymentStatus'
        );
        
        return {
          'success': true,
          'previousAmount': currentTotalFoodAmount,
          'newAmount': newTotalFoodAmount,
          'paidAmount': paidAmount,
          'status': paymentStatus,
          'paymentId': paymentDocRef.id,
        };
      });
      
    } catch (error) {
      AppLogger.error('Error processing payment: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }
  
  /// Update payment status (for pending payments)
  static Future<Map<String, dynamic>> updatePaymentStatus({
    required String userId,
    required String status, // 'pending'
  }) async {
    try {
      AppLogger.info('Updating payment status for user: $userId to $status');
      
      final userDocRef = _firestore.collection('users').doc(userId);
      
      await userDocRef.update({
        'qpayStatus': status,
        'lastPaymentStatusUpdate': FieldValue.serverTimestamp(),
      });
      
      return {
        'success': true,
        'status': status,
      };
      
    } catch (error) {
      AppLogger.error('Error updating payment status: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }
  
  /// Get current user's payment status and food amount
  static Future<Map<String, dynamic>> getUserPaymentInfo([String? userId]) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }
      
      final data = userDoc.data()!;
      
      // Safe parsing for potentially string values from Firebase
      final dynamic rawTotalFoodAmount = data['totalFoodAmount'] ?? 0.0;
      final dynamic rawLastPaymentAmount = data['lastPaymentAmount'] ?? 0.0;
      
      return {
        'success': true,
        'totalFoodAmount': rawTotalFoodAmount is String 
            ? double.tryParse(rawTotalFoodAmount) ?? 0.0 
            : (rawTotalFoodAmount as num).toDouble(),
        'qpayStatus': data['qpayStatus'] ?? 'none',
        'lastPaymentAmount': rawLastPaymentAmount is String 
            ? double.tryParse(rawLastPaymentAmount) ?? 0.0 
            : (rawLastPaymentAmount as num).toDouble(),
        'lastPaymentDate': data['lastPaymentDate'],
        'lastPaymentStatusUpdate': data['lastPaymentStatusUpdate'],
      };
      
    } catch (error) {
      AppLogger.error('Error getting user payment info: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }
  
  /// Get payment history for a user
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final paymentsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .orderBy('date', descending: true)
          .limit(20)
          .get();
      
      return paymentsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'status': data['status'] ?? 'unknown',
          'date': data['date'],
          'method': data['method'] ?? 'unknown',
          'invoiceId': data['invoiceId'],
          'orderId': data['orderId'],
          'previousBalance': data['previousBalance'] ?? 0.0,
          'newBalance': data['newBalance'] ?? 0.0,
        };
      }).toList();
      
    } catch (error) {
      AppLogger.error('Error getting payment history: $error');
      return [];
    }
  }
  
  /// Initialize or ensure user document exists with default values
  static Future<void> ensureUserDocument([String? userId]) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }
      
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        await userDocRef.set({
          'totalFoodAmount': 0.0,
          'qpayStatus': 'none',
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        AppLogger.info('User document created with default values');
      }
      
    } catch (error) {
      AppLogger.error('Error ensuring user document: $error');
    }
  }
}