import 'package:flutter/material.dart';
import 'package:timex/index.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  final int totalPrice = 1000; // Total price 1000 MNT
  final Map<String, int> products = {
    'Steak': 500,
    'Soup': 500,
  };
  
  String qrData = '';

  @override
  void initState() {
    super.initState();
    _generateQPayInvoice();
  }

  void _generateQPayInvoice() {
    // Generate mock QPay QR invoice data
    // Format based on QPay documentation research
    String invoiceNo = DateTime.now().millisecondsSinceEpoch.toString();
    String merchantCode = 'TIMEX001';
    String description = products.entries
        .map((e) => '${e.key} (₮${e.value})')
        .join(', ');
    
    // Mock QPay QR format (simplified for testing)
    qrData = 'qpay://invoice?'
        'merchant=$merchantCode&'
        'invoice=$invoiceNo&'
        'amount=$totalPrice&'
        'currency=MNT&'
        'description=${Uri.encodeComponent(description)}';
    
    setState(() {});
  }

  void _refreshQRCode() {
    _generateQPayInvoice();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 20),
            
            // QPay Logo/Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: txt(
                'QPay Invoice',
                style: TxtStl.bodyText1(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // QR Code
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: qrData.isNotEmpty
                  ? QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    )
                  : const CircularProgressIndicator(),
            ),
            
            SizedBox(height: 30),
            
            // Invoice Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(
                    'Invoice Details',
                    style: TxtStl.bodyText1(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 15),
                  
                  // Products
                  ...products.entries.map((product) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        txt(
                          product.key,
                          style: TxtStl.bodyText1(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        txt(
                          '₮${product.value}',
                          style: TxtStl.bodyText1(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  )),
                  
                  Divider(color: Colors.grey.shade400, thickness: 1),
                  
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      txt(
                        'Total Amount',
                        style: TxtStl.bodyText1(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      txt(
                        '₮$totalPrice',
                        style: TxtStl.bodyText1(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  SizedBox(width: 10),
                  Expanded(
                    child: txt(
                      'Scan with your bank app to pay',
                      style: TxtStl.bodyText1(
                        fontSize: 14,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
