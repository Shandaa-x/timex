import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/money_format.dart';
import '../services/payment_service.dart';
import '../../../theme/app_theme.dart';
import '../../../config/qpay_config.dart';
import 'dart:async';

class PaginatedPaymentHistoryWidget extends StatefulWidget {
  const PaginatedPaymentHistoryWidget({super.key});

  @override
  State<PaginatedPaymentHistoryWidget> createState() =>
      _PaginatedPaymentHistoryWidgetState();
}

class _PaginatedPaymentHistoryWidgetState
    extends State<PaginatedPaymentHistoryWidget> {
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
    _realTimeSubscription = PaymentService.getPaymentHistoryStream(limit: 5)
        .listen(
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
                      .map(
                        (doc) => PaymentService.convertDocumentToPayment(doc),
                      )
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
            snapshot.docs
                .map((doc) => PaymentService.convertDocumentToPayment(doc))
                .toList(),
          );
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMoreData =
              snapshot.docs.length >=
              10; // If we got full page, there might be more
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
      final snapshot = await PaymentService.getNextPaymentHistoryPage(
        _lastDocument!,
      );

      if (mounted) {
        setState(() {
          _paymentHistory.addAll(
            snapshot.docs
                .map((doc) => PaymentService.convertDocumentToPayment(doc))
                .toList(),
          );
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMoreData =
              snapshot.docs.length >=
              10; // If we got full page, there might be more
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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isInitialLoading) {
      return _buildShimmerLoading();
    }

    if (_error != null) {
      return _buildErrorState(theme, colorScheme);
    }

    if (_paymentHistory.isEmpty) {
      return _buildEmptyState(theme, colorScheme);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surface, colorScheme.surface.withOpacity(0.8)],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: AppTheme.primaryLight,
        backgroundColor: Colors.white,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _paymentHistory.length + (_hasMoreData ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _paymentHistory.length) {
              return _buildLoadingIndicator();
            }

            final payment = _paymentHistory[index];
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 50)),
              curve: Curves.easeOutBack,
              child: _buildPaymentCard(payment),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[200]!,
                  Colors.grey[100]!,
                  Colors.grey[200]!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: _buildShimmerAnimation(),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerAnimation() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1500),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
          colors: [
            Colors.grey[200]!,
            Colors.white.withOpacity(0.8),
            Colors.grey[200]!,
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Алдаа гарлаа',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Дахин оролдох'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryLight.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryLight.withOpacity(0.1),
                    AppTheme.primaryLight.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 60,
                color: AppTheme.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Төлбөрийн түүх байхгүй байна',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Хоолоо идээд төлбөрөө хийсний дараа энд харагдах болно',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: _isLoading
          ? Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Илүү мэдээлэл ачаалж байна...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    // Safe data extraction with null checks
    final amount = (payment['amount'] as num?)?.toInt() ?? 0;
    // Use bank receiver name with safe fallback
    String bankReceiverName;
    try {
      bankReceiverName = QPayConfig.username.isNotEmpty
          ? QPayConfig.username
          : 'GRAND_IT';
    } catch (e) {
      // Fallback if QPayConfig is not initialized
      bankReceiverName = 'GRAND_IT';
    }

    // Parse date from various possible formats
    DateTime date;
    try {
      if (payment['createdAt'] is Timestamp) {
        date = (payment['createdAt'] as Timestamp).toDate();
      } else if (payment['date'] is Timestamp) {
        date = (payment['date'] as Timestamp).toDate();
      } else if (payment['date'] is String) {
        date = DateTime.parse(payment['date'] as String);
      } else {
        date = DateTime.now();
      }
    } catch (e) {
      date = DateTime.now();
    }

    // Use green colors as shown in the image
    final primaryColor = Colors.green[600]!;
    final backgroundColor = Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon section
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.restaurant, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankReceiverName, // Display bank receiver name with safe fallback
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFullDate(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Amount section
            Text(
              '-${MoneyFormatService.formatWithSymbol(amount)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
