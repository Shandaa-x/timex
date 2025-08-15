import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/food_payment_models.dart';
import '../services/individual_food_payment_service.dart';
import '../services/money_format.dart';

/// Widget that displays individual food items with their payment status
class IndividualFoodPaymentWidget extends StatefulWidget {
  final FoodPaymentStatus? statusFilter;
  final bool showPaymentSummary;

  const IndividualFoodPaymentWidget({
    super.key,
    this.statusFilter,
    this.showPaymentSummary = true,
  });

  @override
  State<IndividualFoodPaymentWidget> createState() => _IndividualFoodPaymentWidgetState();
}

class _IndividualFoodPaymentWidgetState extends State<IndividualFoodPaymentWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<FoodItem> _foodItems = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  PaymentSummary? _paymentSummary;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    if (widget.showPaymentSummary) {
      _loadPaymentSummary();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final foodItems = await IndividualFoodPaymentService.getFoodItems(
        limit: 20,
        statusFilter: widget.statusFilter,
      );

      if (mounted) {
        setState(() {
          _foodItems.clear();
          _foodItems.addAll(foodItems);
          _hasMoreData = foodItems.length >= 20;
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

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData || _foodItems.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastDocument = _foodItems.last;
      // Note: In a real implementation, you'd need to pass the DocumentSnapshot
      // For now, we'll just load more items
      final moreFoodItems = await IndividualFoodPaymentService.getFoodItems(
        limit: 20,
        statusFilter: widget.statusFilter,
      );

      if (mounted) {
        setState(() {
          _foodItems.addAll(moreFoodItems);
          _hasMoreData = moreFoodItems.length >= 20;
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

  Future<void> _loadPaymentSummary() async {
    try {
      final summary = await IndividualFoodPaymentService.getPaymentSummary();
      if (mounted) {
        setState(() {
          _paymentSummary = summary;
        });
      }
    } catch (e) {
      // Handle error silently
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
    return RefreshIndicator(
      onRefresh: () async {
        await _loadInitialData();
        if (widget.showPaymentSummary) {
          await _loadPaymentSummary();
        }
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Payment Summary
          if (widget.showPaymentSummary && _paymentSummary != null)
            SliverToBoxAdapter(
              child: _buildPaymentSummary(_paymentSummary!),
            ),
          
          // Food Items List
          if (_foodItems.isEmpty && !_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No food items found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _foodItems.length) {
                    return _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }
                  
                  return _buildFoodItemCard(_foodItems[index]);
                },
                childCount: _foodItems.length + (_hasMoreData ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(PaymentSummary summary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Progress', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('${(summary.paymentProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: summary.paymentProgress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Summary Stats
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Value',
                  MoneyFormatService.formatWithSymbol(summary.totalFoodValue.toInt()),
                  Colors.blue[700]!,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Paid Amount',
                  MoneyFormatService.formatWithSymbol(summary.totalPaidAmount.toInt()),
                  Colors.green[700]!,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Remaining',
                  MoneyFormatService.formatWithSymbol(summary.totalRemainingBalance.toInt()),
                  Colors.red[700]!,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Total Items',
                  '${summary.totalFoodCount}',
                  Colors.grey[700]!,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Status counts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusCount('Unpaid', summary.unpaidCount, Colors.red),
              _buildStatusCount('Partial', summary.partiallyPaidCount, Colors.orange),
              _buildStatusCount('Paid', summary.fullyPaidCount, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCount(String label, int count, MaterialColor color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color[300]!),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color[700],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFoodItemCard(FoodItem foodItem) {
    // Determine colors based on payment status
    Color cardColor;
    Color statusColor;
    Color progressColor;

    switch (foodItem.status) {
      case FoodPaymentStatus.unpaid:
        cardColor = Colors.red[50]!;
        statusColor = Colors.red[600]!;
        progressColor = Colors.red[400]!;
        break;
      case FoodPaymentStatus.partiallyPaid:
        cardColor = Colors.orange[50]!;
        statusColor = Colors.orange[600]!;
        progressColor = Colors.orange[400]!;
        break;
      case FoodPaymentStatus.fullyPaid:
        cardColor = Colors.green[50]!;
        statusColor = Colors.green[600]!;
        progressColor = Colors.green[400]!;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with image, name, and status
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
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${foodItem.id}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  foodItem.status.statusBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
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
                    '${(foodItem.paymentProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: foodItem.paymentProgress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Payment amounts
          Row(
            children: [
              Expanded(
                child: _buildAmountItem(
                  'Price',
                  MoneyFormatService.formatWithSymbol(foodItem.price.toInt()),
                  Colors.blue[600]!,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  'Paid',
                  MoneyFormatService.formatWithSymbol(foodItem.paidAmount.toInt()),
                  Colors.green[600]!,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  'Remaining',
                  MoneyFormatService.formatWithSymbol(foodItem.remainingBalance.toInt()),
                  Colors.red[600]!,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Selected date and payment history count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected: ${_formatDate(foodItem.selectedDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (foodItem.paymentHistory.isNotEmpty)
                Text(
                  '${foodItem.paymentHistory.length} payment(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
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
        if (imageBase64.contains('data:image/') && imageBase64.contains(';base64,')) {
          base64String = imageBase64.split(',').last;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(base64String),
            width: 50,
            height: 50,
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.restaurant,
        color: Colors.grey[600],
        size: 24,
      ),
    );
  }

  Widget _buildAmountItem(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}