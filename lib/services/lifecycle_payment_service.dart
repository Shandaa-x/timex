import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../utils/logger.dart';
import 'qpay_helper_service.dart';
import 'user_payment_service.dart';

/// Lifecycle-aware payment service that monitors app state and handles
/// payment status checking when returning from banking apps
class LifecyclePaymentService with WidgetsBindingObserver {
  static final LifecyclePaymentService _instance =
      LifecyclePaymentService._internal();
  factory LifecyclePaymentService() => _instance;
  LifecyclePaymentService._internal();

  // Payment tracking state
  bool _isTrackingPayment = false;
  String? _activeInvoiceId;
  String? _activeAccessToken;
  DateTime? _paymentStartedAt;

  // Enhanced tracking for reliable status checks
  bool _isCheckingPaymentStatus = false;
  int _statusCheckAttempts = 0;
  static const int _maxStatusCheckAttempts = 3;

  // Callbacks for payment status updates
  final List<Function(PaymentStatus)> _statusCallbacks = [];
  final List<Function(String)> _errorCallbacks = [];

  // Debouncing for rapid lifecycle changes
  Timer? _statusCheckTimer;
  static const Duration _statusCheckDelay = Duration(milliseconds: 500);

  // Enhanced cooldown and retry logic
  DateTime? _lastStatusCheck;
  static const Duration _statusCheckCooldown = Duration(seconds: 1);

