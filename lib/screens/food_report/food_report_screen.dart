import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import '../../services/money_format.dart';
import 'widgets/month_navigation_widget.dart';
import 'widgets/summary_section_widget.dart';
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

  // Mark all unpaid meals for the month as paid
  Future<void> _payMonthly() async {
    if (_unpaidFoodData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Төлөх хоол байхгүй байна'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Calculate total amount
    final totalAmount = _unpaidTotalAmount;
    final totalFoods = _unpaidFoodData.values.fold<int>(0, (sum, foods) => sum + foods.length);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Сарын төлбөр төлөх'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сарын нийт төлбөр: ${MoneyFormatService.formatWithSymbol(totalAmount)}'),
              const SizedBox(height: 8),
              Text('Нийт хоол: $totalFoods'),
              const SizedBox(height: 16),
              const Text('Та энэ сарын бүх хоолны төлбөрийг төлөхийг хүсэж байна уу?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Үгүй'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Тийм'),
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
            PaymentService.saveMealPaymentStatus(_selectedMonth, mealKey, true)
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
              content: Text('Сарын төлбөр амжилттай төлөгдлөө! ${MoneyFormatService.formatWithSymbol(totalAmount)}'),
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
              content: Text('Төлбөр төлөхөд алдаа гарлаа. Дахин оролдоно уу.'),
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
            content: Text('Алдаа гарлаа: $e'),
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

  // Check if any foods exist in the selected month
  bool get _hasAnyFoodsInMonth => _monthlyFoodData.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Хоолны тайлан', variant: AppBarVariant.standard, backgroundColor: Colors.white,),
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
                    // FoodFrequencySectionWidget(
                    //   foodStats: _getUnpaidFoodStats(),
                    //   selectedFoodFilter: _selectedFoodFilter,
                    // ),
                    // const SizedBox(height: 24),
                    // Unpaid meals breakdown
                    DailyBreakdownSectionWidget(
                      unpaidFoodData: _unpaidFoodData,
                      selectedFoodFilter: _selectedFoodFilter,
                      onMarkMealAsPaid: _markMealAsPaid,
                      onPayMonthly: _payMonthly,
                      hasAnyFoodsInMonth: _hasAnyFoodsInMonth,
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
