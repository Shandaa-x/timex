import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/screens/home/widgets/custom_sliver_appbar.dart';
import 'dart:async';
import '../../widgets/custom_drawer.dart';
import '../../services/money_format.dart';
import '../payment/payment_screen.dart';
import 'tabview/daily_tab_screen.dart';
import 'tabview/history_tab_screen.dart';
import 'services/food_data_service.dart';
import 'services/payment_service.dart';
import 'services/food_calculation_service.dart';

class FoodReportScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const FoodReportScreen({super.key, this.onNavigateToTab});

  @override
  State<FoodReportScreen> createState() => _FoodReportScreenState();
}

class _FoodReportScreenState extends State<FoodReportScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _monthlyFoodData = {};
  Map<String, int> _foodStats = {};
  Map<String, bool> _eatenForDayData = {}; // Track which days food was eaten
  Map<String, bool> _paidMeals = {}; // Track which individual meals are paid for

  // User statistics from totalFoodAmount
  double _paymentBalance = 0.0;
  double _totalPaymentAmount = 0.0;
  bool _userStatsLoading = true;
  StreamSubscription<DocumentSnapshot>? _userStatsSubscription;

  // Filtering
  String? _selectedFoodFilter;

  // Tab controller
  late TabController _tabController;

  // Helper to get current user ID
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Add listener to rebuild when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadMonthlyFoodData();
    _loadUserSettings();
    _loadUserStatistics();
  }

  Future<void> _loadUserStatistics() async {
    try {
      setState(() => _userStatsLoading = true);

      // Cancel any existing subscription
      _userStatsSubscription?.cancel();

      // Listen to real-time changes in the user's document
      _userStatsSubscription = _firestore
          .collection('users')
          .doc(_userId)
          .snapshots()
          .listen((userDoc) {
            if (userDoc.exists && mounted) {
              final userData = userDoc.data();

              // Get totalFoodAmount (total consumed) from the user's document
              final dynamic rawTotalFoodAmount = userData?['totalFoodAmount'] ?? 0.0;
              final double totalFoodConsumed = rawTotalFoodAmount is String 
                  ? double.tryParse(rawTotalFoodAmount) ?? 0.0 
                  : (rawTotalFoodAmount as num).toDouble();

              // Get payment status
              final String qpayStatus = userData?['qpayStatus'] ?? 'none';

              setState(() {
                _totalPaymentAmount = totalFoodConsumed; // Show totalFoodAmount as "Amount to Pay"
                _paymentBalance = totalFoodConsumed; // Show remaining balance
                _userStatsLoading = false;
              });

              debugPrint(
                '✅ Real-time user statistics: totalFoodAmount=$totalFoodConsumed, status=$qpayStatus',
              );
            }
          });
    } catch (e) {
      debugPrint('❌ Error setting up user statistics listener: $e');
      setState(() => _userStatsLoading = false);
    }
  }

  Future<void> _loadMonthlyFoodData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _monthlyFoodData.clear();
      _foodStats.clear();
      _eatenForDayData.clear();
      _paidMeals.clear();


      // Load all data using services
      final results = await Future.wait([
        FoodDataService.loadEatenForDayData(_selectedMonth, _userId),
        PaymentService.loadMealPaymentStatus(_selectedMonth),
        FoodDataService.loadFoodDataForMonth(_selectedMonth),
      ]);

      _eatenForDayData = results[0] as Map<String, bool>;
      _paidMeals = results[1] as Map<String, bool>;
      _monthlyFoodData = results[2] as Map<String, List<Map<String, dynamic>>>;

      // Calculate food statistics
      _foodStats = FoodDataService.calculateFoodStats(_monthlyFoodData);
    } catch (e) {
      print('Error loading monthly food data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _updateFoodFilter(); // Update available filter options
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load user settings (for future use)
  Future<void> _loadUserSettings() async {
    try {
      // For now, using default values - in real app, load from SharedPreferences
      // Budget feature removed - no longer needed
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  // Mark individual meal as paid using service
  Future<void> _markMealAsPaid(
    String dateKey,
    int foodIndex,
    Map<String, dynamic> food,
  ) async {
    final mealKey = '${dateKey}_$foodIndex';
    final success = await PaymentService.saveMealPaymentStatus(
      _selectedMonth,
      mealKey,
      true,
    );

    if (success) {
      setState(() {
        _paidMeals[mealKey] = true;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${FoodDataService.getFoodName(food)} payment completed',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mark all unpaid meals for the month as paid
  Future<void> _payMonthly() async {
    if (_unpaidFoodData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No meals to pay for'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Calculate total amount
    final totalAmount = _unpaidTotalAmount;
    final totalFoods = _unpaidFoodData.values.fold<int>(
      0,
      (sum, foods) => sum + foods.length,
    );

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pay Monthly Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total monthly bill: ${MoneyFormatService.formatWithSymbol(totalAmount)}',
              ),
              const SizedBox(height: 8),
              Text('Total meals: $totalFoods'),
              const SizedBox(height: 16),
              const Text('Do you want to pay for all meals this month?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Mark all unpaid meals as paid
      final futures = <Future>[];

      for (final dateEntry in _unpaidFoodData.entries) {
        final dateKey = dateEntry.key;
        final foods = dateEntry.value;

        for (int i = 0; i < foods.length; i++) {
          final food = foods[i];
          final foodIndex = FoodDataService.getFoodIndex(food);
          final mealKey = '${dateKey}_$foodIndex';

          futures.add(
            PaymentService.saveMealPaymentStatus(_selectedMonth, mealKey, true),
          );
        }
      }

      // Wait for all payments to complete
      final results = await Future.wait(futures);
      final allSuccessful = results.every((success) => success);

      if (allSuccessful) {
        // Update local state
        setState(() {
          for (final dateEntry in _unpaidFoodData.entries) {
            final dateKey = dateEntry.key;
            final foods = dateEntry.value;

            for (int i = 0; i < foods.length; i++) {
              final food = foods[i];
              final foodIndex = FoodDataService.getFoodIndex(food);
              final mealKey = '${dateKey}_$foodIndex';
              _paidMeals[mealKey] = true;
            }
          }
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Monthly payment successful! ${MoneyFormatService.formatWithSymbol(totalAmount)}',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error processing payment. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error paying monthly: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update food filtering using service
  void _updateFoodFilter() {
    // Food filtering functionality removed as it's not currently used
  }

  // Get only unpaid meals data using service
  Map<String, List<Map<String, dynamic>>> get _unpaidFoodData =>
      FoodCalculationService.getUnpaidFoodData(
        _monthlyFoodData,
        _eatenForDayData,
        _paidMeals,
        _selectedFoodFilter,
      );

  // Get unpaid meals total using service
  int get _unpaidTotalAmount =>
      FoodCalculationService.calculateUnpaidTotalAmount(_unpaidFoodData);

  // Check if any foods exist in the selected month
  bool get _hasAnyFoodsInMonth => _monthlyFoodData.isNotEmpty;

  Widget _buildTabbedBreakdownSection() {
    return Column(
      children: [
        // Tab bar
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(2),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 14),
                    SizedBox(width: 6),
                    Text('Food List'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 14),
                    SizedBox(width: 6),
                    Text('Payment History'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate a reasonable height based on screen size
            final screenHeight = MediaQuery.of(context).size.height;
            final availableHeight = screenHeight * 0.6; // Use 60% of screen height

            return SizedBox(
              height: availableHeight,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Daily Breakdown
                  DailyTabScreen(
                    unpaidFoodData: _unpaidFoodData,
                    selectedFoodFilter: _selectedFoodFilter,
                    onMarkMealAsPaid: _markMealAsPaid,
                    onPayMonthly: _payMonthly,
                    hasAnyFoodsInMonth: _hasAnyFoodsInMonth,
                  ),
                  // Tab 2: History
                  const HistoryTabScreen(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadMonthlyFoodData(), _loadUserStatistics()]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        onNavigateToTab: widget.onNavigateToTab,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                const CustomSliverAppBar(
                  title: 'Хоолны тайлан',
                  gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Food Statistics Card
                      if (_userStatsLoading)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.restaurant_menu,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Food Expenses',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Amount to Pay',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          MoneyFormatService.formatWithSymbol(
                                            _totalPaymentAmount.round(),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Balance',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          MoneyFormatService.formatWithSymbol(
                                            _paymentBalance.round(),
                                          ),
                                          style: TextStyle(
                                            color: _paymentBalance >= 0
                                                ? Colors.white
                                                : Colors.red[200],
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Make Payment Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _totalPaymentAmount > 0 ? () {
                                    // Navigate to payment screen with the total amount
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PaymentScreen(
                                          initialAmount: _totalPaymentAmount.round(),
                                        ),
                                      ),
                                    );
                                  } : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF10B981),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.payment, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Make Payment',
                                        style: TextStyle(
                                          fontSize: 16,
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
                      const SizedBox(height: 15),
                      _buildTabbedBreakdownSection(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userStatsSubscription?.cancel();
    super.dispose();
  }
}