import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Modern user account service for the improved Firebase structure
/// Manages user accounts in the 'user_accounts' collection
class ModernUserAccountService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or initialize a user account in the new structure
  static Future<Map<String, dynamic>> createUserAccount({
    required String userId,
    double initialBalance = 0.0,
    String accountType = 'food',
  }) async {
    try {
      AppLogger.info('Creating user account for: $userId');

      final accountDocRef = _firestore.collection('user_accounts').doc(userId);
      
      // Check if account already exists
      final existingDoc = await accountDocRef.get();
      if (existingDoc.exists) {
        AppLogger.info('User account already exists for: $userId');
        return {'success': true, 'existed': true, 'data': existingDoc.data()};
      }

      final accountData = {
        'userId': userId,
        'balance': {
          'current': initialBalance,
          'totalDeposited': initialBalance,
          'totalSpent': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        'status': 'active',
        'accountType': accountType,
        'timestamps': {
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      };

      await accountDocRef.set(accountData);

      AppLogger.success('User account created successfully for: $userId');
      return {'success': true, 'existed': false, 'data': accountData};
    } catch (error) {
      AppLogger.error('Error creating user account: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get user account information
  static Future<Map<String, dynamic>> getUserAccount([String? userId]) async {
    try {
      final String uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (uid.isEmpty) {
        throw Exception('No user ID provided');
      }

      final accountDoc = await _firestore
          .collection('user_accounts')
          .doc(uid)
          .get();

      if (!accountDoc.exists) {
        // Try to migrate from old structure
        AppLogger.info('Account not found, attempting migration for: $uid');
        final migrationResult = await _migrateFromLegacyStructure(uid);
        if (migrationResult['success']) {
          return migrationResult;
        } else {
          // Create new account with zero balance
          return await createUserAccount(userId: uid);
        }
      }

      final data = accountDoc.data()!;
      return {
        'success': true,
        'userId': uid,
        'balance': data['balance'] ?? {},
        'status': data['status'] ?? 'active',
        'accountType': data['accountType'] ?? 'food',
        'timestamps': data['timestamps'] ?? {},
      };
    } catch (error) {
      AppLogger.error('Error getting user account: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Update user account balance after a transaction
  static Future<Map<String, dynamic>> updateBalance({
    required String userId,
    required double amount,
    required String transactionType, // 'deposit', 'purchase', 'refund'
    String? transactionId,
  }) async {
    try {
      AppLogger.info('Updating balance for user: $userId, amount: ₮$amount, type: $transactionType');

      final accountDocRef = _firestore.collection('user_accounts').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final accountDoc = await transaction.get(accountDocRef);

        if (!accountDoc.exists) {
          throw Exception('User account not found');
        }

        final data = accountDoc.data()!;
        final currentBalance = (data['balance']['current'] as num?)?.toDouble() ?? 0.0;
        final totalDeposited = (data['balance']['totalDeposited'] as num?)?.toDouble() ?? 0.0;
        final totalSpent = (data['balance']['totalSpent'] as num?)?.toDouble() ?? 0.0;

        double newBalance;
        double newTotalDeposited = totalDeposited;
        double newTotalSpent = totalSpent;

        switch (transactionType) {
          case 'deposit':
            newBalance = currentBalance + amount;
            newTotalDeposited = totalDeposited + amount;
            break;
          case 'purchase':
            newBalance = (currentBalance - amount).clamp(0.0, double.infinity);
            newTotalSpent = totalSpent + amount;
            break;
          case 'refund':
            newBalance = currentBalance + amount;
            newTotalSpent = (totalSpent - amount).clamp(0.0, double.infinity);
            break;
          default:
            throw Exception('Invalid transaction type: $transactionType');
        }

        final updateData = {
          'balance.current': newBalance,
          'balance.totalDeposited': newTotalDeposited,
          'balance.totalSpent': newTotalSpent,
          'balance.lastUpdated': FieldValue.serverTimestamp(),
          'timestamps.updatedAt': FieldValue.serverTimestamp(),
        };

        if (transactionId != null) {
          updateData['balance.lastTransactionId'] = transactionId;
        }

        transaction.update(accountDocRef, updateData);

        AppLogger.success(
          'Balance updated: $userId - ₮$currentBalance → ₮$newBalance (${transactionType.toUpperCase()})',
        );

        return {
          'success': true,
          'userId': userId,
          'previousBalance': currentBalance,
          'newBalance': newBalance,
          'amount': amount,
          'transactionType': transactionType,
          'totalDeposited': newTotalDeposited,
          'totalSpent': newTotalSpent,
        };
      });
    } catch (error) {
      AppLogger.error('Error updating balance: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get account balance
  static Future<double> getBalance([String? userId]) async {
    try {
      final accountInfo = await getUserAccount(userId);
      if (accountInfo['success']) {
        return (accountInfo['balance']['current'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } catch (error) {
      AppLogger.error('Error getting balance: $error');
      return 0.0;
    }
  }

  /// Check if user has sufficient balance for a purchase
  static Future<bool> hasSufficientBalance(double amount, [String? userId]) async {
    try {
      final balance = await getBalance(userId);
      return balance >= amount;
    } catch (error) {
      AppLogger.error('Error checking balance: $error');
      return false;
    }
  }

  /// Update account status
  static Future<Map<String, dynamic>> updateAccountStatus({
    required String userId,
    required String status, // 'active', 'suspended', 'closed'
  }) async {
    try {
      AppLogger.info('Updating account status for: $userId to $status');

      await _firestore.collection('user_accounts').doc(userId).update({
        'status': status,
        'timestamps.updatedAt': FieldValue.serverTimestamp(),
        'timestamps.statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'status': status};
    } catch (error) {
      AppLogger.error('Error updating account status: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Migrate user data from legacy structure to new structure
  static Future<Map<String, dynamic>> _migrateFromLegacyStructure(String userId) async {
    try {
      AppLogger.info('Migrating legacy data for user: $userId');

      // Get legacy user document
      final legacyUserDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!legacyUserDoc.exists) {
        throw Exception('Legacy user document not found');
      }

      final legacyData = legacyUserDoc.data()!;
      
      // Extract balance information from legacy structure
      final totalFoodAmount = (legacyData['totalFoodAmount'] as num?)?.toDouble() ?? 0.0;
      final originalFoodAmount = (legacyData['originalFoodAmount'] as num?)?.toDouble() ?? 0.0;
      final paymentAmounts = List<dynamic>.from(legacyData['paymentAmounts'] ?? []);
      
      final totalDeposited = paymentAmounts
          .map((payment) => payment is String 
              ? double.tryParse(payment) ?? 0.0 
              : (payment as num).toDouble())
          .fold(0.0, (total, amount) => total + amount);
      
      final totalSpent = originalFoodAmount - totalFoodAmount;
      final currentBalance = totalFoodAmount;

      // Create new account structure
      final migrationResult = await createUserAccount(
        userId: userId,
        initialBalance: currentBalance,
      );

      if (migrationResult['success']) {
        // Update with calculated values
        await _firestore.collection('user_accounts').doc(userId).update({
          'balance.totalDeposited': totalDeposited,
          'balance.totalSpent': totalSpent,
          'balance.current': currentBalance,
          'balance.lastUpdated': FieldValue.serverTimestamp(),
          'migrated': true,
          'migratedAt': FieldValue.serverTimestamp(),
          'legacyData': {
            'originalFoodAmount': originalFoodAmount,
            'paymentAmounts': paymentAmounts,
          },
        });

        AppLogger.success('Successfully migrated user account: $userId');
        
        return {
          'success': true,
          'migrated': true,
          'balance': {
            'current': currentBalance,
            'totalDeposited': totalDeposited,
            'totalSpent': totalSpent,
          },
        };
      }

      return migrationResult;
    } catch (error) {
      AppLogger.error('Error migrating legacy data: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get account statistics
  static Future<Map<String, dynamic>> getAccountStatistics([String? userId]) async {
    try {
      final accountInfo = await getUserAccount(userId);
      if (!accountInfo['success']) {
        return accountInfo;
      }

      final balance = accountInfo['balance'];
      final current = (balance['current'] as num?)?.toDouble() ?? 0.0;
      final totalDeposited = (balance['totalDeposited'] as num?)?.toDouble() ?? 0.0;
      final totalSpent = (balance['totalSpent'] as num?)?.toDouble() ?? 0.0;

      return {
        'success': true,
        'statistics': {
          'currentBalance': current,
          'totalDeposited': totalDeposited,
          'totalSpent': totalSpent,
          'spendingPercentage': totalDeposited > 0 ? (totalSpent / totalDeposited * 100) : 0.0,
          'remainingPercentage': totalDeposited > 0 ? (current / totalDeposited * 100) : 0.0,
        },
        'status': accountInfo['status'],
        'accountType': accountInfo['accountType'],
      };
    } catch (error) {
      AppLogger.error('Error getting account statistics: $error');
      return {'success': false, 'error': error.toString()};
    }
  }
}