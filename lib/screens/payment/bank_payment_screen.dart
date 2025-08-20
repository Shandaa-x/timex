import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/money_format.dart';
import '../../services/qpay_helper_service.dart';
import '../../services/user_payment_service.dart';
import '../../theme/app_theme.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class BankPaymentScreen extends StatefulWidget {
  final int amount;
  final Map<String, dynamic> bank;
  final String? description;

  const BankPaymentScreen({
    super.key,
    required this.amount,
    required this.bank,
    this.description,
  });

  @override
  State<BankPaymentScreen> createState() => _BankPaymentScreenState();
}

class _BankPaymentScreenState extends State<BankPaymentScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  String _paymentStatus = 'preparing';
  String? _invoiceId;
  String? _errorMessage;
  Timer? _statusCheckTimer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initiatePayment();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _paymentStatus = 'creating_invoice';
      _isProcessing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final String orderId = 'TIMEX_${DateTime.now().millisecondsSinceEpoch}';

      // Create QPay invoice
      final result = await QPayHelperService.createInvoiceWithQR(
        amount: widget.amount.toDouble(),
        orderId: orderId,
        userId: currentUser.uid,
        invoiceDescription: 'TIMEX Payment - ${widget.bank['mongolianName']}',
        enableSocialPay: true,
      );

      if (result['success'] == true) {
        setState(() {
          _invoiceId = result['invoice']['invoice_id'];
          _paymentStatus = 'ready_to_pay';
        });
        _startStatusChecking();
      } else {
        throw Exception(result['error'] ?? 'Failed to create payment invoice');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _paymentStatus = 'error';
        _isProcessing = false;
      });
    }
  }

  void _startStatusChecking() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (_invoiceId != null) {
        await _checkPaymentStatus();
      }
    });

    // Auto-launch banking app after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      _launchBankingApp();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_invoiceId == null) return;

    try {
      final authResult = await QPayHelperService.getAccessToken();
      if (authResult['success'] == true) {
        final paymentResult = await QPayHelperService.checkPayment(
          authResult['access_token'],
          _invoiceId!,
        );

        if (paymentResult['success'] == true) {
          final int count = paymentResult['count'] ?? 0;
          if (count > 0) {
            setState(() {
              _paymentStatus = 'completed';
              _isProcessing = false;
            });
            _statusCheckTimer?.cancel();
            await _processPaymentSuccess();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    }
  }

  Future<void> _processPaymentSuccess() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await UserPaymentService.processPayment(
          userId: currentUser.uid,
          paidAmount: widget.amount.toDouble(),
          paymentMethod: widget.bank['mongolianName'],
          invoiceId: _invoiceId!,
        );

        // Show success message after a delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _showSuccessDialog();
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing payment success: $e');
    }
  }

  Future<void> _launchBankingApp() async {
    if (!mounted) return;

    try {
      final String scheme = widget.bank['scheme'] ?? '';
      if (scheme.isNotEmpty) {
        final uri = Uri.parse(scheme);
        if (await canLaunchUrl(uri)) {
          setState(() {
            _paymentStatus = 'waiting_for_payment';
          });
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error launching banking app: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.bank['mongolianName'] ?? widget.bank['name'],
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_paymentStatus == 'waiting_for_payment')
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _checkPaymentStatus,
              tooltip: 'Төлбөрийн төлөв шалгах',
            ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Bank Info Card
                    _buildBankInfoCard(theme, colorScheme),

                    const SizedBox(height: 24),

                    // Payment Status Card
                    _buildPaymentStatusCard(theme, colorScheme),

                    const SizedBox(height: 24),

                    // Instructions
                    _buildInstructions(theme, colorScheme),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            _buildBottomActions(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfoCard(ThemeData theme, ColorScheme colorScheme) {
    final bankColor = widget.bank['color'] as Color? ?? AppTheme.primaryLight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bankColor, bankColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bankColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bank Logo
          Hero(
            tag: 'bank_${widget.bank['name']}',
            child: Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                widget.bank['icon'],
                width: 56,
                height: 56,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.account_balance,
                    color: Colors.white,
                    size: 56,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bank Name
          Text(
            widget.bank['mongolianName'] ?? widget.bank['name'],
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Payment Amount
          Text(
            MoneyFormatService.formatWithSymbol(widget.amount),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),

          if (widget.description != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStatusCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor().withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Icon
          ScaleTransition(
            scale: _paymentStatus == 'waiting_for_payment'
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_getStatusIcon(), color: _getStatusColor(), size: 32),
            ),
          ),

          const SizedBox(height: 16),

          // Status Text
          Text(
            _getStatusText(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: _getStatusColor(),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Status Description
          Text(
            _getStatusDescription(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          // Loading indicator for processing states
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructions(ThemeData theme, ColorScheme colorScheme) {
    final instructions = _getInstructions();
    if (instructions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Зөвлөмж',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...instructions.map(
            (instruction) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, right: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      instruction,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paymentStatus == 'ready_to_pay' ||
                _paymentStatus == 'waiting_for_payment')
              ElevatedButton(
                onPressed: _launchBankingApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.bank['color'] as Color? ?? AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.launch_rounded),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.bank['mongolianName']} нээх',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            if (_paymentStatus == 'error')
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initiatePayment();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Дахин оролдох',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Cancel Button
            if (_paymentStatus != 'completed')
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Цуцлах',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_paymentStatus) {
      case 'completed':
        return AppTheme.successLight;
      case 'error':
        return AppTheme.errorLight;
      case 'waiting_for_payment':
        return AppTheme.warningLight;
      default:
        return AppTheme.primaryLight;
    }
  }

  IconData _getStatusIcon() {
    switch (_paymentStatus) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'waiting_for_payment':
        return Icons.pending_rounded;
      case 'ready_to_pay':
        return Icons.payment_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String _getStatusText() {
    switch (_paymentStatus) {
      case 'creating_invoice':
        return 'Төлбөр бэлдэж байна...';
      case 'ready_to_pay':
        return 'Төлбөр төлөхөд бэлэн';
      case 'waiting_for_payment':
        return 'Төлбөр хүлээж байна...';
      case 'completed':
        return 'Төлбөр амжилттай';
      case 'error':
        return 'Алдаа гарлаа';
      default:
        return 'Боловсруулж байна...';
    }
  }

  String _getStatusDescription() {
    switch (_paymentStatus) {
      case 'creating_invoice':
        return 'Таны төлбөрийн мэдээллийг бэлдэж байна';
      case 'ready_to_pay':
        return 'Банкны аппыг нээж төлбөр төлнө үү';
      case 'waiting_for_payment':
        return 'Банкны аппад төлбөр хийснийг хүлээж байна';
      case 'completed':
        return 'Таны төлбөр амжилттай боловсруулагдлаа';
      case 'error':
        return _errorMessage ?? 'Дахин оролдоно уу';
      default:
        return 'Түр хүлээнэ үү...';
    }
  }

  List<String> _getInstructions() {
    switch (_paymentStatus) {
      case 'ready_to_pay':
      case 'waiting_for_payment':
        return [
          'Доорх товчийг дарж банкны аппыг нээнэ үү',
          'Аппад нэвтэрч төлбөр хийнэ үү',
          'Төлбөр амжилттай болсон дараа энэ хуудас автоматаар шинэчлэгдэнэ',
        ];
      case 'completed':
        return [
          'Төлбөр амжилттай боловсруулагдлаа',
          'Таны дансны үлдэгдэл шинэчлэгдсэн байна',
        ];
      default:
        return [];
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.successLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.successLight,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Төлбөр амжилттай!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.successLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              MoneyFormatService.formatWithSymbol(widget.amount),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'дүнтэй төлбөр амжилттай боловсруулагдлаа.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
              Navigator.of(context).pop(); // Go back to main screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Буцах'),
          ),
        ],
      ),
    );
  }
}
