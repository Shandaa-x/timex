import 'package:flutter/material.dart';
import '../models/food_payment_models.dart';
import '../services/food_payment_service.dart';
import '../services/money_format.dart';
import '../widgets/food_payment_history_widget.dart';
import '../widgets/food_selection_widget.dart';
import '../widgets/food_payment_processor_widget.dart';

/// Main screen for managing food payments and viewing history
class FoodManagementScreen extends StatefulWidget {
  const FoodManagementScreen({super.key});

  @override
  State<FoodManagementScreen> createState() => _FoodManagementScreenState();
}

class _FoodManagementScreenState extends State<FoodManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedFoodIds = {};
  int _totalUnpaidCount = 0;
  double _totalUnpaidAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPaymentSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentSummary() async {
    try {
      final foods = await FoodPaymentService.getAllFoodItems();
      final unpaidFoods = foods
          .where((food) => food.status != FoodPaymentStatus.fullyPaid)
          .toList();

      final totalAmount = unpaidFoods.fold<double>(
        0.0,
        (sum, food) => sum + food.remainingBalance,
      );

      setState(() {
        _totalUnpaidCount = unpaidFoods.length;
        _totalUnpaidAmount = totalAmount;
      });
    } catch (e) {
      print('❌ Error loading payment summary: $e');
    }
  }

  void _onFoodSelectionChanged(Set<String> selectedIds) {
    setState(() {
      _selectedFoodIds.clear();
      _selectedFoodIds.addAll(selectedIds);
    });
  }

  void _showAddFoodDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: FoodSelectionWidget(
            onFoodAdded: (FoodItem food) {
              Navigator.of(context).pop();
              _loadPaymentSummary();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${food.name} successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPaymentProcessor() {
    if (_selectedFoodIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one food item to pay for'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodPaymentProcessorWidget(
          selectedFoodIds: _selectedFoodIds.toList(),
          onPaymentCompleted: (PaymentResult result) {
            _loadPaymentSummary();
            setState(() {
              _selectedFoodIds.clear();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Management'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'My Foods'),
            Tab(icon: Icon(Icons.history), text: 'Payment History'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAddFoodDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add New Food',
          ),
          if (_selectedFoodIds.isNotEmpty)
            IconButton(
              onPressed: _showPaymentProcessor,
              icon: const Icon(Icons.payment),
              tooltip: 'Process Payment',
            ),
        ],
      ),
      body: Column(
        children: [
          // Payment summary banner
          _buildPaymentSummaryBanner(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // My Foods tab
                FoodPaymentHistoryWidget(
                  onSelectionChanged: _onFoodSelectionChanged,
                  showSelectionMode: true,
                ),

                // Payment History tab
                const FoodPaymentHistoryWidget(showSelectionMode: false),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedFoodIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showPaymentProcessor,
              backgroundColor: Colors.green[600],
              icon: const Icon(Icons.payment, color: Colors.white),
              label: Text(
                'Pay for ${_selectedFoodIds.length} items',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : FloatingActionButton(
              onPressed: _showAddFoodDialog,
              backgroundColor: Colors.blue[600],
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildPaymentSummaryBanner() {
    if (_totalUnpaidCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          border: Border(bottom: BorderSide(color: Colors.green[200]!)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 12),
            const Text(
              'All payments up to date! 🎉',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border(bottom: BorderSide(color: Colors.orange[200]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_totalUnpaidCount unpaid food items',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Total amount: ${MoneyFormatService.formatWithSymbol(_totalUnpaidAmount.toInt())}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          if (_totalUnpaidCount > 0)
            TextButton(
              onPressed: () {
                _tabController.animateTo(0);
              },
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }
}

/// Payment statistics widget for dashboard
class PaymentStatsWidget extends StatelessWidget {
  const PaymentStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodItem>>(
      stream: FoodPaymentService.getFoodItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final foods = snapshot.data ?? [];
        final unpaidFoods = foods
            .where((f) => f.status == FoodPaymentStatus.unpaid)
            .length;
        final partiallyPaidFoods = foods
            .where((f) => f.status == FoodPaymentStatus.partiallyPaid)
            .length;
        final paidFoods = foods
            .where((f) => f.status == FoodPaymentStatus.fullyPaid)
            .length;

        final totalUnpaidAmount = foods
            .where((f) => f.status != FoodPaymentStatus.fullyPaid)
            .fold<double>(0.0, (sum, f) => sum + f.remainingBalance);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    const Text(
                      'Payment Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status counts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Unpaid',
                      unpaidFoods.toString(),
                      Colors.red,
                      Icons.cancel,
                    ),
                    _buildStatItem(
                      'Partial',
                      partiallyPaidFoods.toString(),
                      Colors.orange,
                      Icons.pending,
                    ),
                    _buildStatItem(
                      'Paid',
                      paidFoods.toString(),
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Total amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding Balance:',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    Text(
                      MoneyFormatService.formatWithSymbol(
                        totalUnpaidAmount.toInt(),
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: totalUnpaidAmount > 0
                            ? Colors.red[600]
                            : Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
