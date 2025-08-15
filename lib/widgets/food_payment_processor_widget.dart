import 'package:flutter/material.dart';
import '../models/food_payment_models.dart';
import '../services/food_payment_service.dart';
import '../services/money_format.dart';

/// Widget for processing payments for selected food items
class FoodPaymentProcessorWidget extends StatefulWidget {
  final List<String> selectedFoodIds;
  final Function(PaymentResult)? onPaymentCompleted;

  const FoodPaymentProcessorWidget({
    super.key,
    required this.selectedFoodIds,
    this.onPaymentCompleted,
  });

  @override
  State<FoodPaymentProcessorWidget> createState() =>
      _FoodPaymentProcessorWidgetState();
}

class _FoodPaymentProcessorWidgetState
    extends State<FoodPaymentProcessorWidget> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _invoiceIdController = TextEditingController();
  List<FoodItem> _selectedFoods = [];
  String _selectedMethod = 'qpay';
  bool _isLoading = true;
  bool _isProcessing = false;
  double _totalNeeded = 0.0;
  double _enteredAmount = 0.0;

  final List<String> _paymentMethods = [
    'qpay',
    'card',
    'cash',
    'bank_transfer',
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedFoods();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _invoiceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedFoods() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allFoods = await FoodPaymentService.getAllFoodItems();
      final selectedFoods = allFoods
          .where((food) => widget.selectedFoodIds.contains(food.id))
          .toList();

      final totalNeeded = selectedFoods.fold<double>(
        0.0,
        (sum, food) => sum + food.remainingBalance,
      );

      setState(() {
        _selectedFoods = selectedFoods;
        _totalNeeded = totalNeeded;
        _amountController.text = totalNeeded.toStringAsFixed(0);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ Error loading selected foods: $e');
    }
  }

  void _onAmountChanged() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _enteredAmount = amount;
    });
  }

  Future<void> _processPayment() async {
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await FoodPaymentService.processPayment(
        foodIds: widget.selectedFoodIds,
        paymentAmount: _enteredAmount,
        method: _selectedMethod,
        invoiceId: _invoiceIdController.text.trim().isNotEmpty
            ? _invoiceIdController.text.trim()
            : null,
      );

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );

        // Notify parent widget
        if (widget.onPaymentCompleted != null) {
          widget.onPaymentCompleted!(result);
        }

        // Close the payment processor
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Payment'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment summary card
            _buildPaymentSummaryCard(),

            const SizedBox(height: 16),

            // Selected foods list
            _buildSelectedFoodsList(),

            const SizedBox(height: 16),

            // Payment amount input
            _buildPaymentAmountSection(),

            const SizedBox(height: 16),

            // Payment method selection
            _buildPaymentMethodSection(),

            const SizedBox(height: 16),

            // Invoice ID input
            _buildInvoiceIdSection(),

            const SizedBox(height: 24),

            // Payment distribution preview
            _buildPaymentDistributionPreview(),

            const SizedBox(height: 24),

            // Process payment button
            _buildProcessPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'Payment Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Items:',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  '${_selectedFoods.length} foods',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Needed:',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  MoneyFormatService.formatWithSymbol(_totalNeeded.toInt()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFoodsList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Foods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._selectedFoods.map(
              (food) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(food.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      MoneyFormatService.formatWithSymbol(
                        food.remainingBalance.toInt(),
                      ),
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAmountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Amount',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter payment amount',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: '₮',
                helperText:
                    'Total needed: ${MoneyFormatService.formatWithSymbol(_totalNeeded.toInt())}',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    _amountController.text = _totalNeeded.toStringAsFixed(0);
                  },
                  child: const Text('Pay Full Amount'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _amountController.text = (_totalNeeded / 2).toStringAsFixed(
                      0,
                    );
                  },
                  child: const Text('Pay Half'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _paymentMethods
                  .map(
                    (method) => ChoiceChip(
                      label: Text(_getMethodDisplayName(method)),
                      selected: _selectedMethod == method,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedMethod = method;
                          });
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceIdSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice ID (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invoiceIdController,
              decoration: const InputDecoration(
                labelText: 'Invoice ID',
                hintText: 'Enter invoice ID if available',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDistributionPreview() {
    if (_enteredAmount <= 0) return const SizedBox.shrink();

    // Calculate payment distribution
    final distribution = _calculatePaymentDistribution(_enteredAmount);

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text(
                  'Payment Distribution Preview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...distribution.entries.map((entry) {
              final food = _selectedFoods.firstWhere((f) => f.id == entry.key);
              final amount = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      MoneyFormatService.formatWithSymbol(amount.toInt()),
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (distribution.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Payment:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    MoneyFormatService.formatWithSymbol(_enteredAmount.toInt()),
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessPaymentButton() {
    final isValidAmount = _enteredAmount > 0;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isValidAmount && !_isProcessing ? _processPayment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        child: _isProcessing
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Processing Payment...'),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payment),
                  const SizedBox(width: 8),
                  Text(
                    'Process Payment (${MoneyFormatService.formatWithSymbol(_enteredAmount.toInt())})',
                  ),
                ],
              ),
      ),
    );
  }

  Map<String, double> _calculatePaymentDistribution(double paymentAmount) {
    final distribution = <String, double>{};
    double remainingAmount = paymentAmount;

    // Sort foods by selection date (oldest first)
    final sortedFoods = List<FoodItem>.from(_selectedFoods)
      ..sort((a, b) => a.selectedDate.compareTo(b.selectedDate));

    for (final food in sortedFoods) {
      if (remainingAmount <= 0) break;

      final amountNeeded = food.remainingBalance;
      if (amountNeeded > 0) {
        final amountToPay = remainingAmount >= amountNeeded
            ? amountNeeded
            : remainingAmount;
        distribution[food.id] = amountToPay;
        remainingAmount -= amountToPay;
      }
    }

    return distribution;
  }

  Color _getStatusColor(FoodPaymentStatus status) {
    switch (status) {
      case FoodPaymentStatus.unpaid:
        return Colors.red;
      case FoodPaymentStatus.partiallyPaid:
        return Colors.orange;
      case FoodPaymentStatus.fullyPaid:
        return Colors.green;
    }
  }

  String _getMethodDisplayName(String method) {
    switch (method) {
      case 'qpay':
        return 'QPay';
      case 'card':
        return 'Card';
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method.toUpperCase();
    }
  }
}
