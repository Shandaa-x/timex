import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/money_format.dart';
import '../../../services/qpay_helper_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/logger.dart';

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
  Timer? _paymentCheckTimer;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _successController;

  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successRotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAutoPaymentCheck();
  }

  void _initializeAnimations() {
    // Pulse animation for waiting state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide animation for entry
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    _successRotationAnimation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _successController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  void _startAutoPaymentCheck() {
    // Start checking payment status automatically every 3 seconds
    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isPaymentCompleted && !_isCheckingPayment && mounted) {
        _checkPaymentStatus(isAutoCheck: true);
      }
    });
  }

  void _stopAutoPaymentCheck() {
    _paymentCheckTimer?.cancel();
    _paymentCheckTimer = null;
  }

  @override
  void dispose() {
    _stopAutoPaymentCheck();
    _pulseController.dispose();
    _slideController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _checkPaymentStatus({bool isAutoCheck = false}) async {
    // Only provide haptic feedback for manual checks
    if (!isAutoCheck) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _isCheckingPayment = true;
      _errorMessage = null;
    });

    try {
      final invoiceId = widget.qpayResult['invoice_id'];
      if (invoiceId == null) {
        throw Exception('Invoice ID not found');
      }

      AppLogger.info(
        'Checking payment status for invoice: $invoiceId ${isAutoCheck ? "(auto)" : "(manual)"}',
      );

      final result = await QPayHelperService.checkPayment(
        widget.accessToken,
        invoiceId,
      );

      if (result['success'] == true) {
        final count = result['count'] ?? 0;
        final rows = result['rows'] as List<dynamic>? ?? [];

        if (count > 0 && rows.isNotEmpty) {
          // Payment found - trigger success animation
          _stopAutoPaymentCheck(); // Stop auto-checking
          _pulseController.stop();
          setState(() {
            _isPaymentCompleted = true;
            _isCheckingPayment = false;
          });

          // Start success animation
          _successController.forward();

          // Haptic feedback for success
          HapticFeedback.heavyImpact();

          // Show success message and close after delay
          _showSuccessMessage();
          Future.delayed(const Duration(seconds: 2500), () {
            if (mounted) {
              Navigator.pop(
                context,
                true,
              ); // Return true to indicate payment success
            }
          });
        } else {
          // No payment found
          setState(() {
            _isCheckingPayment = false;
            if (!isAutoCheck) {
              // Only show error message for manual checks
              _errorMessage =
                  'Төлбөр олдсонгүй. Банкны аппд төлбөр хийгдсэнийг шалгана уу.';
            }
          });
          if (!isAutoCheck) {
            HapticFeedback.mediumImpact();
          }
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to check payment');
      }
    } catch (error) {
      AppLogger.error('Error checking payment status: $error');
      setState(() {
        _isCheckingPayment = false;
        if (!isAutoCheck) {
          // Only show error message for manual checks
          _errorMessage =
              'Төлбөрийн төлөв шалгахад алдаа гарлаа: ${error.toString()}';
        }
      });
      if (!isAutoCheck) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Төлбөр амжилттай боловсруулагдлаа!',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successLight,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Icon with animations
                  Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle with gradient
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _isPaymentCompleted
                                  ? [
                                      AppTheme.successLight,
                                      AppTheme.successLight.withOpacity(0.8),
                                    ]
                                  : [
                                      AppTheme.warningLight,
                                      AppTheme.warningLight.withOpacity(0.8),
                                    ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_isPaymentCompleted
                                            ? AppTheme.successLight
                                            : AppTheme.warningLight)
                                        .withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),

                        // Icon with animations
                        if (_isPaymentCompleted)
                          ScaleTransition(
                            scale: _successScaleAnimation,
                            child: RotationTransition(
                              turns: _successRotationAnimation,
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: const Icon(
                              Icons.schedule_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Title with beautiful typography
                  Text(
                    _isPaymentCompleted
                        ? 'Төлбөр амжилттай!'
                        : 'Төлбөр хүлээж байна',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isPaymentCompleted
                          ? AppTheme.successLight
                          : colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Amount with styling
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryLight.withOpacity(0.1),
                          AppTheme.primaryLight.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryLight.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      MoneyFormatService.formatWithSymbol(widget.amount),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description with better styling
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isPaymentCompleted
                          ? AppTheme.successLight.withOpacity(0.05)
                          : colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isPaymentCompleted
                            ? AppTheme.successLight.withOpacity(0.2)
                            : colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isPaymentCompleted
                                  ? Icons.celebration_rounded
                                  : Icons.info_outline_rounded,
                              color: _isPaymentCompleted
                                  ? AppTheme.successLight
                                  : colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isPaymentCompleted
                                    ? 'Таны төлбөр амжилттай боловсруулагдлаа.'
                                    : 'Банкны аппд төлбөр хийсний дараа автомат шалгагдана эсвэл "Төлбөр шалгах" товчийг дарна уу.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _isPaymentCompleted
                                      ? AppTheme.successLight
                                      : colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Auto-check indicator
                        if (!_isPaymentCompleted && !_isCheckingPayment) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Автомат шалгаж байна (3 секунд тутам)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Error message with modern styling
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.errorLight.withOpacity(0.05),
                            AppTheme.errorLight.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.errorLight.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.errorLight.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.errorLight,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.errorLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Action buttons with modern styling
                  if (!_isPaymentCompleted) ...[
                    // Primary action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCheckingPayment
                            ? null
                            : () => _checkPaymentStatus(isAutoCheck: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colorScheme.outline
                              .withOpacity(0.3),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isCheckingPayment
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Шалгаж байна...',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.refresh_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Төлбөр шалгах',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Secondary action button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Цуцлах',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Bottom safe area padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