  /// Initialize the service and start listening to lifecycle changes
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    AppLogger.info('🔄 LifecyclePaymentService initialized');
  }

  /// Dispose the service and clean up resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusCheckTimer?.cancel();
    _statusCallbacks.clear();
    _errorCallbacks.clear();
    AppLogger.info('🔚 LifecyclePaymentService disposed');
  }

  /// Start tracking a payment with enhanced state management
  void startTrackingPayment({
    required String invoiceId,
    required String accessToken,
  }) {
    AppLogger.info('📱 Starting payment tracking for invoice: $invoiceId');

    _isTrackingPayment = true;
    _activeInvoiceId = invoiceId;
    _activeAccessToken = accessToken;
    _paymentStartedAt = DateTime.now();
    _isCheckingPaymentStatus = false;
    _statusCheckAttempts = 0;

    // Clear previous state
    _statusCheckTimer?.cancel();
    _lastStatusCheck = null;

    // Notify that tracking has started
    _notifyStatusCallbacks(PaymentStatus.tracking);
  }

  /// Stop tracking the current payment with cleanup
  void stopTrackingPayment() {
    AppLogger.info('🛑 Stopping payment tracking');

    _isTrackingPayment = false;
    _activeInvoiceId = null;
    _activeAccessToken = null;
    _paymentStartedAt = null;
    _isCheckingPaymentStatus = false;
    _statusCheckAttempts = 0;
    _statusCheckTimer?.cancel();
    _lastStatusCheck = null;
  }

  /// Add a callback for payment status updates
  void addStatusCallback(Function(PaymentStatus) callback) {
    _statusCallbacks.add(callback);
  }

  /// Remove a callback for payment status updates
  void removeStatusCallback(Function(PaymentStatus) callback) {
    _statusCallbacks.remove(callback);
  }

  /// Add a callback for error updates
  void addErrorCallback(Function(String) callback) {
    _errorCallbacks.add(callback);
  }

  /// Remove a callback for error updates
  void removeErrorCallback(Function(String) callback) {
    _errorCallbacks.remove(callback);
  }

  /// Handle app lifecycle state changes with enhanced logic
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    AppLogger.info('📱 App lifecycle state changed: $state');

    if (state == AppLifecycleState.resumed && _isTrackingPayment) {
      AppLogger.info('🔄 App resumed with active payment, checking status...');

      // Always check status when app resumes from banking app
      _forceStatusCheckOnResume();
    } else if (state == AppLifecycleState.paused && _isTrackingPayment) {
      AppLogger.info('⏸️ App paused during payment tracking');
      // Reset check attempts when app is paused (likely going to banking app)
      _statusCheckAttempts = 0;
    }
  }

  /// Force a status check when app resumes (bypass cooldowns)
  void _forceStatusCheckOnResume() {
    if (!_isTrackingPayment) return;

    // Cancel any existing timer
    _statusCheckTimer?.cancel();

    // Reset cooldown for app resume
    _lastStatusCheck = null;

    // Immediately schedule a check
    _statusCheckTimer = Timer(const Duration(milliseconds: 300), () {
      if (_isTrackingPayment) {
        _performStatusCheckWithRetry();
      }
    });
  }

  /// Manually schedule a status check (for external use)
  void scheduleStatusCheck() {
    _scheduleStatusCheck();
  }

  /// Schedule a payment status check with debouncing
  void _scheduleStatusCheck() {
    // Cancel any existing timer
    _statusCheckTimer?.cancel();

    // Check cooldown (but allow bypass for app resume)
    if (_lastStatusCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastStatusCheck!);
      if (timeSinceLastCheck < _statusCheckCooldown) {
        AppLogger.info('⏱️ Status check on cooldown, waiting...');
        return;
      }
    }

    // Schedule new check
    _statusCheckTimer = Timer(_statusCheckDelay, () {
      if (_isTrackingPayment) {
        _performStatusCheckWithRetry();
      }
    });
  }

  /// Perform payment status check with retry logic
  Future<void> _performStatusCheckWithRetry() async {
    if (_isCheckingPaymentStatus) {
      AppLogger.info('⏳ Already checking payment status, skipping...');
      return;
    }

    if (_statusCheckAttempts >= _maxStatusCheckAttempts) {
      AppLogger.warning('⚠️ Max status check attempts reached');
      _notifyErrorCallbacks('Maximum check attempts exceeded');
      return;
    }

    _statusCheckAttempts++;
    await _performStatusCheck();
  }

  /// Perform the actual payment status check with enhanced error handling
  Future<void> _performStatusCheck() async {
    if (!_isTrackingPayment ||
        _activeInvoiceId == null ||
        _activeAccessToken == null) {
      return;
    }

    _isCheckingPaymentStatus = true;
    _lastStatusCheck = DateTime.now();

    try {
      AppLogger.info(
        '🔍 Checking payment status for invoice: $_activeInvoiceId (attempt $_statusCheckAttempts)',
      );

      // Notify callbacks that we're checking
      _notifyStatusCallbacks(PaymentStatus.checking);

      // Check payment via QPay API
      final result = await QPayHelperService.checkPayment(
        _activeAccessToken!,
        _activeInvoiceId!,
      );

      if (result['success'] == true) {
        final count = result['count'] ?? 0;
        final rows = result['rows'] as List<dynamic>? ?? [];

        if (count > 0 && rows.isNotEmpty) {
          // Payment found - process it
          AppLogger.success(
            '✅ Payment completed for invoice: $_activeInvoiceId',
          );

          final paymentData = rows.first;
          final dynamic rawAmount =
              paymentData['payment_amount'] ??
              paymentData['paid_amount'] ??
              0.0;
          final double paidAmount = rawAmount is String
              ? double.tryParse(rawAmount) ?? 0.0
              : (rawAmount as num).toDouble();

          // Process payment in UserPaymentService
          await _processPaymentCompletion(paidAmount, paymentData);

          // Notify success
          _notifyStatusCallbacks(PaymentStatus.completed);

          // Stop tracking since payment is complete
          stopTrackingPayment();
        } else {
          // No payment found yet
          AppLogger.info(
            '⏳ Payment not found yet for invoice: $_activeInvoiceId',
          );
          _notifyStatusCallbacks(PaymentStatus.pending);

          // Schedule retry if under max attempts
          if (_statusCheckAttempts < _maxStatusCheckAttempts) {
            _scheduleRetryCheck();
          }
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to check payment status');
      }
    } catch (error) {
      AppLogger.error('❌ Error checking payment status: $error');
      _notifyErrorCallbacks('Status check failed: $error');
      _notifyStatusCallbacks(PaymentStatus.error);

      // Schedule retry if under max attempts
      if (_statusCheckAttempts < _maxStatusCheckAttempts) {
        _scheduleRetryCheck();
      }
    } finally {
      _isCheckingPaymentStatus = false;
    }
  }

  /// Schedule a retry check with exponential backoff
  void _scheduleRetryCheck() {
    final retryDelay = Duration(
      seconds: _statusCheckAttempts * 2,
    ); // 2s, 4s, 6s
    AppLogger.info('🔄 Scheduling retry check in ${retryDelay.inSeconds}s');

    _statusCheckTimer = Timer(retryDelay, () {
      if (_isTrackingPayment &&
          _statusCheckAttempts < _maxStatusCheckAttempts) {
        _performStatusCheckWithRetry();
      }
    });
  }

  /// Process payment completion through UserPaymentService
  Future<void> _processPaymentCompletion(
    double paidAmount,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final userId = _getCurrentUserId();
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final result = await UserPaymentService.processPayment(
        userId: userId,
        paidAmount: paidAmount,
        paymentMethod: 'qpay',
        invoiceId: _activeInvoiceId!,
        orderId: paymentData['order_id']?.toString(),
      );

      if (result['success'] == true) {
        AppLogger.success(
          '💰 Payment processed successfully in UserPaymentService',
        );
      } else {
        throw Exception(result['error'] ?? 'Failed to process payment');
      }
    } catch (error) {
      AppLogger.error('❌ Error processing payment completion: $error');
      rethrow;
    }
  }

  /// Get current user ID from Firebase Auth
  String _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  /// Notify all status callbacks
  void _notifyStatusCallbacks(PaymentStatus status) {
    for (final callback in _statusCallbacks) {
      try {
        callback(status);
      } catch (error) {
        AppLogger.error('Error in status callback: $error');
      }
    }
  }

  /// Notify all error callbacks
  void _notifyErrorCallbacks(String error) {
    for (final callback in _errorCallbacks) {
      try {
        callback(error);
      } catch (error) {
        AppLogger.error('Error in error callback: $error');
      }
    }
  }

  /// Force a manual status check (for manual refresh)
  Future<void> forceStatusCheck() async {
    if (!_isTrackingPayment) {
      AppLogger.warning('⚠️ No payment being tracked, ignoring force check');
      return;
    }

    AppLogger.info('🔄 Force checking payment status...');

    // Reset attempt counter and cooldown for manual check
    _statusCheckAttempts = 0;
    _lastStatusCheck = null;
    _isCheckingPaymentStatus = false;

    await _performStatusCheckWithRetry();
  }

  /// Check if currently checking payment status
  bool get isCheckingStatus => _isCheckingPaymentStatus;

  /// Get current attempt count
  int get attemptCount => _statusCheckAttempts;

  /// Check if currently tracking a payment
  bool get isTrackingPayment => _isTrackingPayment;

  /// Get the active invoice ID being tracked
  String? get activeInvoiceId => _activeInvoiceId;

  /// Get how long the payment has been active
  Duration? get paymentDuration {
    if (_paymentStartedAt == null) return null;
    return DateTime.now().difference(_paymentStartedAt!);
  }
}

/// Enum representing different payment statuses
enum PaymentStatus {
  tracking, // Started tracking payment
  checking, // Currently checking payment status
  pending, // No payment found yet
  completed, // Payment successfully completed
  error, // Error occurred during checking
}

/// Extension to provide user-friendly status messages
extension PaymentStatusExtension on PaymentStatus {
  String get message {
    switch (this) {
      case PaymentStatus.tracking:
        return 'Payment tracking started...';
      case PaymentStatus.checking:
        return 'Checking payment status...';
      case PaymentStatus.pending:
        return 'Waiting for payment confirmation...';
      case PaymentStatus.completed:
        return 'Payment completed successfully!';
      case PaymentStatus.error:
        return 'Error checking payment status';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.tracking:
        return Colors.blue[300]!;
      case PaymentStatus.checking:
        return Colors.blue;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.error:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentStatus.tracking:
        return Icons.track_changes;
      case PaymentStatus.checking:
        return Icons.refresh;
      case PaymentStatus.pending:
        return Icons.access_time;
      case PaymentStatus.completed:
        return Icons.check_circle;
      case PaymentStatus.error:
        return Icons.error;
    }
  }
}
