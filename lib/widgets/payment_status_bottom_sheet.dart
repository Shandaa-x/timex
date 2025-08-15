import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/lifecycle_payment_service.dart';
import '../widgets/beautiful_circular_progress.dart';
import 'dart:async';

/// Payment status bottom sheet with lifecycle-aware status checking
class PaymentStatusBottomSheet extends StatefulWidget {
  final String bankName;
  final double amount;
  final String? invoiceId;
  final String? orderId;
  final String? accessToken;
  final VoidCallback? onPaymentCompleted;
  final VoidCallback? onCancel;

  const PaymentStatusBottomSheet({
    super.key,
    required this.bankName,
    required this.amount,
    this.invoiceId,
    this.orderId,
    this.accessToken,
    this.onPaymentCompleted,
    this.onCancel,
  });

  @override
  State<PaymentStatusBottomSheet> createState() =>
      _PaymentStatusBottomSheetState();
}

class _PaymentStatusBottomSheetState extends State<PaymentStatusBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;

  PaymentStatus _currentStatus = PaymentStatus.tracking;
  String? _errorMessage;
  bool _isManualCheckDisabled = false;

  final LifecyclePaymentService _paymentService = LifecyclePaymentService();
  StreamSubscription<DocumentSnapshot>? _userDocumentListener;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start animations
    _animationController.repeat();
    _pulseController.repeat(reverse: true);

    // Setup lifecycle payment tracking
    _setupPaymentTracking();

    // Start listening to real-time payment updates
    _startListeningToPaymentUpdates();
  }

  void _setupPaymentTracking() {
    if (widget.invoiceId != null && widget.accessToken != null) {
      // Add status callback
      _paymentService.addStatusCallback(_onPaymentStatusChanged);
      _paymentService.addErrorCallback(_onPaymentError);

      // Start tracking the payment
      _paymentService.startTrackingPayment(
        invoiceId: widget.invoiceId!,
        accessToken: widget.accessToken!,
      );

      // Initial status check
      _performInitialStatusCheck();
    }
  }

  void _performInitialStatusCheck() async {
    setState(() {
      _currentStatus = PaymentStatus.checking;
      _isManualCheckDisabled = true;
    });

    // Wait a moment for the UI to update, then check
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await _paymentService.forceStatusCheck();
    } finally {
      if (mounted) {
        setState(() {
          _isManualCheckDisabled = false;
        });
      }
    }
  }

  void _onPaymentStatusChanged(PaymentStatus status) {
    if (!mounted) return;

    setState(() {
      _currentStatus = status;
      _errorMessage = null;
    });

    // Handle successful payment
    if (status == PaymentStatus.completed) {
      _handlePaymentCompleted();
    }
  }

  void _onPaymentError(String error) {
    if (!mounted) return;

    setState(() {
      _errorMessage = error;
      _currentStatus = PaymentStatus.error;
    });
  }

  void _startListeningToPaymentUpdates() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userDocumentListener = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen(
            (documentSnapshot) {
              if (documentSnapshot.exists && mounted) {
                final data = documentSnapshot.data()!;
                final String status = data['qpayStatus'] ?? 'pending';

                // If payment is completed in Firebase, trigger completion
                if (status == 'paid' &&
                    _currentStatus != PaymentStatus.completed) {
                  _onPaymentStatusChanged(PaymentStatus.completed);
                }
              }
            },
            onError: (error) {
              print('Firebase listener error: $error');
            },
          );
    }
  }

  void _handlePaymentCompleted() {
    // Stop animations
    _animationController.stop();
    _pulseController.stop();

    // Show completion message briefly, then call callback
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        widget.onPaymentCompleted?.call();
      }
    });
  }

  Future<void> _manualStatusCheck() async {
    if (_isManualCheckDisabled) return;

    setState(() {
      _isManualCheckDisabled = true;
      _currentStatus = PaymentStatus.checking;
      _errorMessage = null;
    });

    try {
      await _paymentService.forceStatusCheck();
    } finally {
      // Re-enable manual check after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isManualCheckDisabled = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _paymentService.removeStatusCallback(_onPaymentStatusChanged);
    _paymentService.removeErrorCallback(_onPaymentError);
    _paymentService.stopTrackingPayment();

    _userDocumentListener?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            spreadRadius: 5,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 32),

            // Status indicator with enhanced animation
            _buildStatusIndicator(),
            const SizedBox(height: 28),

            // Title with status-based styling
            _buildStatusTitle(),
            const SizedBox(height: 12),

            // Description
            _buildStatusDescription(),
            const SizedBox(height: 16),

            // Amount display
            _buildAmountDisplay(),
            const SizedBox(height: 32),

            // Action buttons
            _buildActionButtons(),
            const SizedBox(height: 16),

            // Cancel button
            _buildCancelButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              if (_currentStatus == PaymentStatus.checking)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 140 * (0.8 + 0.2 * _pulseController.value),
                      height: 140 * (0.8 + 0.2 * _pulseController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _currentStatus.color.withOpacity(
                            0.3 * (1 - _pulseController.value),
                          ),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),

              // Main status circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _getStatusGradient(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _currentStatus.color.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: _buildStatusIcon(),
              ),

              // Orbiting dots for checking status
              if (_currentStatus == PaymentStatus.checking)
                ..._buildOrbitingDots(),
            ],
          ),
        );
      },
    );
  }

  List<Color> _getStatusGradient() {
    switch (_currentStatus) {
      case PaymentStatus.completed:
        return [const Color(0xFF10B981), const Color(0xFF06B6D4)];
      case PaymentStatus.error:
        return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      case PaymentStatus.checking:
        return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
      default:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    }
  }

  Widget _buildStatusIcon() {
    if (_currentStatus == PaymentStatus.checking) {
      return BeautifulCircularProgress(
        size: 75,
        strokeWidth: 4,
        gradientColors: const [Colors.white, Color(0xFFF1F5F9)],
        backgroundColor: Colors.transparent,
        centerGlowColor: Colors.white,
        centerGlowSize: 30,
        animationDuration: const Duration(milliseconds: 1500),
      );
    }

    return Icon(_currentStatus.icon, color: Colors.white, size: 32);
  }

  List<Widget> _buildOrbitingDots() {
    return [
      for (int i = 0; i < 6; i++)
        Transform.rotate(
          angle: (_animationController.value * 2 * 3.14159) + (i * 3.14159 / 3),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(
                  0.5 + 0.5 * ((i / 6) + _animationController.value) % 1,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildStatusTitle() {
    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(colors: _getStatusGradient()).createShader(bounds),
      child: Text(
        _getStatusTitle(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case PaymentStatus.tracking:
        return 'Payment Started';
      case PaymentStatus.checking:
        return 'Checking Payment...';
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.completed:
        return 'Payment Completed!';
      case PaymentStatus.error:
        return 'Check Failed';
    }
  }

  Widget _buildStatusDescription() {
    String description;
    switch (_currentStatus) {
      case PaymentStatus.tracking:
        description = 'Please complete your payment in ${widget.bankName}';
        break;
      case PaymentStatus.checking:
        description = 'Please wait while we verify your payment status';
        break;
      case PaymentStatus.pending:
        description =
            'Complete your payment in ${widget.bankName} and tap "Check Status"';
        break;
      case PaymentStatus.completed:
        description = 'Your payment has been successfully processed!';
        break;
      case PaymentStatus.error:
        description =
            _errorMessage ??
            'Failed to check payment status. Please try again.';
        break;
    }

    return Text(
      description,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey[600],
        height: 1.5,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _currentStatus.color.withOpacity(0.08),
            _currentStatus.color.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _currentStatus.color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: _currentStatus.color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '₮${widget.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _currentStatus.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_currentStatus == PaymentStatus.completed) {
      return const SizedBox.shrink(); // No action needed for completed payment
    }

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _isManualCheckDisabled
            ? null
            : LinearGradient(
                colors: [
                  _currentStatus.color,
                  _currentStatus.color.withOpacity(0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
      ),
      child: ElevatedButton(
        onPressed: _isManualCheckDisabled ? null : _manualStatusCheck,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isManualCheckDisabled
              ? Colors.grey[200]
              : Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isManualCheckDisabled
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[600]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Checking...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : const Text(
                'Check Payment Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: () {
          _paymentService.stopTrackingPayment();
          Navigator.of(context).pop();
          widget.onCancel?.call();
        },
        child: Text(
          'Cancel',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ),
    );
  }
}
