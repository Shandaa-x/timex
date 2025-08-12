/// Example usage of QPay Service in Flutter
/// This file demonstrates how to integrate QPay payments in your Flutter app
library qpay_example;

import 'package:flutter/material.dart';
import '../services/qpay_service.dart';
import '../models/qpay_models.dart';
import '../utils/logger.dart';

/// Example QPay payment screen
class QPayPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic>? user;

  const QPayPaymentScreen({Key? key, required this.order, this.user})
    : super(key: key);

  @override
  State<QPayPaymentScreen> createState() => _QPayPaymentScreenState();
}

class _QPayPaymentScreenState extends State<QPayPaymentScreen> {
  QPayInvoiceResult? _invoiceResult;
  QPayPaymentStatus? _paymentStatus;
  bool _isLoading = false;
  bool _isMonitoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createInvoice();
  }

  /// Create QPay invoice
  Future<void> _createInvoice() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      AppLogger.info(
        'Creating QPay invoice for order: ${widget.order['orderNumber']}',
      );

      final result = await QPayService.createInvoice(
        widget.order,
        widget.user,
        expirationMinutes: 5,
      );

      setState(() {
        _invoiceResult = result;
        _isLoading = false;
      });

      if (result.success) {
        // Start monitoring payment
        _startPaymentMonitoring();
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
      AppLogger.error('Failed to create invoice', error);
    }
  }

  /// Start monitoring payment status
  Future<void> _startPaymentMonitoring() async {
    if (_invoiceResult?.invoiceId == null || _isMonitoring) return;

    setState(() {
      _isMonitoring = true;
    });

    try {
      await QPayService.monitorPayment(
        _invoiceResult!.invoiceId!,
        onPaymentComplete: (paymentData) {
          setState(() {
            _paymentStatus = QPayPaymentStatus(
              success: true,
              isPaid: true,
              paymentData: paymentData,
            );
            _isMonitoring = false;
          });
          _showPaymentSuccess();
        },
        onSessionExpired: () {
          setState(() {
            _isMonitoring = false;
          });
          _showSessionExpired();
        },
        onTimeout: () {
          setState(() {
            _isMonitoring = false;
          });
          _showTimeout();
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
            _isMonitoring = false;
          });
        },
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isMonitoring = false;
      });
    }
  }

  /// Check payment status manually
  Future<void> _checkPaymentStatus() async {
    if (_invoiceResult?.invoiceId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final status = await QPayService.checkPaymentStatus(
        _invoiceResult!.invoiceId!,
      );

      setState(() {
        _paymentStatus = status;
        _isLoading = false;
      });

      if (status.isPaid) {
        _showPaymentSuccess();
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  /// Simulate payment for testing
  Future<void> _simulatePayment() async {
    if (_invoiceResult?.invoiceId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await QPayService.simulatePayment(
        _invoiceResult!.invoiceId!,
        _invoiceResult!.amount,
      );

      // Check status after simulation
      await _checkPaymentStatus();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  /// Show payment success dialog
  void _showPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful! 🎉'),
        content: const Text('Your payment has been processed successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show session expired dialog
  void _showSessionExpired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'The payment session has expired. Please try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createInvoice(); // Recreate invoice
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show timeout dialog
  void _showTimeout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Timeout'),
        content: const Text(
          'Payment monitoring has timed out. Please check manually or try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkPaymentStatus();
            },
            child: const Text('Check Status'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QPay Payment'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order Number: ${widget.order['orderNumber'] ?? 'N/A'}',
                    ),
                    Text(
                      'Total Amount: \$${widget.order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                    ),
                    Text(
                      'Items: ${(widget.order['items'] as List?)?.length ?? 0}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Loading indicator
            if (_isLoading) const Center(child: CircularProgressIndicator()),

            // Error display
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              ),

            // QPay invoice details
            if (_invoiceResult != null && _invoiceResult!.success)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QPay Invoice',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Invoice ID: ${_invoiceResult!.invoiceId}'),
                      Text(
                        'Amount: \$${_invoiceResult!.amount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 16),

                      // QR Code placeholder
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('QR Code will appear here'),
                              Text('(Install qr_flutter package)'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Payment status
            if (_paymentStatus != null)
              Card(
                color: _paymentStatus!.isPaid
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Status',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _paymentStatus!.isPaid ? 'PAID ✅' : 'PENDING ⏳',
                        style: TextStyle(
                          color: _paymentStatus!.isPaid
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_paymentStatus!.totalPaid > 0)
                        Text(
                          'Paid Amount: \$${_paymentStatus!.totalPaid.toStringAsFixed(2)}',
                        ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Action buttons
            if (_invoiceResult != null && _invoiceResult!.success) ...[
              ElevatedButton(
                onPressed: _isLoading ? null : _checkPaymentStatus,
                child: const Text('Check Payment Status'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _simulatePayment,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Simulate Payment (Testing)'),
              ),
              const SizedBox(height: 8),
              if (_isMonitoring)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isMonitoring = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Stop Monitoring'),
                ),
            ],

            // Retry button for errors
            if (_error != null)
              ElevatedButton(
                onPressed: _createInvoice,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Example of how to use QPay service in a simple function
Future<void> exampleQPayUsage() async {
  // Example order data
  final Map<String, dynamic> sampleOrder = {
    'orderNumber': 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
    'totalAmount': 25.99,
    'items': [
      {'productName': 'Sample Product 1', 'numericPrice': 15.99, 'quantity': 1},
      {'productName': 'Sample Product 2', 'numericPrice': 10.00, 'quantity': 1},
    ],
  };

  // Example user data
  final Map<String, dynamic> sampleUser = {
    'uid': 'user_123',
    'email': 'user@example.com',
  };

  try {
    // 1. Create invoice
    AppLogger.info('Creating QPay invoice...');
    final invoiceResult = await QPayService.createInvoice(
      sampleOrder,
      sampleUser,
      expirationMinutes: 5,
    );

    if (invoiceResult.success) {
      AppLogger.success('Invoice created: ${invoiceResult.invoiceId}');

      // 2. Monitor payment (in a real app, this would be in a widget)
      AppLogger.info('Starting payment monitoring...');
      await QPayService.monitorPayment(
        invoiceResult.invoiceId!,
        onPaymentComplete: (paymentData) {
          AppLogger.success('Payment completed! 🎉');
          AppLogger.info('Payment data: $paymentData');
        },
        onSessionExpired: () {
          AppLogger.warning('Payment session expired');
        },
        onTimeout: () {
          AppLogger.warning('Payment monitoring timeout');
        },
        onError: (error) {
          AppLogger.error('Payment monitoring error', error);
        },
      );
    } else {
      AppLogger.error('Failed to create invoice: ${invoiceResult.error}');
    }
  } catch (error) {
    AppLogger.error('QPay usage example failed', error);
  }
}

/// Helper function to create test order data
Map<String, dynamic> createTestOrder({
  double totalAmount = 50.0,
  int itemCount = 2,
}) {
  final List<Map<String, dynamic>> items = List.generate(
    itemCount,
    (index) => {
      'productName': 'Test Product ${index + 1}',
      'numericPrice': totalAmount / itemCount,
      'quantity': 1,
    },
  );

  return {
    'orderNumber': 'TEST_ORDER_${DateTime.now().millisecondsSinceEpoch}',
    'totalAmount': totalAmount,
    'items': items,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

/// Helper function to create test user data
Map<String, dynamic> createTestUser({
  String uid = 'test_user_123',
  String email = 'test@example.com',
}) {
  return {'uid': uid, 'email': email, 'displayName': 'Test User'};
}
