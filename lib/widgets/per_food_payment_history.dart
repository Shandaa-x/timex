import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/food_payment_models.dart';
import '../services/individual_food_payment_service.dart';
import '../services/money_format.dart';

/// Widget that displays payment history per individual food item
class PerFoodPaymentHistory extends StatefulWidget {
  const PerFoodPaymentHistory({super.key});

  @override
  State<PerFoodPaymentHistory> createState() => _PerFoodPaymentHistoryState();
}

class _PerFoodPaymentHistoryState extends State<PerFoodPaymentHistory> {
  final ScrollController _scrollController = ScrollController();
  final List<FoodItem> _foodItems = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _error;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get food items with payment history, sorted by last payment date
      final foodItems = await IndividualFoodPaymentService.getFoodItems(
        limit: 20,
      );

      // Filter to show only foods that have payment history
      final foodsWithPayments = foodItems
          .where((food) => food.hasPayment || food.paymentHistory.isNotEmpty)
          .toList();

      // Sort by latest payment date
      foodsWithPayments.sort((a, b) {
        final aLastPayment = a.paymentHistory.isNotEmpty
            ? a.paymentHistory.last.paymentDate
            : a.selectedDate;
        final bLastPayment = b.paymentHistory.isNotEmpty
            ? b.paymentHistory.last.paymentDate
            : b.selectedDate;
        return bLastPayment.compareTo(aLastPayment);
      });

      if (mounted) {
        setState(() {
          _foodItems.clear();
          _foodItems.addAll(foodsWithPayments);
          _hasMoreData = foodsWithPayments.length >= 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final moreFoodItems = await IndividualFoodPaymentService.getFoodItems(
        limit: 20,
        lastDocument: _lastDocument,
      );

      final foodsWithPayments = moreFoodItems
          .where((food) => food.hasPayment || food.paymentHistory.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _foodItems.addAll(foodsWithPayments);
          _hasMoreData = foodsWithPayments.length >= 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _foodItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _foodItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Payment History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_foodItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No food items found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add some food items to see them here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                _loadInitialData();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _foodItems.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _foodItems.length) {
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            );
          }

          return _buildFoodPaymentCard(_foodItems[index]);
        },
      ),
    );
  }

  Widget _buildFoodPaymentCard(FoodItem foodItem) {
    // Determine card styling based on payment status
    Color cardColor;
    Color statusColor;
    Color borderColor;
    IconData statusIcon;

    switch (foodItem.status) {
      case FoodPaymentStatus.fullyPaid:
        cardColor = Colors.green[50]!;
        statusColor = Colors.green[600]!;
        borderColor = Colors.green[200]!;
        statusIcon = Icons.check_circle;
        break;
      case FoodPaymentStatus.partiallyPaid:
        cardColor = Colors.orange[50]!;
        statusColor = Colors.orange[600]!;
        borderColor = Colors.orange[200]!;
        statusIcon = Icons.schedule;
        break;
      case FoodPaymentStatus.unpaid:
        cardColor = Colors.red[50]!;
        statusColor = Colors.red[600]!;
        borderColor = Colors.red[200]!;
        statusIcon = Icons.pending;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Food image, name, and status
          Row(
            children: [
              // Food image
              _buildFoodImage(foodItem.imageBase64),
              const SizedBox(width: 12),

              // Food details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodItem.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Food ID: ${foodItem.id}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Selected: ${_formatDate(foodItem.selectedDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Status indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${(foodItem.paymentProgress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: foodItem.paymentProgress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment details
          Row(
            children: [
              Expanded(
                child: _buildPaymentDetail(
                  'Price',
                  MoneyFormatService.formatWithSymbol(foodItem.price.toInt()),
                  Colors.blue[600]!,
                ),
              ),
              Expanded(
                child: _buildPaymentDetail(
                  'Paid',
                  MoneyFormatService.formatWithSymbol(
                    foodItem.paidAmount.toInt(),
                  ),
                  Colors.green[600]!,
                ),
              ),
              Expanded(
                child: _buildPaymentDetail(
                  'Remaining',
                  MoneyFormatService.formatWithSymbol(
                    foodItem.remainingBalance.toInt(),
                  ),
                  Colors.red[600]!,
                ),
              ),
            ],
          ),

          // Show payment history if available
          if (foodItem.paymentHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Payment History (${foodItem.paymentHistory.length} payments)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...foodItem.paymentHistory.map(
              (payment) => _buildPaymentHistoryItem(payment),
            ),
          ],

          // Status badge
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                foodItem.status.statusBadge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodImage(String? imageBase64) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        // Handle both data URL format and direct base64
        String base64String = imageBase64;
        if (imageBase64.contains('data:image/') &&
            imageBase64.contains(';base64,')) {
          base64String = imageBase64.split(',').last;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(base64String),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderImage();
            },
          ),
        );
      } catch (e) {
        return _buildPlaceholderImage();
      }
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey[600], size: 28),
    );
  }

  Widget _buildPaymentDetail(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistoryItem(FoodPaymentRecord payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Payment method icon
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              payment.method.toLowerCase() == 'qpay'
                  ? Icons.qr_code
                  : Icons.payment,
              size: 16,
              color: Colors.blue[600],
            ),
          ),
          const SizedBox(width: 8),

          // Payment details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      MoneyFormatService.formatWithSymbol(
                        payment.amount.toInt(),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      payment.method.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateTime(payment.paymentDate),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (payment.transactionId != null)
                      Text(
                        'TX: ${payment.transactionId!.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
