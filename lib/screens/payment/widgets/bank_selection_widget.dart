import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/money_format.dart';
import '../../../theme/app_theme.dart';

class BankSelectionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  final int amount;
  final Function(Map<String, dynamic>) onBankSelected;
  final String? selectedBankId;

  const BankSelectionWidget({
    super.key,
    required this.banks,
    required this.amount,
    required this.onBankSelected,
    this.selectedBankId,
  });

  @override
  State<BankSelectionWidget> createState() => _BankSelectionWidgetState();
}

class _BankSelectionWidgetState extends State<BankSelectionWidget>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _staggerController = AnimationController(
      duration: Duration(milliseconds: 800 + (widget.banks.length * 100)),
      vsync: this,
    );

    _slideAnimations = List.generate(
      widget.banks.length,
      (index) =>
          Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _staggerController,
              curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutCubic),
            ),
          ),
    );

    _fadeAnimations = List.generate(
      widget.banks.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(index * 0.1, 1.0, curve: Curves.easeInOut),
        ),
      ),
    );

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.banks.isEmpty) {
      return _buildEmptyState(theme, colorScheme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount Display
        _buildAmountCard(theme, colorScheme),

        const SizedBox(height: 24),

        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Банк сонгох',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Banks List
        ...widget.banks.asMap().entries.map((entry) {
          final index = entry.key;
          final bank = entry.value;

          return SlideTransition(
            position: _slideAnimations[index],
            child: FadeTransition(
              opacity: _fadeAnimations[index],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: _buildBankCard(bank, theme, index),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAmountCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryLight,
            AppTheme.primaryLight.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
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
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Төлөх дүн',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MoneyFormatService.formatWithSymbol(widget.amount),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCard(Map<String, dynamic> bank, ThemeData theme, int index) {
    final isSelected = widget.selectedBankId == bank['packageName'];
    final isInstalled = bank['isInstalled'] ?? false;
    final bankColor = _getBankColor(bank['name']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onBankSelected(bank);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? bankColor.withOpacity(0.1)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? bankColor
                    : theme.colorScheme.outline.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? bankColor.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Bank Logo Container
                Hero(
                  tag: 'bank_logo_${bank['packageName']}_$index',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: bankColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bankColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: bank['icon'] != null
                        ? Image.asset(
                            bank['icon'],
                            width: 32,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              _getBankIcon(bank['name']),
                              color: bankColor,
                              size: 32,
                            ),
                          )
                        : Icon(
                            _getBankIcon(bank['name']),
                            color: bankColor,
                            size: 32,
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
                              bank['mongolianName'] ??
                                  bank['name'] ??
                                  'Unknown Bank',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? bankColor
                                    : theme.colorScheme.onSurface,
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
                                  ? AppTheme.successLight.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isInstalled
                                    ? AppTheme.successLight.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isInstalled
                                      ? Icons.check_circle
                                      : Icons.download_rounded,
                                  color: isInstalled
                                      ? AppTheme.successLight
                                      : Colors.orange,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isInstalled ? 'Суулгасан' : 'Татах',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isInstalled
                                        ? AppTheme.successLight
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        isInstalled
                            ? 'Шууд төлбөр төлөх боломжтой'
                            : 'Татаж авснаар төлбөр төлөх боломжтой',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Quick Action Text
                      Text(
                        isInstalled ? '👆 Дарж төлөх' : '👆 Дарж татах',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: bankColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Selection Indicator & Arrow
                Column(
                  children: [
                    if (isSelected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: bankColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Банкны апп олдсонгүй',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Банкны мобайл апп суулгаж төлбөр төлөх боломжтой',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getBankColor(String? bankName) {
    switch (bankName?.toLowerCase()) {
      case 'khan bank':
        return const Color(0xFF1E3A8A);
      case 'state bank':
        return const Color(0xFF059669);
      case 'xac bank':
        return const Color(0xFFDC2626);
      case 'tdb bank':
        return const Color(0xFF7C2D12);
      case 'socialpay':
        return const Color(0xFF7C3AED);
      case 'most money':
        return const Color(0xFFEA580C);
      case 'trade bank':
        return const Color(0xFF0F766E);
      case 'chinggis khaan bank':
        return const Color(0xFF7C2D12);
      case 'capitron bank':
        return const Color(0xFF4338CA);
      case 'bogd bank':
        return const Color(0xFF059669);
      case 'arig bank':
        return const Color(0xFFDC2626);
      case 'trans bank':
        return const Color(0xFF7C3AED);
      default:
        return AppTheme.primaryLight;
    }
  }

  IconData _getBankIcon(String? bankName) {
    switch (bankName?.toLowerCase()) {
      case 'khan bank':
        return Icons.account_balance;
      case 'state bank':
        return Icons.account_balance_wallet;
      case 'xac bank':
        return Icons.savings;
      case 'tdb bank':
        return Icons.business;
      case 'socialpay':
        return Icons.payment;
      case 'most money':
        return Icons.monetization_on;
      default:
        return Icons.account_balance;
    }
  }
}
