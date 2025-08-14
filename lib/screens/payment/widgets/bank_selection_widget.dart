import 'package:flutter/material.dart';
import '../../../services/money_format.dart';

class BankSelectionWidget extends StatelessWidget {
  final List<Map<String, dynamic>> banks;
  final int amount;
  final Function(Map<String, dynamic>) onBankSelected;

  const BankSelectionWidget({
    super.key,
    required this.banks,
    required this.amount,
    required this.onBankSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (banks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Column(
          children: [
            Icon(Icons.account_balance, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No Payment Apps Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please install a banking app to make payments',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Amount to pay: ${MoneyFormatService.formatWithSymbol(amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: banks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final bank = banks[index];
            return _buildBankCard(context, bank);
          },
        ),
      ],
    );
  }

  Widget _buildBankCard(BuildContext context, Map<String, dynamic> bank) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onBankSelected(bank),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Bank Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getBankColor(bank['name']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getBankIcon(bank['name']),
                  color: _getBankColor(bank['name']),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Bank Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank['name'] ?? 'Unknown Bank',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bank['isInstalled'] == true
                          ? 'App installed - Tap to pay'
                          : 'Available for payment',
                      style: TextStyle(
                        fontSize: 12,
                        color: bank['isInstalled'] == true
                            ? Colors.green[600]
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bank['isInstalled'] == true
                      ? Colors.green[100]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bank['isInstalled'] == true ? 'Ready' : 'Available',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: bank['isInstalled'] == true
                        ? Colors.green[700]
                        : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBankColor(String? bankName) {
    switch (bankName?.toLowerCase()) {
      case 'khan bank':
        return const Color(0xFF1E3A8A);
      case 'state bank':
        return const Color(0xFF059669);
      case 'tdb bank':
        return const Color(0xFFDC2626);
      case 'socialpay':
        return const Color(0xFF7C3AED);
      case 'qpay':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getBankIcon(String? bankName) {
    switch (bankName?.toLowerCase()) {
      case 'khan bank':
        return Icons.account_balance;
      case 'state bank':
        return Icons.account_balance_wallet;
      case 'tdb bank':
        return Icons.savings;
      case 'socialpay':
        return Icons.payment;
      case 'qpay':
        return Icons.qr_code;
      default:
        return Icons.account_balance;
    }
  }
}
