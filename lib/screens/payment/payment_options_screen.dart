import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/money_format.dart';
import '../../services/user_payment_service.dart';
import '../../theme/app_theme.dart';
import 'payment_screen.dart';
import 'bank_selection_screen.dart';

class PaymentOptionsScreen extends StatefulWidget {
  final double? suggestedAmount;
  final String? description;

  const PaymentOptionsScreen({
    super.key,
    this.suggestedAmount,
    this.description,
  });

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  double _currentBalance = 0.0;
  String _paymentStatus = 'none';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserBalance();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _loadUserBalance() async {
    try {
      final paymentInfo = await UserPaymentService.getUserPaymentInfo();
      if (paymentInfo['success'] == true) {
        setState(() {
          _currentBalance = paymentInfo['totalFoodAmount'] ?? 0.0;
          _paymentStatus = paymentInfo['qpayStatus'] ?? 'none';
        });
      }
    } catch (e) {
      debugPrint('Error loading balance: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryLight,
                    AppTheme.primaryLight.withOpacity(0.8),
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  'Төлбөрийн сонголт',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _loadUserBalance,
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Balance Status Card
                    _buildBalanceStatusCard(theme, colorScheme),

                    const SizedBox(height: 24),

                    // Payment Options
                    _buildPaymentOptionsSection(theme, colorScheme),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStatusCard(ThemeData theme, ColorScheme colorScheme) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText();

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [statusColor, statusColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _isLoading
          ? _buildLoadingBalance()
          : Column(
              children: [
                // Status Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(statusIcon, color: Colors.white, size: 32),
                ),

                const SizedBox(height: 16),

                // Status Title
                Text(
                  statusText,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Balance Amount
                Text(
                  MoneyFormatService.formatWithSymbol(_currentBalance.round()),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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

  Widget _buildLoadingBalance() {
    return Column(
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
        const SizedBox(height: 16),
        Text(
          'Төлөвийг шалгаж байна...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOptionsSection(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Төлбөр төлөх аргууд',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          // Quick Payment Button
          _buildPaymentOption(
            icon: Icons.flash_on_rounded,
            title: 'Шилжүүлэг хийх',
            description: 'Банкны апп эсвэл QPay ашиглан төлөх',
            gradient: [
              AppTheme.primaryLight,
              AppTheme.primaryLight.withOpacity(0.8),
            ],
            onTap: () => _navigateToPayment(),
            theme: theme,
          ),

          const SizedBox(height: 12),

          // Bank Selection Button
          _buildPaymentOption(
            icon: Icons.account_balance_rounded,
            title: 'Банк сонгох',
            description: 'Банкуудын жагсаалтаас сонгон төлөх',
            gradient: [
              AppTheme.secondaryLight,
              AppTheme.secondaryLight.withOpacity(0.8),
            ],
            onTap: () => _navigateToBankSelection(),
            theme: theme,
          ),

          const SizedBox(height: 12),

          // Custom Amount Button (if no suggested amount)
          if (widget.suggestedAmount == null)
            _buildPaymentOption(
              icon: Icons.edit_rounded,
              title: 'Дүн оруулах',
              description: 'Төлөх дүнгээ өөрөө оруулах',
              gradient: [
                AppTheme.accentLight,
                AppTheme.accentLight.withOpacity(0.8),
              ],
              onTap: () => _showCustomAmountDialog(),
              theme: theme,
            ),

          if (_currentBalance <= 0) ...[
            const SizedBox(height: 20),
            _buildNoBalanceMessage(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _currentBalance > 0 ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _currentBalance > 0
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    )
                  : null,
              color: _currentBalance <= 0 ? Colors.grey[300] : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _currentBalance > 0
                  ? [
                      BoxShadow(
                        color: gradient.first.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoBalanceMessage(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Төлбөр дууссан байна!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Таны үлдэгдэл 0₮ байна. Нэмэлт төлбөр төлөх шаардлагагүй.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_paymentStatus) {
      case 'paid':
        return AppTheme.successLight;
      case 'partial':
        return AppTheme.warningLight;
      default:
        return _currentBalance > 0
            ? AppTheme.errorLight
            : AppTheme.successLight;
    }
  }

  IconData _getStatusIcon() {
    switch (_paymentStatus) {
      case 'paid':
        return Icons.check_circle_rounded;
      case 'partial':
        return Icons.payments_rounded;
      default:
        return _currentBalance > 0
            ? Icons.account_balance_wallet_rounded
            : Icons.check_circle_rounded;
    }
  }

  String _getStatusText() {
    switch (_paymentStatus) {
      case 'paid':
        return 'Төлбөр дууссан';
      case 'partial':
        return 'Хэсэгчилсэн төлбөр';
      default:
        return _currentBalance > 0
            ? 'Төлбөр төлөх шаардлагатай'
            : 'Төлбөр дууссан';
    }
  }

  void _navigateToPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PaymentScreen(initialAmount: widget.suggestedAmount?.round()),
      ),
    );
  }

  void _navigateToBankSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BankSelectionScreen(
          amount: widget.suggestedAmount?.round() ?? _currentBalance.round(),
        ),
      ),
    );
  }

  void _showCustomAmountDialog() {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Төлөх дүн оруулах',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Төлөх дүнгээ оруулна уу:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Дүн (₮)',
                suffixText: '₮',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Цуцлах'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(initialAmount: amount),
                  ),
                );
              }
            },
            child: Text('Үргэлжлүүлэх'),
          ),
        ],
      ),
    );
  }
}
