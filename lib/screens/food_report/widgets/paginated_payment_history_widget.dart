import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/money_format.dart';
import '../services/payment_service.dart';
import 'dart:async';

class PaginatedPaymentHistoryWidget extends StatefulWidget {
  const PaginatedPaymentHistoryWidget({super.key});

  @override
  State<PaginatedPaymentHistoryWidget> createState() => _PaginatedPaymentHistoryWidgetState();
}

class _PaginatedPaymentHistoryWidgetState extends State<PaginatedPaymentHistoryWidget> {
  final List<Map<String, dynamic>> _paymentHistory = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _isInitialLoading = true;
  DocumentSnapshot? _lastDocument;
  String? _error;
  StreamSubscription<QuerySnapshot>? _realTimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _setupRealTimeListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _realTimeSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeListener() {
    // Set up real-time listener for new payments
    _realTimeSubscription = PaymentService.getPaymentHistoryStream(limit: 5).listen(
      (snapshot) {
        if (!_isInitialLoading && mounted) {
          // Check for new documents
          final newDocs = snapshot.docChanges
              .where((change) => change.type == DocumentChangeType.added)
              .map((change) => change.doc)
              .toList();

          if (newDocs.isNotEmpty) {
            setState(() {
              // Add new payments to the beginning of the list
              final newPayments = newDocs
                  .map((doc) => PaymentService.convertDocumentToPayment(doc))
                  .toList();
              _paymentHistory.insertAll(0, newPayments);
            });
          }
        }
      },
      onError: (error) {
        print('Real-time listener error: $error');
      },
    );
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
    });

    try {
      final snapshot = await PaymentService.getInitialPaymentHistory();
      
      if (mounted) {
        setState(() {
          _paymentHistory.clear();
          _paymentHistory.addAll(
            snapshot.docs.map((doc) => PaymentService.convertDocumentToPayment(doc)).toList(),
          );
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMoreData = snapshot.docs.length >= 10; // If we got full page, there might be more
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await PaymentService.getNextPaymentHistoryPage(_lastDocument!);
      
      if (mounted) {
        setState(() {
          _paymentHistory.addAll(
            snapshot.docs.map((doc) => PaymentService.convertDocumentToPayment(doc)).toList(),
          );
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMoreData = snapshot.docs.length >= 10; // If we got full page, there might be more
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Өгөгдөл ачаалахад алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Алдаа гарлаа',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      );
    }

    if (_paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Төлбөрийн түүх байхгүй байна',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _paymentHistory.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _paymentHistory.length) {
            // Loading indicator at the bottom
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            );
          }

          final payment = _paymentHistory[index];
          return _buildPaymentCard(payment);
        },
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final amount = payment['amount'] as num? ?? 0;
    final type = payment['type'] as String? ?? 'payment';
    final description = payment['description'] as String? ?? '';
    final status = payment['status'] as String? ?? 'completed';
    final paymentMethod = payment['paymentMethod'] as String? ?? 'unknown';
    
    // Parse date from various possible formats
    DateTime date;
    try {
      if (payment['timestamp'] is Timestamp) {
        date = (payment['timestamp'] as Timestamp).toDate();
      } else if (payment['date'] is String) {
        date = DateTime.parse(payment['date'] as String);
      } else {
        date = DateTime.now();
      }
    } catch (e) {
      date = DateTime.now();
    }

    // Determine card color and icon based on type and status
    Color cardColor;
    Color iconColor;
    IconData icon;
    String title;

    switch (type.toLowerCase()) {
      case 'payment':
        cardColor = Colors.red[50]!;
        iconColor = Colors.red[600]!;
        icon = Icons.payment;
        title = 'Төлбөр төлөгдлөө';
        break;
      case 'topup':
      case 'deposit':
        cardColor = Colors.green[50]!;
        iconColor = Colors.green[600]!;
        icon = Icons.account_balance_wallet;
        title = 'Данс цэнэглэгдлээ';
        break;
      case 'refund':
        cardColor = Colors.blue[50]!;
        iconColor = Colors.blue[600]!;
        icon = Icons.replay;
        title = 'Буцаан олголт';
        break;
      default:
        cardColor = Colors.grey[50]!;
        iconColor = Colors.grey[600]!;
        icon = Icons.account_balance_wallet;
        title = type;
    }

    if (status != 'completed') {
      cardColor = Colors.orange[50]!;
      iconColor = Colors.orange[600]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${type == 'payment' ? '-' : '+'}${MoneyFormatService.formatWithSymbol(amount.toInt())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: type == 'payment' ? Colors.red[600] : Colors.green[600],
                    ),
                  ),
                  if (status != 'completed') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (paymentMethod != 'unknown')
                Text(
                  paymentMethod,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          if (payment['transactionId'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'ID: ${payment['transactionId']}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
