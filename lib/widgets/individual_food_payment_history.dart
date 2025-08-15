import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_payment_models.dart';
import '../services/integrated_food_payment_service.dart';
import '../services/money_format.dart';
import 'dart:async';

/// Individual food payment history widget
/// Shows each food item with its payment status, remaining balance, and payment history
class IndividualFoodPaymentHistory extends StatefulWidget {
  const IndividualFoodPaymentHistory({super.key});

  @override
  State<IndividualFoodPaymentHistory> createState() => _IndividualFoodPaymentHistoryState();
}

class _IndividualFoodPaymentHistoryState extends State<IndividualFoodPaymentHistory> {
  List<FoodItem> _foodItems = [];
  bool _isLoading = false;
  final DateTime _selectedMonth = DateTime.now();
  StreamSubscription<List<FoodItem>>? _foodItemsSubscription;
  PaymentSummary? _paymentSummary;

  @override
  void initState() {
    super.initState();
    _setupRealTimeData();
    _loadPaymentSummary();
  }

  @override
  void dispose() {
    _foodItemsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeData() {
    setState(() {
      _isLoading = true;
    });

    // Listen to real-time food items stream
    _foodItemsSubscription = IntegratedFoodPaymentService
        .getFoodItemsStream(_selectedMonth)
        .listen(
          (foodItems) {
            if (mounted) {
              setState(() {
                _foodItems = foodItems;
                _isLoading = false;
              });
              _loadPaymentSummary();
            }
          },
          onError: (error) async {
            // If no data exists, sync from existing Firebase structure
            await _syncExistingData();
          },
        );
  }

  Future<void> _syncExistingData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Sync existing Firebase food data to new structure
      await IntegratedFoodPaymentService.syncExistingFoodData(_selectedMonth);
      
      // If still no data, create sample data
      final foodItems = await IntegratedFoodPaymentService.convertFirebaseFoodsToFoodItems(_selectedMonth);
      
      if (foodItems.isEmpty) {
        await _createAndLoadSampleData();
      }
    } catch (e) {
      // Fallback to sample data
      await _createAndLoadSampleData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPaymentSummary() async {
    try {
      final summary = await IntegratedFoodPaymentService.getPaymentSummary(_selectedMonth);
      if (mounted) {
        setState(() {
          _paymentSummary = summary;
        });
      }
    } catch (e) {
      // Error loading summary
    }
  }

  Future<void> _createAndLoadSampleData() async {
    // Create sample food items with different payment statuses
    final sampleFoods = [
      FoodItem(
        id: 'demo_burger_001',
        name: 'Classic Beef Burger',
        price: 15000,
        selectedDate: DateTime.now().subtract(const Duration(hours: 3)),
        paidAmount: 15000, // Fully paid
        paymentHistory: [
          FoodPaymentRecord(
            id: 'payment_001',
            amount: 15000,
            paymentDate: DateTime.now().subtract(const Duration(hours: 2)),
            method: 'qpay',
            transactionId: 'txn_001',
            invoiceId: 'inv_001',
          ),
        ],
      ),
      FoodItem(
        id: 'demo_pizza_002',
        name: 'Margherita Pizza',
        price: 25000,
        selectedDate: DateTime.now().subtract(const Duration(hours: 2)),
        paidAmount: 10000, // Partially paid
        paymentHistory: [
          FoodPaymentRecord(
            id: 'payment_002',
            amount: 10000,
            paymentDate: DateTime.now().subtract(const Duration(hours: 1)),
            method: 'qpay',
            transactionId: 'txn_002',
            invoiceId: 'inv_002',
          ),
        ],
      ),
      FoodItem(
        id: 'demo_salad_003',
        name: 'Caesar Salad',
        price: 8000,
        selectedDate: DateTime.now().subtract(const Duration(hours: 1)),
        paidAmount: 0, // Unpaid
        paymentHistory: [],
      ),
      FoodItem(
        id: 'demo_cake_004',
        name: 'Chocolate Cake',
        price: 6000,
        selectedDate: DateTime.now().subtract(const Duration(minutes: 30)),
        paidAmount: 3000, // Partially paid
        paymentHistory: [
          FoodPaymentRecord(
            id: 'payment_003',
            amount: 3000,
            paymentDate: DateTime.now().subtract(const Duration(minutes: 15)),
            method: 'qpay',
            transactionId: 'txn_003',
            invoiceId: 'inv_003',
          ),
        ],
      ),
      FoodItem(
        id: 'demo_drink_005',
        name: 'Fresh Orange Juice',
        price: 4000,
        selectedDate: DateTime.now().subtract(const Duration(minutes: 15)),
        paidAmount: 4000, // Fully paid
        paymentHistory: [
          FoodPaymentRecord(
            id: 'payment_004',
            amount: 4000,
            paymentDate: DateTime.now().subtract(const Duration(minutes: 10)),
            method: 'qpay',
            transactionId: 'txn_004',
            invoiceId: 'inv_004',
          ),
        ],
      ),
    ];

    // Save sample foods to Firebase using integrated service
    try {
      // Convert to the new integrated structure and save
      final batch = FirebaseFirestore.instance.batch();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo_user';
      
      for (final food in sampleFoods) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('foods')
            .doc(food.id);
        batch.set(ref, food.toMap());
      }
      
      await batch.commit();
      
      // The stream will automatically update the UI
    } catch (e) {
      // If save fails, just show the sample data locally
      setState(() {
        _foodItems = sampleFoods;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading food payment history...'),
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
              'No food items available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _syncExistingData();
                if (_foodItems.isEmpty) {
                  await _createAndLoadSampleData();
                }
              },
              child: const Text('Load Sample Data'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _syncExistingData();
        await _loadPaymentSummary();
      },
      child: Column(
        children: [
          // Payment Summary
          if (_paymentSummary != null)
            _buildPaymentSummary(_paymentSummary!),
          
          // Food Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _foodItems.length,
              itemBuilder: (context, index) {
                return _buildFoodCard(_foodItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(FoodItem food) {
    // Determine colors based on payment status
    Color cardColor;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (food.status) {
      case FoodPaymentStatus.fullyPaid:
        cardColor = Colors.green[50]!;
        statusColor = Colors.green[600]!;
        statusIcon = Icons.check_circle;
        statusText = 'FULLY PAID';
        break;
      case FoodPaymentStatus.partiallyPaid:
        cardColor = Colors.orange[50]!;
        statusColor = Colors.orange[600]!;
        statusIcon = Icons.schedule;
        statusText = 'PARTIALLY PAID';
        break;
      case FoodPaymentStatus.unpaid:
        cardColor = Colors.red[50]!;
        statusColor = Colors.red[600]!;
        statusIcon = Icons.pending;
        statusText = 'UNPAID';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
          // Header with food info and status
          Row(
            children: [
              // Food image placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.restaurant,
                  color: Colors.grey[600],
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              
              // Food details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${food.id}',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment amounts section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Price and paid amounts
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountColumn(
                        'Price',
                        MoneyFormatService.formatWithSymbol(food.price.toInt()),
                        Colors.blue[600]!,
                      ),
                    ),
                    Expanded(
                      child: _buildAmountColumn(
                        'Paid',
                        MoneyFormatService.formatWithSymbol(food.paidAmount.toInt()),
                        Colors.green[600]!,
                      ),
                    ),
                    Expanded(
                      child: _buildAmountColumn(
                        'Remaining',
                        MoneyFormatService.formatWithSymbol(food.remainingBalance.toInt()),
                        food.remainingBalance > 0 ? Colors.red[600]! : Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Progress',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${(food.paymentProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: food.paymentProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Payment history
          if (food.paymentHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Payment History (${food.paymentHistory.length} transactions)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...food.paymentHistory.map((payment) => _buildPaymentRecord(payment)),
          ],

          // Selection date
          const SizedBox(height: 12),
          Text(
            'Selected: ${_formatDate(food.selectedDate)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
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

  Widget _buildPaymentRecord(FoodPaymentRecord payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
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
              payment.method == 'qpay' ? Icons.qr_code : Icons.payment,
              size: 12,
              color: Colors.blue[600],
            ),
          ),
          const SizedBox(width: 8),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      MoneyFormatService.formatWithSymbol(payment.amount.toInt()),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      payment.method.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(payment.paymentDate),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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

  Widget _buildPaymentSummary(PaymentSummary summary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                'Food Payment Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Summary stats
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
          
          // Progress bar
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
}