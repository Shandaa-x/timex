import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';
import 'modern_user_account_service.dart';

/// Modern transaction service for the improved Firebase structure
/// Manages transactions in the 'transactions' collection
class TransactionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a deposit transaction (payment received)
  static Future<Map<String, dynamic>> createDeposit({
    required String userId,
    required double amount,
    required String paymentMethod,
    required String invoiceId,
    String? orderId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('Creating deposit transaction for: $userId, amount: ₮$amount');

      // Check if user account exists
      final accountInfo = await ModernUserAccountService.getUserAccount(userId);
      if (!accountInfo['success']) {
        throw Exception('User account not found or could not be created');
      }

      final transactionRef = _firestore.collection('transactions').doc();
      
      final transactionData = {
        'userId': userId,
        'type': 'deposit',
        'amount': amount,
        'description': 'QPay Payment Deposit',
        'status': 'completed',
        'paymentMethod': paymentMethod,
        'invoiceId': invoiceId,
        'orderId': orderId,
        'metadata': {
          'originalAmount': amount,
          'overpaymentPrevented': false,
          'processingFee': 0.0,
          ...?metadata,
        },
        'timestamps': {
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        },
      };

      // Create transaction and update balance atomically
      await _firestore.runTransaction((transaction) async {
        // Create the transaction record
        transaction.set(transactionRef, transactionData);

        // Update user account balance
        final accountDocRef = _firestore.collection('user_accounts').doc(userId);
        final accountDoc = await transaction.get(accountDocRef);
        
        if (accountDoc.exists) {
          final data = accountDoc.data()!;
          final currentBalance = (data['balance']['current'] as num?)?.toDouble() ?? 0.0;
          final totalDeposited = (data['balance']['totalDeposited'] as num?)?.toDouble() ?? 0.0;

          transaction.update(accountDocRef, {
            'balance.current': currentBalance + amount,
            'balance.totalDeposited': totalDeposited + amount,
            'balance.lastUpdated': FieldValue.serverTimestamp(),
            'balance.lastTransactionId': transactionRef.id,
            'timestamps.updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      AppLogger.success('Deposit transaction created successfully: ${transactionRef.id}');
      
      return {
        'success': true,
        'transactionId': transactionRef.id,
        'amount': amount,
        'type': 'deposit',
        'status': 'completed',
      };
    } catch (error) {
      AppLogger.error('Error creating deposit transaction: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Create a purchase transaction (spending money on meals)
  static Future<Map<String, dynamic>> createPurchase({
    required String userId,
    required double amount,
    required String description,
    String? mealId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('Creating purchase transaction for: $userId, amount: ₮$amount');

      // Check if user has sufficient balance
      final hasFunds = await ModernUserAccountService.hasSufficientBalance(amount, userId);
      if (!hasFunds) {
        return {
          'success': false,
          'error': 'Insufficient balance for purchase',
          'code': 'INSUFFICIENT_FUNDS',
        };
      }

      final transactionRef = _firestore.collection('transactions').doc();
      
      final transactionData = {
        'userId': userId,
        'type': 'purchase',
        'amount': amount,
        'description': description,
        'status': 'completed',
        'paymentMethod': 'balance',
        'mealId': mealId,
        'metadata': {
          'purchaseType': 'meal',
          'autoProcessed': true,
          ...?metadata,
        },
        'timestamps': {
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        },
      };

      // Create transaction and update balance atomically
      await _firestore.runTransaction((transaction) async {
        // Create the transaction record
        transaction.set(transactionRef, transactionData);

        // Update user account balance
        final accountDocRef = _firestore.collection('user_accounts').doc(userId);
        final accountDoc = await transaction.get(accountDocRef);
        
        if (accountDoc.exists) {
          final data = accountDoc.data()!;
          final currentBalance = (data['balance']['current'] as num?)?.toDouble() ?? 0.0;
          final totalSpent = (data['balance']['totalSpent'] as num?)?.toDouble() ?? 0.0;

          transaction.update(accountDocRef, {
            'balance.current': (currentBalance - amount).clamp(0.0, double.infinity),
            'balance.totalSpent': totalSpent + amount,
            'balance.lastUpdated': FieldValue.serverTimestamp(),
            'balance.lastTransactionId': transactionRef.id,
            'timestamps.updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      AppLogger.success('Purchase transaction created successfully: ${transactionRef.id}');
      
      return {
        'success': true,
        'transactionId': transactionRef.id,
        'amount': amount,
        'type': 'purchase',
        'status': 'completed',
      };
    } catch (error) {
      AppLogger.error('Error creating purchase transaction: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Create a refund transaction
  static Future<Map<String, dynamic>> createRefund({
    required String userId,
    required double amount,
    required String originalTransactionId,
    String reason = 'Customer requested refund',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('Creating refund transaction for: $userId, amount: ₮$amount');

      final transactionRef = _firestore.collection('transactions').doc();
      
      final transactionData = {
        'userId': userId,
        'type': 'refund',
        'amount': amount,
        'description': 'Refund: $reason',
        'status': 'completed',
        'paymentMethod': 'balance',
        'originalTransactionId': originalTransactionId,
        'metadata': {
          'refundReason': reason,
          'refundType': 'full',
          ...?metadata,
        },
        'timestamps': {
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        },
      };

      // Create transaction and update balance atomically
      await _firestore.runTransaction((transaction) async {
        // Create the transaction record
        transaction.set(transactionRef, transactionData);

        // Update user account balance
        final accountDocRef = _firestore.collection('user_accounts').doc(userId);
        final accountDoc = await transaction.get(accountDocRef);
        
        if (accountDoc.exists) {
          final data = accountDoc.data()!;
          final currentBalance = (data['balance']['current'] as num?)?.toDouble() ?? 0.0;
          final totalSpent = (data['balance']['totalSpent'] as num?)?.toDouble() ?? 0.0;

          transaction.update(accountDocRef, {
            'balance.current': currentBalance + amount,
            'balance.totalSpent': (totalSpent - amount).clamp(0.0, double.infinity),
            'balance.lastUpdated': FieldValue.serverTimestamp(),
            'balance.lastTransactionId': transactionRef.id,
            'timestamps.updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      AppLogger.success('Refund transaction created successfully: ${transactionRef.id}');
      
      return {
        'success': true,
        'transactionId': transactionRef.id,
        'amount': amount,
        'type': 'refund',
        'status': 'completed',
      };
    } catch (error) {
      AppLogger.error('Error creating refund transaction: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get transaction history for a user with pagination
  static Future<Map<String, dynamic>> getTransactionHistory({
    String? userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? transactionType, // 'deposit', 'purchase', 'refund'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }

      AppLogger.info('Fetching transaction history for: $uid, limit: $limit');

      Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamps.createdAt', descending: true)
          .limit(limit);

      // Add filters if provided
      if (transactionType != null) {
        query = query.where('type', isEqualTo: transactionType);
      }

      if (startDate != null) {
        query = query.where('timestamps.createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamps.createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      
      final transactions = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'userId': data['userId'],
          'type': data['type'],
          'amount': data['amount'],
          'description': data['description'],
          'status': data['status'],
          'paymentMethod': data['paymentMethod'],
          'invoiceId': data['invoiceId'],
          'orderId': data['orderId'],
          'mealId': data['mealId'],
          'originalTransactionId': data['originalTransactionId'],
          'metadata': data['metadata'] ?? {},
          'timestamps': data['timestamps'] ?? {},
          'createdAt': data['timestamps']?['createdAt'],
          'processedAt': data['timestamps']?['processedAt'],
        };
      }).toList();

      AppLogger.info('Found ${transactions.length} transactions for user: $uid');

      return {
        'success': true,
        'transactions': transactions,
        'count': transactions.length,
        'hasMore': transactions.length == limit,
        'lastDocument': querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      };
    } catch (error) {
      AppLogger.error('Error getting transaction history: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get transaction by ID
  static Future<Map<String, dynamic>> getTransaction(String transactionId) async {
    try {
      final doc = await _firestore.collection('transactions').doc(transactionId).get();
      
      if (!doc.exists) {
        return {'success': false, 'error': 'Transaction not found'};
      }

      final data = doc.data()!;
      return {
        'success': true,
        'transaction': {
          'id': doc.id,
          'userId': data['userId'],
          'type': data['type'],
          'amount': data['amount'],
          'description': data['description'],
          'status': data['status'],
          'paymentMethod': data['paymentMethod'],
          'invoiceId': data['invoiceId'],
          'orderId': data['orderId'],
          'mealId': data['mealId'],
          'originalTransactionId': data['originalTransactionId'],
          'metadata': data['metadata'] ?? {},
          'timestamps': data['timestamps'] ?? {},
        },
      };
    } catch (error) {
      AppLogger.error('Error getting transaction: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get transaction statistics for a user
  static Future<Map<String, dynamic>> getTransactionStatistics({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }

      Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: uid);

      if (startDate != null) {
        query = query.where('timestamps.createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamps.createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      double totalDeposits = 0.0;
      double totalPurchases = 0.0;
      double totalRefunds = 0.0;
      int depositCount = 0;
      int purchaseCount = 0;
      int refundCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] as String;
        final amount = (data['amount'] as num).toDouble();

        switch (type) {
          case 'deposit':
            totalDeposits += amount;
            depositCount++;
            break;
          case 'purchase':
            totalPurchases += amount;
            purchaseCount++;
            break;
          case 'refund':
            totalRefunds += amount;
            refundCount++;
            break;
        }
      }

      return {
        'success': true,
        'statistics': {
          'totalDeposits': totalDeposits,
          'totalPurchases': totalPurchases,
          'totalRefunds': totalRefunds,
          'netAmount': totalDeposits + totalRefunds - totalPurchases,
          'transactionCounts': {
            'deposits': depositCount,
            'purchases': purchaseCount,
            'refunds': refundCount,
            'total': querySnapshot.docs.length,
          },
          'averageTransaction': querySnapshot.docs.isNotEmpty 
              ? (totalDeposits + totalPurchases + totalRefunds) / querySnapshot.docs.length 
              : 0.0,
        },
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      };
    } catch (error) {
      AppLogger.error('Error getting transaction statistics: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Update transaction status (for pending transactions)
  static Future<Map<String, dynamic>> updateTransactionStatus({
    required String transactionId,
    required String status, // 'pending', 'completed', 'failed', 'cancelled'
    String? reason,
  }) async {
    try {
      AppLogger.info('Updating transaction status: $transactionId to $status');

      final updateData = {
        'status': status,
        'timestamps.statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (reason != null) {
        updateData['statusReason'] = reason;
      }

      if (status == 'completed') {
        updateData['timestamps.processedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('transactions').doc(transactionId).update(updateData);

      AppLogger.success('Transaction status updated: $transactionId -> $status');
      
      return {'success': true, 'transactionId': transactionId, 'status': status};
    } catch (error) {
      AppLogger.error('Error updating transaction status: $error');
      return {'success': false, 'error': error.toString()};
    }
  }
}