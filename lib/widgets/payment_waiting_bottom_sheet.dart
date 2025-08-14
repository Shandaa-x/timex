import 'package:flutter/material.dart';
import '../services/money_format.dart';
import '../services/qpay_helper_service.dart';
import '../utils/logger.dart';

class PaymentWaitingBottomSheet extends StatefulWidget {
  final Map<String, dynamic> qpayResult;
  final int amount;
  final String accessToken;

  const PaymentWaitingBottomSheet({
    super.key,
    required this.qpayResult,
    required this.amount,
    required this.accessToken,
  });

  @override
  State<PaymentWaitingBottomSheet> createState() =>
      _PaymentWaitingBottomSheetState();
}

class _PaymentWaitingBottomSheetState extends State<PaymentWaitingBottomSheet>
    with TickerProviderStateMixin {
  bool _isCheckingPayment = false;
  bool _isPaymentCompleted = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    setState(() {
      _isCheckingPayment = true;
      _errorMessage = null;
    });

    try {
      final invoiceId = widget.qpayResult['invoice_id'];
      if (invoiceId == null) {
        throw Exception('Invoice ID not found');
      }

      AppLogger.info('Checking payment status for invoice: $invoiceId');

      final result = await QPayHelperService.checkPayment(
        widget.accessToken,
        invoiceId,
      );

      if (result['success'] == true) {
        final count = result['count'] ?? 0;
        final rows = result['rows'] as List<dynamic>? ?? [];

        if (count > 0 && rows.isNotEmpty) {
          // Payment found
          setState(() {
            _isPaymentCompleted = true;
            _isCheckingPayment = false;
          });

          // Show success message and close after delay
          _showSuccessMessage();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context, true); // Return true to indicate payment success
            }
          });
        } else {
          // No payment found
          setState(() {
            _isCheckingPayment = false;
            _errorMessage = 'Payment not found. Please complete payment in your banking app.';
          });
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to check payment');
      }
    } catch (error) {
      AppLogger.error('Error checking payment status: $error');
      setState(() {
        _isCheckingPayment = false;
        _errorMessage = 'Failed to check payment status: ${error.toString()}';
      });
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Payment completed successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Status Icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPaymentCompleted ? 1.0 : _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isPaymentCompleted
                        ? Colors.green
                        : Colors.orange[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPaymentCompleted
                        ? Icons.check_circle
                        : Icons.access_time,
                    size: 40,
                    color: _isPaymentCompleted
                        ? Colors.white
                        : Colors.orange[600],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            _isPaymentCompleted 
                ? 'Payment Completed!' 
                : 'Waiting for Payment',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isPaymentCompleted ? Colors.green : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Amount
          Text(
            MoneyFormatService.formatWithSymbol(widget.amount),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            _isPaymentCompleted
                ? 'Your payment has been processed successfully.'
                : 'Please complete the payment in your banking app, then tap "Check Payment" to confirm.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          if (!_isPaymentCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCheckingPayment ? null : _checkPaymentStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isCheckingPayment
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Check Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}