import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/money_format.dart';
import '../../widgets/common_app_bar.dart';

class BankPaymentScreen extends StatefulWidget {
  final int paymentAmount;
  final String paymentMethod;
  final String bankName;
  final String bankPackage;
  final Color bankColor;

  const BankPaymentScreen({
    super.key,
    required this.paymentAmount,
    required this.paymentMethod,
    required this.bankName,
    required this.bankPackage,
    required this.bankColor,
  });

  @override
  State<BankPaymentScreen> createState() => _BankPaymentScreenState();
}

class _BankPaymentScreenState extends State<BankPaymentScreen> {
  bool _isProcessing = false;
  bool _paymentCompleted = false;

  // Account details for transfer (example)
  final String _accountNumber = "5000000001";
  final String _accountName = "TIMEX СИСТЕМИЙН ДАНС";
  final String _transferDescription = "Хоолны төлбөр";

  Future<void> _launchBankApp() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Try to launch the bank app
      final Uri bankUri = Uri.parse('${widget.bankPackage}://transfer');
      
      if (await canLaunchUrl(bankUri)) {
        await launchUrl(
          bankUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // If can't launch app, show manual transfer instructions
        _showManualTransferDialog();
      }
    } catch (e) {
      // Show manual transfer instructions if app launch fails
      _showManualTransferDialog();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showManualTransferDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${widget.bankName} апп нээх боломжгүй'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Доорх мэдээллийг ашиглан гараар шилжүүлнэ үү:'),
            const SizedBox(height: 16),
            _buildTransferInfo(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Буцах'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markAsCompleted();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.bankColor,
            ),
            child: const Text('Төлбөр төлсөн', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _markAsCompleted() {
    setState(() {
      _paymentCompleted = true;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Төлбөр амжилттай төлөгдлөө! ${MoneyFormatService.formatWithSymbol(widget.paymentAmount)}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    // Navigate back to main screen after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label хуулагдлаа'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildTransferInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Дансны дугаар:', _accountNumber, () {
            _copyToClipboard(_accountNumber, 'Дансны дугаар');
          }),
          const SizedBox(height: 12),
          _buildInfoRow('Данс эзэмшигч:', _accountName, () {
            _copyToClipboard(_accountName, 'Данс эзэмшигч');
          }),
          const SizedBox(height: 12),
          _buildInfoRow('Дүн:', MoneyFormatService.formatWithSymbol(widget.paymentAmount), () {
            _copyToClipboard(widget.paymentAmount.toString(), 'Дүн');
          }),
          const SizedBox(height: 12),
          _buildInfoRow('Гүйлгээний утга:', _transferDescription, () {
            _copyToClipboard(_transferDescription, 'Гүйлгээний утга');
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, VoidCallback onCopy) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: widget.bankName,
        variant: AppBarVariant.standard,
        backgroundColor: Colors.white,
      ),
      body: _paymentCompleted ? _buildSuccessView() : _buildPaymentView(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Төлбөр амжилттай!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            MoneyFormatService.formatWithSymbol(widget.paymentAmount),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Үндсэн хуудас руу шилжиж байна...',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.bankColor.withOpacity(0.8),
                  widget.bankColor,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.bankColor.withOpacity(0.3),
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
                    Expanded(
                      child: Text(
                        '${widget.bankName} - ${widget.paymentMethod}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Төлөх дүн',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MoneyFormatService.formatWithSymbol(widget.paymentAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Transfer Information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Шилжүүлгийн мэдээлэл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTransferInfo(),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Action Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _launchBankApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.bankColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '${widget.bankName} апп нээх',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _markAsCompleted,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.bankColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Төлбөр төлсөн гэж тэмдэглэх',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.bankColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
