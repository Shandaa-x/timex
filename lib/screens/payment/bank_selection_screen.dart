import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/money_format.dart';
import '../../widgets/common_app_bar.dart';
import '../../services/qpay_helper_service.dart';
import '../../services/qpay_webhook_service.dart';
import '../../utils/qr_utils.dart';
import 'bank_payment_screen.dart';

class BankSelectionScreen extends StatefulWidget {
  final int paymentAmount;
  final String paymentMethod;

  const BankSelectionScreen({
    super.key,
    required this.paymentAmount,
    required this.paymentMethod,
  });

  @override
  State<BankSelectionScreen> createState() => _BankSelectionScreenState();
}

class _BankSelectionScreenState extends State<BankSelectionScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _qpayResult;

  static final List<Map<String, dynamic>> _banks = [
    {
      'name': 'Хаан банк',
      'icon': Icons.account_balance,
      'color': Colors.green,
      'package': 'com.khanbank.consumer',
    },
    {
      'name': 'Төрийн банк 3.0',
      'icon': Icons.account_balance,
      'color': Colors.blue,
      'package': 'mn.tdb.mobile',
    },
    {
      'name': 'Хас банк',
      'icon': Icons.account_balance,
      'color': Colors.orange,
      'package': 'mn.xacbank.xacmobile',
    },
    {
      'name': 'TDB online',
      'icon': Icons.account_balance,
      'color': Colors.cyan,
      'package': 'mn.tdb.online',
    },
    {
      'name': 'Голомт банк',
      'icon': Icons.account_balance,
      'color': Colors.lightBlue,
      'package': 'mn.golomt.consumer',
    },
    {
      'name': 'МОСТ мони',
      'icon': Icons.account_balance,
      'color': Colors.green[800]!,
      'package': 'mn.most.money',
    },
    {
      'name': 'Үндэсний хөрөнгө оруулалтын банк',
      'icon': Icons.account_balance,
      'color': Colors.brown,
      'package': 'mn.nic.mobile',
    },
    {
      'name': 'Чингис Хаан банк',
      'icon': Icons.account_balance,
      'color': Colors.purple,
      'package': 'mn.ckb.mobile',
    },
    {
      'name': 'Капитрон банк',
      'icon': Icons.account_balance,
      'color': Colors.red,
      'package': 'mn.capitron.mobile',
    },
    {
      'name': 'Богд банк',
      'icon': Icons.account_balance,
      'color': Colors.green[700]!,
      'package': 'mn.bogd.mobile',
    },
  ];

  void _navigateToBank(BuildContext context, Map<String, dynamic> bank) async {
    // Check if this is a QPay-enabled bank (Khan Bank for example)
    if (widget.paymentMethod == 'QPay' && bank['name'] == 'Хаан банк') {
      await _createQPayInvoiceAndLaunchApp(bank);
    } else {
      // For other banks or regular transfer, go to payment screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BankPaymentScreen(
            paymentAmount: widget.paymentAmount,
            paymentMethod: widget.paymentMethod,
            bankName: bank['name'],
            bankPackage: bank['package'],
            bankColor: bank['color'],
          ),
        ),
      );
    }
  }

  Future<void> _createQPayInvoiceAndLaunchApp(Map<String, dynamic> bank) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      final String userUid = currentUser?.uid ?? 'unknown';
      final String orderId = 'TIMEX_${DateTime.now().millisecondsSinceEpoch}';

      // Create QPay invoice
      final result = await QPayHelperService.createInvoiceWithQR(
        amount: widget.paymentAmount.toDouble(),
        orderId: orderId,
        userId: userUid,
        invoiceDescription: 'TIMEX Хоолны төлбөр - ₮${widget.paymentAmount}',
        callbackUrl: 'http://localhost:3000/qpay/webhook',
      );

      if (result['success'] == true) {
        final invoice = result['invoice'];
        setState(() {
          _qpayResult = invoice;
        });

        // Set payment status to pending in Firebase
        await QPayWebhookService.setPaymentStatusPending(userUid);

        // Launch Khan Bank app directly
        await _launchKhanBankApp(invoice, bank);

        // Show success message
        _showMessage(
          'QPay QR баригдлаа! ${bank['name']} апп нээгдэж байна...',
          isError: false,
        );
      } else {
        throw Exception(result['error'] ?? 'QPay QR үүсгэхэд алдаа гарлаа');
      }
    } catch (error) {
      print('Error creating QPay invoice: $error');
      _showMessage('Алдаа гарлаа: $error', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchKhanBankApp(Map<String, dynamic> qpayResult, Map<String, dynamic> bank) async {
    try {
      // Try to get the primary banking app from QPay result
      final primaryBankingApp = QRUtils.getPrimaryBankingApp(qpayResult);
      
      if (primaryBankingApp != null) {
        final uri = Uri.parse(primaryBankingApp.deepLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Fallback: Try to launch Khan Bank using QR text and package
      final qrText = qpayResult['qr_text'] ?? '';
      final invoiceId = qpayResult['invoice_id'];
      
      // Get QPay short URL
      String? qpayShortUrl;
      if (qpayResult['qpay_shortUrl'] != null) {
        qpayShortUrl = qpayResult['qpay_shortUrl'].toString();
      } else if (qpayResult['urls'] != null) {
        final urls = qpayResult['urls'];
        if (urls is List && urls.isNotEmpty) {
          for (final url in urls) {
            if (url is Map && url['link'] != null) {
              final link = url['link'].toString();
              if (link.startsWith('http')) {
                qpayShortUrl = link;
                break;
              }
            }
          }
        }
      }

      // Generate deep link for Khan Bank
      final deepLink = QRUtils.getPrimaryDeepLink(qrText, qpayShortUrl, invoiceId);
      
      if (deepLink != null) {
        final uri = Uri.parse(deepLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('${bank['name']} апп олдсонгүй');
        }
      } else {
        throw Exception('QPay холбоос үүсгэхэд алдаа гарлаа');
      }
    } catch (error) {
      print('Error launching Khan Bank app: $error');
      _showMessage('${bank['name']} апп нээхэд алдаа гарлаа: $error', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(
        title: 'Хэтэвч цэнэглэх',
        variant: AppBarVariant.standard,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Payment Summary Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
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
                Row(
                  children: [
                    Icon(
                      widget.paymentMethod == 'QPay' ? Icons.qr_code : Icons.account_balance,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.paymentMethod,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Төлөх дүн: ${MoneyFormatService.formatWithSymbol(widget.paymentAmount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          
          // Bank Selection Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Банк сонгох',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Та төлбөр төлөхийг хүсэж буй банкаа сонгоно уу',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bank List
          Expanded(
            child: _isLoading 
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'QPay QR үүсгэж байна...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _banks.length,                  itemBuilder: (context, index) {
                    final bank = _banks[index];
                    final isKhanBankQPay = widget.paymentMethod == 'QPay' && bank['name'] == 'Хаан банк';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: isKhanBankQPay ? 4 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isKhanBankQPay 
                            ? const BorderSide(color: Colors.blue, width: 2)
                            : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: () => _navigateToBank(context, bank),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: isKhanBankQPay 
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue.withOpacity(0.05),
                                      Colors.blue.withOpacity(0.1),
                                    ],
                                  ),
                                )
                              : null,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: bank['color'].withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isKhanBankQPay ? Icons.qr_code_scanner : bank['icon'],
                                    color: bank['color'],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bank['name'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isKhanBankQPay ? Colors.blue[800] : const Color(0xFF1F2937),
                                        ),
                                      ),
                                      if (isKhanBankQPay) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'QPay QR ашиглан төлөх',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  isKhanBankQPay ? Icons.qr_code : Icons.arrow_forward_ios,
                                  color: isKhanBankQPay ? Colors.blue : Colors.grey[400],
                                  size: isKhanBankQPay ? 20 : 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
