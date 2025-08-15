import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_payment_models.dart';
import '../services/integrated_food_payment_service.dart';
import '../services/money_format.dart';
import 'food_payment_processor_widget.dart';

/// Widget that integrates food selection with QPay payment processing
class FoodPaymentIntegrationWidget extends StatefulWidget {
  final DateTime selectedMonth;
  
  const FoodPaymentIntegrationWidget({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<FoodPaymentIntegrationWidget> createState() => _FoodPaymentIntegrationWidgetState();
}

class _FoodPaymentIntegrationWidgetState extends State<FoodPaymentIntegrationWidget> {
  List<FoodItem> _allFoodItems = [];
  List<String> _selectedFoodIds = [];
  bool _isLoading = false;
  bool _isProcessingPayment = false;
  double _selectedTotalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  Future<void> _loadFoodItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load food items using integrated service
      final foodItems = await IntegratedFoodPaymentService.convertFirebaseFoodsToFoodItems(widget.selectedMonth);
      
      if (mounted) {
        setState(() {
          _allFoodItems = foodItems;
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
            content: Text('Error loading food items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFoodSelection(String foodId, double remainingBalance) {
    setState(() {
      if (_selectedFoodIds.contains(foodId)) {
        _selectedFoodIds.remove(foodId);
        _selectedTotalAmount -= remainingBalance;
      } else {
        _selectedFoodIds.add(foodId);
        _selectedTotalAmount += remainingBalance;
      }
      _selectedTotalAmount = _selectedTotalAmount.clamp(0.0, double.infinity);
    });
  }

  Future<void> _processPayment() async {
    if (_selectedFoodIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select food items to pay for'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Get selected food items
      final selectedFoods = _allFoodItems
          .where((food) => _selectedFoodIds.contains(food.id))
          .toList();

      // Get current user data
      final currentUser = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();

      final userData = userDoc.exists ? userDoc.data() : null;

      // Create QPay invoice using integrated service
      final result = await IntegratedFoodPaymentService.createFoodPaymentInvoice(
        selectedFoods,
        userData,
      );

      if (result.success) {
        if (mounted) {
          // Navigate to food payment processor instead of old payment screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FoodPaymentProcessorWidget(
                selectedFoodIds: _selectedFoodIds.toList(),
                onPaymentCompleted: (result) {
                  if (result.success) {
                    // Handle payment completion
                    _handlePaymentComplete({
                      'invoiceId': result.paymentTransaction?.invoiceId ?? '',
                      'transactionId': result.paymentTransaction?.id ?? '',
                      'amount': result.paymentTransaction?.totalAmount ?? 0.0,
                      'status': 'completed',
                    });
                  }
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating invoice: ${result.error ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  Future<void> _handlePaymentComplete(Map<String, dynamic> paymentResult) async {
    try {
      // Process payment completion using integrated service
      final invoiceId = paymentResult['invoiceId'] as String?;
      
      if (invoiceId != null) {
        final success = await IntegratedFoodPaymentService.processPaymentCompletion(
          invoiceId,
          paymentResult,
        );

        if (success && mounted) {
          // Clear selection and reload food items
          setState(() {
            _selectedFoodIds.clear();
            _selectedTotalAmount = 0.0;
          });
          
          await _loadFoodItems();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment completed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment completion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            Text('Loading food items...'),
          ],
        ),
      );
    }

    final unpaidFoods = _allFoodItems
        .where((food) => food.remainingBalance > 0)
        .toList();

    if (unpaidFoods.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All food items are fully paid!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Payment summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Food Items to Pay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected: ${_selectedFoodIds.length} items',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Total: ${MoneyFormatService.formatWithSymbol(_selectedTotalAmount.toInt())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Food items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unpaidFoods.length,
            itemBuilder: (context, index) {
              return _buildFoodSelectionCard(unpaidFoods[index]);
            },
          ),
        ),

        // Payment button
        if (_selectedFoodIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isProcessingPayment
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Processing Payment...'),
                      ],
                    )
                  : Text(
                      'Pay ${MoneyFormatService.formatWithSymbol(_selectedTotalAmount.toInt())} with QPay',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildFoodSelectionCard(FoodItem foodItem) {
    final isSelected = _selectedFoodIds.contains(foodItem.id);
    final hasPartialPayment = foodItem.paidAmount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleFoodSelection(foodItem.id, foodItem.remainingBalance),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green[50] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.green[300]! : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Selection checkbox
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green[600] : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? Colors.green[600]! : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
                
                const SizedBox(width: 12),
                
                // Food image placeholder
                Container(
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
                ),
                
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Price: ${MoneyFormatService.formatWithSymbol(foodItem.price.toInt())}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (hasPartialPayment) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Paid: ${MoneyFormatService.formatWithSymbol(foodItem.paidAmount.toInt())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Remaining amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasPartialPayment)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'PARTIAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      MoneyFormatService.formatWithSymbol(foodItem.remainingBalance.toInt()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.green[700] : Colors.red[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasPartialPayment ? 'Remaining' : 'Amount Due',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.green[600] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}