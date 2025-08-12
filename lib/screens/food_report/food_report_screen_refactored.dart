import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/month_navigation_widget.dart';
import 'widgets/summary_section_widget.dart';
import 'widgets/food_frequency_section_widget.dart';
import 'widgets/daily_breakdown_section_widget.dart';
import 'widgets/payment_history_section_widget.dart';
import 'widgets/filter_bottom_sheet_widget.dart';
import 'services/food_data_service.dart';
import 'services/payment_service.dart';
import 'services/food_calculation_service.dart';
import 'services/month_navigation_service.dart';

class FoodReportScreen extends StatefulWidget {
  const FoodReportScreen({super.key});

  @override
  State<FoodReportScreen> createState() => _FoodReportScreenState();
}

class _FoodReportScreenState extends State<FoodReportScreen> {
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _monthlyFoodData = {};
  Map<String, int> _foodStats = {};
  Map<String, bool> _eatenForDayData = {}; // Track which days food was eaten
  Map<String, bool> _paidMeals = {}; // Track which individual meals are paid for

  // Balance and budget tracking
  List<Map<String, dynamic>> _paymentHistory = [];

  // Filtering
  String? _selectedFoodFilter;
  List<String> _availableFoodTypes = [];

  @override
  void initState() {
    super.initState();
    _loadMonthlyFoodData();
    _loadUserSettings();
    _loadPaymentHistory();
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
        FoodDataService.loadEatenForDayData(_selectedMonth),
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
            content: Text('Өгөгдөл ачаалахад алдаа гарлаа: $e'),
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

  // Load payment history from service
  Future<void> _loadPaymentHistory() async {
    try {
      _paymentHistory = await PaymentService.loadPaymentHistory(_selectedMonth);
    } catch (e) {
      print('Error loading payment history: $e');
      _paymentHistory = [];
    }
  }

  void _navigatePreviousMonth() {
    setState(() {
      _selectedMonth = MonthNavigationService.navigateToPreviousMonth(_selectedMonth);
      _selectedFoodFilter = null; // Clear filter when changing month
    });
    _loadMonthlyFoodData();
    _loadPaymentHistory();
  }

  void _navigateNextMonth() {
    setState(() {
      _selectedMonth = MonthNavigationService.navigateToNextMonth(_selectedMonth);
      _selectedFoodFilter = null; // Clear filter when changing month
    });
    _loadMonthlyFoodData();
    _loadPaymentHistory();
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
  Future<void> _markMealAsPaid(String dateKey, int foodIndex, Map<String, dynamic> food) async {
    final mealKey = '${dateKey}_$foodIndex';
    final success = await PaymentService.saveMealPaymentStatus(_selectedMonth, mealKey, true);
    
    if (success) {
      setState(() {
        _paidMeals[mealKey] = true;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${FoodDataService.getFoodName(food)} төлбөр төлөгдлөө'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update food filtering using service
  void _updateFoodFilter() {
    _availableFoodTypes = FoodDataService.getAvailableFoodTypes(_monthlyFoodData);
  }

  // Get filtered food data using service
  Map<String, List<Map<String, dynamic>>> get _filteredFoodData => 
    FoodCalculationService.getFilteredFoodData(_monthlyFoodData, _eatenForDayData, _selectedFoodFilter);

  // Get only unpaid meals data using service
  Map<String, List<Map<String, dynamic>>> get _unpaidFoodData => 
    FoodCalculationService.getUnpaidFoodData(_monthlyFoodData, _eatenForDayData, _paidMeals, _selectedFoodFilter);

  // Get unpaid meals total using service
  int get _unpaidTotalAmount => FoodCalculationService.calculateUnpaidTotalAmount(_unpaidFoodData);

  // Get paid meals total using service
  int get _paidTotalAmount => FoodCalculationService.calculatePaidTotalAmount(_filteredFoodData, _paidMeals);

  // Get unpaid food stats for frequency chart
  Map<String, int> _getUnpaidFoodStats() {
    final unpaidStats = <String, int>{};
    
    for (final entry in _unpaidFoodData.entries) {
      final foods = entry.value;
      for (final food in foods) {
        final foodName = FoodDataService.getFoodName(food);
        unpaidStats[foodName] = (unpaidStats[foodName] ?? 0) + 1;
      }
    }
    
    return unpaidStats;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheetWidget(
        availableFoodTypes: _availableFoodTypes,
        selectedFoodFilter: _selectedFoodFilter,
        onApplyFilter: (String? filter) {
          setState(() {
            _selectedFoodFilter = filter;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const CommonAppBar(title: 'Хоолны тайлан', variant: AppBarVariant.standard),
      body: Column(
        children: [
          MonthNavigationWidget(
            selectedMonth: _selectedMonth,
            onPreviousMonth: _navigatePreviousMonth,
            onNextMonth: _navigateNextMonth,
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    SummarySectionWidget(
                      unpaidCount: _unpaidFoodData.values.fold(
                        0,
                        (total, foods) => total + foods.length,
                      ),
                      paidTotal: _paidTotalAmount,
                      totalCost: _unpaidTotalAmount + _paidTotalAmount,
                      paymentBalance:
                          _paymentHistory.fold<double>(
                            0.0,
                            (total, payment) => total + (payment['amount'] as num).toDouble(),
                          ) -
                          (_unpaidTotalAmount + _paidTotalAmount),
                      selectedFoodFilter: _selectedFoodFilter,
                      onFilterPressed: _showFilterBottomSheet,
                    ),
                    const SizedBox(height: 24),
                    // Payment history
                    if (_paymentHistory.isNotEmpty) ...[
                      PaymentHistorySectionWidget(paymentHistory: _paymentHistory),
                      const SizedBox(height: 24),
                    ],
                    // Food frequency chart
                    FoodFrequencySectionWidget(
                      foodStats: _getUnpaidFoodStats(),
                      selectedFoodFilter: _selectedFoodFilter,
                    ),
                    const SizedBox(height: 24),
                    // Unpaid meals breakdown
                    DailyBreakdownSectionWidget(
                      unpaidFoodData: _unpaidFoodData,
                      selectedFoodFilter: _selectedFoodFilter,
                      onMarkMealAsPaid: _markMealAsPaid,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
