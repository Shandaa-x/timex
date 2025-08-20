import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/money_format.dart';
import '../../theme/app_theme.dart';
import '../../theme/assets.dart';
import 'payment_screen.dart';

class BankSelectionScreen extends StatefulWidget {
  final int amount;
  final String? description;

  const BankSelectionScreen({
    super.key,
    required this.amount,
    this.description,
  });

  @override
  State<BankSelectionScreen> createState() => _BankSelectionScreenState();
}

class _BankSelectionScreenState extends State<BankSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _headerController;
  late Animation<double> _listAnimation;
  late Animation<Offset> _headerAnimation;

  final List<Map<String, dynamic>> _banks = [
    {
      'name': 'Khan Bank',
      'mongolianName': 'Хаан банк',
      'icon': Assets.khan,
      'packageName': 'mn.khan.bank',
      'scheme': 'khanbank://',
      'color': const Color(0xFF1E3A8A),
      'isInstalled': true,
      'description': 'Монголын тэргүүлэгч банк',
    },
    {
      'name': 'State Bank',
      'mongolianName': 'Төрийн банк 3.0',
      'icon': Assets.state,
      'packageName': 'mn.statebank',
      'scheme': 'statebank://',
      'color': const Color(0xFF059669),
      'isInstalled': true,
      'description': 'Засгийн газрын банк',
    },
    {
      'name': 'Xac Bank',
      'mongolianName': 'Хас банк',
      'icon': Assets.xac,
      'packageName': 'mn.xac.bank',
      'scheme': 'xacbank://',
      'color': const Color(0xFFDC2626),
      'isInstalled': true,
      'description': 'Хас банкны апп',
    },
    {
      'name': 'TDB Bank',
      'mongolianName': 'TDB online',
      'icon': Assets.tdb,
      'packageName': 'mn.tdb.online',
      'scheme': 'tdbbank://',
      'color': const Color(0xFF7C2D12),
      'isInstalled': false,
      'description': 'Худалдааны хөгжлийн банк',
    },
    {
      'name': 'SocialPay',
      'mongolianName': 'Сошиал Пэй',
      'icon': Assets.socialpay,
      'packageName': 'mn.socialpay.app',
      'scheme': 'socialpay://',
      'color': const Color(0xFF7C3AED),
      'isInstalled': true,
      'description': 'Нийгмийн банкны апп',
    },
    {
      'name': 'Most Money',
      'mongolianName': 'МОСТ мони',
      'icon': Assets.mostmoney,
      'packageName': 'mn.most.money',
      'scheme': 'most://',
      'color': const Color(0xFFEA580C),
      'isInstalled': false,
      'description': 'МОСТ мани апп',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _listAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
    );

    _headerAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          ),
        );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _listController.forward();
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _headerController.dispose();
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
          // Modern App Bar
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
                  'Банк сонгох',
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
          ),

          // Content
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _headerAnimation,
              child: Column(
                children: [
                  // Payment Amount Card
                  _buildPaymentAmountCard(theme, colorScheme),

                  const SizedBox(height: 24),

                  // Banks List
                  FadeTransition(
                    opacity: _listAnimation,
                    child: _buildBanksList(theme, colorScheme),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAmountCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.secondaryLight,
            AppTheme.secondaryLight.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryLight.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Payment Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(height: 16),

          // Amount
          Text(
            'Төлөх дүн',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            MoneyFormatService.formatWithSymbol(widget.amount),
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

  Widget _buildBanksList(ThemeData theme, ColorScheme colorScheme) {
    final installedBanks = _banks
        .where((bank) => bank['isInstalled'] == true)
        .toList();
    final notInstalledBanks = _banks
        .where((bank) => bank['isInstalled'] != true)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Installed Banks Section
          if (installedBanks.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Суулгасан аппууд',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...installedBanks.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 200 + (entry.key * 100)),
                curve: Curves.easeOutCubic,
                child: _buildBankCard(entry.value, theme, true),
              );
            }),
            const SizedBox(height: 32),
          ],

          // Available Banks Section
          if (notInstalledBanks.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.download, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Боломжит аппууд',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...notInstalledBanks.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 400 + (entry.key * 100)),
                curve: Curves.easeOutCubic,
                child: _buildBankCard(entry.value, theme, false),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBankCard(
    Map<String, dynamic> bank,
    ThemeData theme,
    bool isInstalled,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectBank(bank),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isInstalled
                    ? (bank['color'] as Color).withOpacity(0.3)
                    : theme.colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isInstalled
                      ? (bank['color'] as Color).withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Bank Logo
                Hero(
                  tag: 'bank_${bank['name']}',
                  child: Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (bank['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (bank['color'] as Color).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Image.asset(
                      bank['icon'],
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.account_balance,
                          color: bank['color'],
                          size: 32,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Bank Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bank['mongolianName'] ?? bank['name'],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isInstalled
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isInstalled
                                      ? Icons.check_circle
                                      : Icons.download,
                                  color: isInstalled
                                      ? Colors.green
                                      : Colors.blue,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isInstalled ? 'Суулгасан' : 'Татах',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isInstalled
                                        ? Colors.green
                                        : Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        bank['description'] ?? 'Банкны мобайл апп',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Action Text
                      Text(
                        isInstalled ? 'Дарж төлөх' : 'Дарж татаж авах',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: bank['color'],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectBank(Map<String, dynamic> bank) {
    HapticFeedback.lightImpact();

    // Navigate to payment screen with selected bank
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PaymentScreen(initialAmount: widget.amount, selectedBank: bank),
      ),
    );
  }
}
