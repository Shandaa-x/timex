import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timex/index.dart';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  final int mockPrice = 500; // Mock price 500 MNT
  bool _isLoading = false;
  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  void _generateQRCode() {
    setState(() {
      _isLoading = true;
    });

    // Simulate QPay invoice generation
    // In real implementation, this would call QPay API
    Future.delayed(const Duration(seconds: 1), () {
      final mockInvoiceData = {
        'amount': mockPrice,
        'currency': 'MNT',
        'merchant': 'TimEx App',
        'invoice_id': 'INV-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Convert to QR data string
      _qrData = 'qpay://invoice?amount=$mockPrice&currency=MNT&merchant=TimEx&id=${mockInvoiceData['invoice_id']}';

      setState(() {
        _isLoading = false;
      });
    });
  }

  void _refreshQRCode() {
    _generateQRCode();
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
          onPressed: () => Navigator.pop(context),
        ),
        title: txt(
          'QPay Төлбөр',
          style: TxtStl.bodyText1(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshQRCode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Price display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3f3f3f),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        txt(
                          'Төлөх дүн',
                          style: TxtStl.bodyText1(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        txt(
                          '₮${mockPrice.toString()}',
                          style: TxtStl.bodyText1(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // QR Code container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        txt(
                          'QPay QR код',
                          style: TxtStl.bodyText1(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // QR Code
                        if (_qrData.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        txt(
                          'QR кодыг QPay аппликейшнаар уншуулна уу',
                          style: TxtStl.bodyText1(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            txt(
                              'Төлбөрийн заавар',
                              style: TxtStl.bodyText1(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        txt(
                          '1. QPay аппликейшн нээнэ үү\n'
                          '2. QR код уншигч сонгоно уу\n'
                          '3. Дээрх QR кодыг уншуулна уу\n'
                          '4. Төлбөрөө баталгаажуулна уу',
                          style: TxtStl.bodyText1(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Test button for development
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Төлбөр амжилттай хийгдлээ! (Тест)'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: txt(
                        'Төлбөр амжилттай (Тест)',
                        style: TxtStl.bodyText1(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
