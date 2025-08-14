import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/money_format.dart';
import '../../services/qpay_helper_service.dart';
import '../../utils/socialpay_integration.dart';
import '../../widgets/beautiful_circular_progress.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentScreen extends StatefulWidget {
  final int? initialAmount;

  const PaymentScreen({super.key, this.initialAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  int _enteredAmount = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableBanks = [];

  // Bank data with proper icons and information matching the design
  final List<Map<String, dynamic>> _bankData = [
    {
      'name': 'Khan Bank',
      'mongolianName': 'Хаан банк',
      'icon': 'assets/images/khan.jpg',
      'packageName': 'mn.khan.bank',
      'scheme': 'khanbank://',
    },
    {
      'name': 'State Bank',
      'mongolianName': 'Төрийн банк 3.0',
      'icon': 'assets/images/state.png',
      'packageName': 'mn.statebank',
      'scheme': 'statebank://',
    },
    {
      'name': 'Xac Bank',
      'mongolianName': 'Хас банк',
      'icon': 'assets/images/xac.png',
      'packageName': 'mn.xac.bank',
      'scheme': 'xacbank://',
    },
    {
      'name': 'TDB Bank',
      'mongolianName': 'TDB online',
      'icon': 'assets/images/tdb.png',
      'packageName': 'mn.tdb.online',
      'scheme': 'tdbbank://',
    },
    {
      'name': 'SocialPay',
      'mongolianName': 'Сошиал Пэй',
      'icon': 'assets/images/socialpay.png',
      'packageName': 'mn.socialpay.app',
      'scheme': 'socialpay://',
    },
    {
      'name': 'Most Money',
      'mongolianName': 'МОСТ мони',
      'icon': 'assets/images/mostmoney.webp',
      'packageName': 'mn.most.money',
      'scheme': 'most://',
    },
    {
      'name': 'Trade Bank',
      'mongolianName': 'Үндэсний хөрөнгө оруулалтын банк',
      'icon': 'assets/images/mbank.png',
      'packageName': 'mn.trade.bank',
      'scheme': 'tradebank://',
    },
    {
      'name': 'Chinggis Khaan Bank',
      'mongolianName': 'Чингис Хаан банк',
      'icon': 'assets/images/toki.webp',
      'packageName': 'mn.chinggisnbank',
      'scheme': 'chinggisnbank://',
    },
    {
      'name': 'Capitron Bank',
      'mongolianName': 'Капитрон банк',
      'icon': 'assets/images/kapitron.webp',
      'packageName': 'mn.capitron.bank',
      'scheme': 'capitronbank://',
    },
    {
      'name': 'Bogd Bank',
      'mongolianName': 'Богд банк',
      'icon': 'assets/images/bogd.webp',
      'packageName': 'mn.bogd.bank',
      'scheme': 'bogdbank://',
    },
    {
      'name': 'Ard Bank',
      'mongolianName': 'Ард банк',
      'icon': 'assets/images/ard.webp',
      'packageName': 'mn.ard.bank',
      'scheme': 'ardbank://',
    },
    {
      'name': 'Arig Bank',
      'mongolianName': 'Ариг банк',
      'icon': 'assets/images/arig.webp',
      'packageName': 'mn.arig.bank',
      'scheme': 'arigbank://',
    },
    {
      'name': 'Trans Bank',
      'mongolianName': 'Транс банк',
      'icon': 'assets/images/trans.webp',
      'packageName': 'mn.trans.bank',
      'scheme': 'transbank://',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount.toString();
      _enteredAmount = widget.initialAmount!;
    }
    _loadAvailableBanks();
  }

  void _onAmountChanged(String value) {
    setState(() {
      _enteredAmount = int.tryParse(value) ?? 0;
    });
  }

  Future<void> _loadAvailableBanks() async {
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> availableBanks = [];

      for (final bank in _bankData) {
        // Simple check - just add all banks for now since BankingAppChecker.isAppInstalled doesn't exist
        availableBanks.add(bank);
      }

      setState(() {
        _availableBanks = availableBanks;
      });
    } catch (e) {
      print('Error loading banks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _currentInvoiceId;
  String? _currentOrderId;
  String? _processingBankId;

  Future<void> _processPayment(Map<String, dynamic> bank) async {
    if (_enteredAmount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _processingBankId = bank['name'];
    });

    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      final String userUid = currentUser?.uid ?? 'unknown';
      final String orderId =
          'TIMEX_PAYMENT_${DateTime.now().millisecondsSinceEpoch}';

      // Create QPay invoice
      final result = await QPayHelperService.createInvoiceWithQR(
        amount: _enteredAmount.toDouble(),
        orderId: orderId,
        userId: userUid,
        invoiceDescription:
            'TIMEX Payment - ₮${_enteredAmount.toStringAsFixed(0)}',
        enableSocialPay: true, // Enable SocialPay support
        callbackUrl: 'http://localhost:3000/qpay/webhook',
      );

      if (result['success'] == true) {
        final invoice = result['invoice'];
        final qrText = invoice['qr_text'] ?? '';
        final invoiceId = invoice['invoice_id'];

        // Store invoice details for status checking
        _currentInvoiceId = invoiceId;
        _currentOrderId = orderId;

        // Create deep link based on bank scheme
        String deepLink;
        if (bank['name'] == 'SocialPay') {
          // Use the SocialPay integration for proper deeplink format
          final socialPayLink = SocialPayIntegration.getSocialPayDeepLink(
            qrText: qrText,
            invoiceId: invoiceId,
          );
          if (socialPayLink != null) {
            deepLink = socialPayLink;
          } else {
            // Fallback to alternative format
            final altLink =
                SocialPayIntegration.getAlternativeSocialPayDeepLink(
                  qrText: qrText,
                  invoiceId: invoiceId,
                );
            deepLink =
                altLink ??
                '${bank['scheme']}qpay?qr=${Uri.encodeComponent(qrText)}';
          }
        } else if (bank['scheme'] == 'khanbank://') {
          deepLink = 'khanbank://qpay?qrText=$qrText&invoiceId=$invoiceId';
        } else if (bank['scheme'] == 'statebank://') {
          deepLink = 'statebank://qpay?qrText=$qrText&invoiceId=$invoiceId';
        } else {
          deepLink =
              '${bank['scheme']}qpay?qrText=$qrText&invoiceId=$invoiceId';
        }

        // Launch banking app
        final uri = Uri.parse(deepLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showSnackBar('Opening ${bank['mongolianName']}...', Colors.green);

          // Show payment status bottom sheet after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _showPaymentStatusBottomSheet(bank);
            }
          });
        } else {
          _showSnackBar('Cannot open ${bank['mongolianName']} app', Colors.red);
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to create QPay invoice');
      }
    } catch (e) {
      print('Payment error: $e');
      _showSnackBar('Payment failed: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
        _processingBankId = null;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPaymentStatusBottomSheet(Map<String, dynamic> bank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentStatusBottomSheet(
        bankName: bank['mongolianName'],
        amount: _enteredAmount,
        invoiceId: _currentInvoiceId,
        orderId: _currentOrderId,
        onCheckStatus: _checkPaymentStatus,
      ),
    );
  }

  Future<void> _checkPaymentStatus() async {
    if (_currentInvoiceId == null) {
      _showSnackBar('No payment to check', Colors.red);
      return;
    }

    try {
      // Here you would implement the actual payment status check
      // For now, we'll simulate a check
      await Future.delayed(const Duration(seconds: 2));

      // Simulate random status for demo
      final isCompleted = DateTime.now().millisecondsSinceEpoch % 2 == 0;

      if (isCompleted) {
        _showSnackBar('Payment completed successfully!', Colors.green);
        // Navigate back or update UI as needed
        Navigator.of(context).pop(); // Close bottom sheet
      } else {
        _showSnackBar('Payment is still pending...', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Failed to check payment status', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Хэтэвч цэнэглэх',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Amount input section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 18),
                    prefixText: '₮ ',
                    prefixStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: _onAmountChanged,
                ),
                if (_enteredAmount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Amount: ${MoneyFormatService.formatWithSymbol(_enteredAmount)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Banks list section
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BeautifulCircularProgress(
                          size: 90,
                          strokeWidth: 5,
                          gradientColors: const [
                            Color(0xFF8B5CF6),
                            Color(0xFFA78BFA),
                            Color(0xFFC084FC),
                            Color(0xFFE879F9),
                          ],
                          backgroundColor: const Color(0x1A8B5CF6),
                          centerGlowColor: const Color(0xFF8B5CF6),
                          centerGlowSize: 35,
                          animationDuration: const Duration(seconds: 2),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Loading Banks...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _availableBanks.isEmpty
                ? const Center(
                    child: Text(
                      'No banking apps available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _availableBanks.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final bank = _availableBanks[index];
                      return _buildBankTile(bank);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankTile(Map<String, dynamic> bank) {
    final isProcessing = _processingBankId == bank['name'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isProcessing ? Colors.purple : Colors.grey[200]!,
            width: isProcessing ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.asset(
                bank['icon'],
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.account_balance,
                      color: Colors.grey[400],
                      size: 28,
                    ),
                  );
                },
              ),
              if (isProcessing)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: BeautifulCircularProgress(
                      size: 30,
                      strokeWidth: 2.5,
                      gradientColors: const [
                        Color(0xFFFFFFFF),
                        Color(0xFFF8FAFC),
                        Color(0xFFE2E8F0),
                      ],
                      backgroundColor: Colors.transparent,
                      showCenterGlow: false,
                      animationDuration: const Duration(milliseconds: 1200),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(
        bank['mongolianName'],
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isProcessing ? Colors.purple : Colors.black87,
        ),
      ),
      trailing: isProcessing
          ? BeautifulCircularProgress(
              size: 24,
              strokeWidth: 2,
              gradientColors: const [
                Color(0xFF8B5CF6),
                Color(0xFFA78BFA),
                Color(0xFFC084FC),
              ],
              backgroundColor: Colors.transparent,
              showCenterGlow: false,
              animationDuration: const Duration(milliseconds: 1000),
            )
          : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: (_enteredAmount > 0 && !_isLoading)
          ? () => _processPayment(bank)
          : null,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}

class PaymentStatusBottomSheet extends StatefulWidget {
  final String bankName;
  final int amount;
  final String? invoiceId;
  final String? orderId;
  final VoidCallback onCheckStatus;

  const PaymentStatusBottomSheet({
    super.key,
    required this.bankName,
    required this.amount,
    this.invoiceId,
    this.orderId,
    required this.onCheckStatus,
  });

  @override
  State<PaymentStatusBottomSheet> createState() =>
      _PaymentStatusBottomSheetState();
}

class _PaymentStatusBottomSheetState extends State<PaymentStatusBottomSheet>
    with TickerProviderStateMixin {
  bool _isChecking = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Start animation immediately
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
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

            // Beautiful animated loading circle with enhanced design
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating progress ring (only when checking)
                      if (_isChecking)
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.purple.withOpacity(0.3),
                            ),
                            backgroundColor: Colors.grey.withOpacity(0.1),
                          ),
                        ),

                      // Middle pulsing ring
                      if (_isChecking)
                        Container(
                          width:
                              120 +
                              (10 *
                                  (0.5 +
                                      0.5 * (1 - _animationController.value))),
                          height:
                              120 +
                              (10 *
                                  (0.5 +
                                      0.5 * (1 - _animationController.value))),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.purple.withOpacity(
                                0.1 + (0.2 * (1 - _animationController.value)),
                              ),
                              width: 2,
                            ),
                          ),
                        ),

                      // Main circle with gradient and beautiful progress indicator
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isChecking
                                ? [
                                    const Color(0xFF8B5CF6),
                                    const Color(0xFFA78BFA),
                                    const Color(0xFFC084FC),
                                  ]
                                : [
                                    const Color(0xFF8B5CF6).withOpacity(0.8),
                                    const Color(0xFFA78BFA).withOpacity(0.9),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: _isChecking
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Beautiful circular progress indicator for checking state
                                  BeautifulCircularProgress(
                                    size: 75,
                                    strokeWidth: 5,
                                    gradientColors: const [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF1F5F9),
                                      Color(0xFFE2E8F0),
                                      Color(0xFFCBD5E1),
                                    ],
                                    backgroundColor: Colors.transparent,
                                    centerGlowColor: Colors.white,
                                    centerGlowSize: 30,
                                    animationDuration: const Duration(
                                      milliseconds: 1500,
                                    ),
                                  ),
                                  // Inner pulsing dot with enhanced animation
                                  AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return Container(
                                        width:
                                            18 +
                                            (8 *
                                                (0.5 +
                                                    0.5 *
                                                        (1 -
                                                            _animationController
                                                                .value))),
                                        height:
                                            18 +
                                            (8 *
                                                (0.5 +
                                                    0.5 *
                                                        (1 -
                                                            _animationController
                                                                .value))),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(
                                            0.7 +
                                                (0.3 *
                                                    (1 -
                                                        _animationController
                                                            .value)),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              blurRadius: 15,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Beautiful animated progress indicator for idle state
                                  BeautifulCircularProgress(
                                    size: 70,
                                    strokeWidth: 4,
                                    gradientColors: const [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF8FAFC),
                                      Color(0xFFE2E8F0),
                                    ],
                                    backgroundColor: Colors.transparent,
                                    centerGlowColor: Colors.white,
                                    centerGlowSize: 25,
                                    animationDuration: const Duration(
                                      seconds: 3,
                                    ),
                                  ),
                                  // Center icon with enhanced styling
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.95),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 18,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Animated orbiting dots (only when checking)
                      if (_isChecking) ...[
                        for (int i = 0; i < 8; i++)
                          Transform.rotate(
                            angle:
                                (_animationController.value * 2 * 3.14159) +
                                (i * 3.14159 / 4),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.purple.withOpacity(
                                        0.3 +
                                            (0.7 *
                                                ((i / 8) +
                                                    _animationController
                                                        .value) %
                                                1),
                                      ),
                                      Colors.purple.withOpacity(
                                        0.6 +
                                            (0.4 *
                                                ((i / 8) +
                                                    _animationController
                                                        .value) %
                                                1),
                                      ),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.withOpacity(0.3),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Title with gradient text effect
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              ).createShader(bounds),
              child: Text(
                _isChecking ? 'Checking Payment...' : 'Payment Pending',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description with better typography
            Text(
              _isChecking
                  ? 'Please wait while we verify your payment status'
                  : 'Please check if your payment was completed in ${widget.bankName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),

            // Amount info with stunning successful green and blue theme styling
            if (widget.amount > 0) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.08), // Emerald
                      const Color(0xFF3B82F6).withOpacity(0.12), // Blue
                      const Color(0xFF06B6D4).withOpacity(0.08), // Cyan
                      const Color(0xFF8B5CF6).withOpacity(0.06), // Purple accent
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 15,
                      spreadRadius: -8,
                      offset: const Offset(0, -4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Beautiful animated icon container with green-blue gradient
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF10B981), // Emerald-500
                            Color(0xFF06B6D4), // Cyan-500
                            Color(0xFF3B82F6), // Blue-500
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Amount text with enhanced green-blue typography
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Payment Amount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669).withOpacity(0.85), // Emerald-600
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF047857), // Emerald-700
                                Color(0xFF10B981), // Emerald-500
                                Color(0xFF06B6D4), // Cyan-500
                                Color(0xFF3B82F6), // Blue-500
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              '₮${widget.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Decorative elements with green-blue theme
                    const SizedBox(width: 16),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.15), // Emerald
                            const Color(0xFF3B82F6).withOpacity(0.10), // Blue
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF059669).withOpacity(0.7), // Emerald-600
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],

            // Check Payment Status Button with gradient
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _isChecking
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                boxShadow: _isChecking
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: _isChecking ? null : _handleCheckPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isChecking
                      ? Colors.grey[200]
                      : Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isChecking
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: _isChecking
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isChecking ? Colors.grey : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckPayment() async {
    setState(() => _isChecking = true);

    try {
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Small delay for UX
      widget.onCheckStatus();
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }
}
