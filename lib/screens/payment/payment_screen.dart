import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/common_app_bar.dart';
import '../../services/money_format.dart';
import '../../utils/banking_app_checker.dart';
import '../../utils/qr_utils.dart';
import '../../services/qpay_helper_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentScreen extends StatefulWidget {
  final int? initialAmount;

  const PaymentScreen({super.key, this.initialAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  int _enteredAmount = 0;
  bool _isCreatingInvoice = false;
  Map<String, dynamic>? qpayResult;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount.toString();
      _enteredAmount = widget.initialAmount!;
    }
  }

  void _onAmountChanged(String value) {
    setState(() {
      _enteredAmount = int.tryParse(value) ?? 0;
    });
  }

  Future<void> _showBankOptions() async {
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create QPay invoice first
    await _createQPayInvoice();
  }

  Future<void> _createQPayInvoice() async {
    setState(() {
      _isCreatingInvoice = true;
      errorMessage = null;
      qpayResult = null;
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
        callbackUrl: 'http://localhost:3000/qpay/webhook',
      );

      if (result['success'] == true) {
        final invoice = result['invoice'];
        setState(() {
          qpayResult = invoice;
          _isCreatingInvoice = false;
        });

        // Show banking app options
        _showBankingAppOptions();
      } else {
        throw Exception(result['error'] ?? 'Failed to create QPay invoice');
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Failed to create payment: $error';
        _isCreatingInvoice = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    }
  }

  /// Show available banking app options using QR screen logic
  void _showBankingAppOptions() async {
    if (qpayResult == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final qrText = qpayResult!['qr_text'] ?? '';
      final invoiceId = qpayResult!['invoice_id'];

      // Use optimized banking app detection from QR screen
      final optimizedLinks = await BankingAppChecker.getOptimizedDeepLinks(
        qrText,
        invoiceId,
      );

      // Get traditional banking apps from QPay response
      final bankingApps = QRUtils.extractBankingApps(qpayResult!);

      Navigator.pop(context); // Close loading dialog

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Banking App',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Amount: ${MoneyFormatService.formatWithSymbol(_enteredAmount)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Show optimized banking apps first
                  if (optimizedLinks.isNotEmpty) ...[
                    Text(
                      'Available Banking Apps:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...optimizedLinks.entries.map((entry) {
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _getBankIcon(entry.key),
                            color: Colors.green,
                            size: 32,
                          ),
                          title: Text(
                            entry.key,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Tap to open and pay ${MoneyFormatService.formatWithSymbol(_enteredAmount)}',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () async {
                            Navigator.pop(context);
                            await _launchBankingApp(entry.value, entry.key);
                          },
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 16),
                  ],

                  // SocialPay option
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: Icon(Icons.people, color: Colors.blue, size: 32),
                      title: Text(
                        'SocialPay',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Khan Bank SocialPay - Pay ${MoneyFormatService.formatWithSymbol(_enteredAmount)}',
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () async {
                        Navigator.pop(context);
                        await _openSocialPay();
                      },
                    ),
                  ),

                  // Banking apps from QPay response
                  if (bankingApps.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'QPay Suggested Apps:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...bankingApps.entries.map((entry) {
                      final app = entry.value;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _getBankIcon(app.name),
                            color: Colors.blue,
                            size: 32,
                          ),
                          title: Text(
                            app.name,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Pay ${MoneyFormatService.formatWithSymbol(_enteredAmount)}',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () async {
                            Navigator.pop(context);
                            await _launchBankingApp(app.deepLink, app.name);
                          },
                        ),
                      );
                    }).toList(),
                  ],

                  SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load banking apps: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Open SocialPay with deep link
  Future<void> _openSocialPay() async {
    if (qpayResult == null) {
      _showMessage('No invoice available', isError: true);
      return;
    }

    try {
      final qrText = qpayResult!['qr_text'] ?? '';
      final invoiceId = qpayResult!['invoice_id'] ?? '';

      // Try to get SocialPay deep link using banking app checker
      String? socialPayLink;
      if (qrText.isNotEmpty) {
        // Create simple SocialPay deep link
        socialPayLink = 'socialpay://payment?qr=$qrText&invoice=$invoiceId';
      }

      if (socialPayLink != null && socialPayLink.isNotEmpty) {
        final uri = Uri.parse(socialPayLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showMessage('Opened SocialPay', isError: false);
        } else {
          _showMessage('SocialPay app not installed', isError: true);
        }
      } else {
        _showMessage('SocialPay link not available', isError: true);
      }
    } catch (error) {
      _showMessage('Failed to open SocialPay: $error', isError: true);
    }
  }

  Future<void> _launchBankingApp(String deepLink, String appName) async {
    try {
      final uri = Uri.parse(deepLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showMessage('Opened $appName', isError: false);
      } else {
        _showMessage('$appName not installed', isError: true);
      }
    } catch (error) {
      _showMessage('Invalid link format for $appName', isError: true);
    }
  }

  IconData _getBankIcon(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'khan bank':
      case 'khanbank':
        return Icons.account_balance;
      case 'qpay wallet':
      case 'qpay':
        return Icons.payment;
      case 'social pay':
      case 'socialpay':
        return Icons.people;
      case 'state bank':
      case 'statebank':
        return Icons.account_balance_wallet;
      case 'tdb bank':
      case 'tdbbank':
        return Icons.business;
      case 'xac bank':
      case 'xacbank':
        return Icons.monetization_on;
      case 'most money':
      case 'mostmoney':
        return Icons.money;
      default:
        return Icons.open_in_new;
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(
        title: 'Make Payment',
        variant: AppBarVariant.standard,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Input Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payment, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Enter Payment Amount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter amount (e.g. 10000)',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: Icon(
                          Icons.currency_exchange,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      onChanged: _onAmountChanged,
                    ),
                  ),
                  if (_enteredAmount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Amount: ${MoneyFormatService.formatWithSymbol(_enteredAmount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enteredAmount > 0 && !_isCreatingInvoice
                          ? _showBankOptions
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF10B981),
                        disabledBackgroundColor: Colors.white.withOpacity(0.3),
                        disabledForegroundColor: Colors.white.withOpacity(0.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isCreatingInvoice
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF10B981),
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Show Payment Options',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Error message display
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }
}
