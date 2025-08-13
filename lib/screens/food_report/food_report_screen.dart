import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../widgets/common_app_bar.dart';
import '../../widgets/custom_drawer.dart';
import '../../services/money_format.dart';
import 'widgets/filter_bottom_sheet_widget.dart';
import 'tabview/daily_tab_screen.dart';
import 'tabview/history_tab_screen.dart';
import 'services/food_data_service.dart';
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

  // User statistics from totalFoodAmount
  int _totalPaymentAmount = 0;
  int _paymentBalance = 0;
  bool _userStatsLoading = true;
  StreamSubscription<DocumentSnapshot>? _userStatsSubscription;

  // Filtering
  String? _selectedFoodFilter;
  List<String> _availableFoodTypes = [];

  // Tab controller
  late TabController _tabController;

  // Helper to get current user ID
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              // This is automatically updated by RealtimeFoodTotalService
              int totalFoodConsumed = userData?['totalFoodAmount'] ?? 0;

              // Get total payments made (if tracking payments separately)
              int totalPaymentsMade = userData?['totalPaymentsMade'] ?? 0;

              setState(() {
                // _totalPaymentAmount = Amount to Pay (display totalFoodAmount from users collection)
                // _paymentBalance = Payment Balance (payments made - food consumed)
                _totalPaymentAmount =
                    totalFoodConsumed; // Show totalFoodAmount as "Төлөх дүн"
                _paymentBalance =
                    totalPaymentsMade -
                    totalFoodConsumed; // Balance (negative if owing money)
                _userStatsLoading = false;
              });

              debugPrint(
                '✅ Real-time user statistics: totalFoodAmount=$totalFoodConsumed, paymentsMade=$totalPaymentsMade, balance=$_paymentBalance',
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

      // Load all data using services
      final results = await Future.wait([
        FoodDataService.loadEatenForDayData(_selectedMonth),
        FoodDataService.loadFoodDataForMonth(_selectedMonth),
      ]);

      _eatenForDayData = results[0] as Map<String, bool>;
      _monthlyFoodData = results[1] as Map<String, List<Map<String, dynamic>>>;

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

  // Load user settings (for future use)
  Future<void> _loadUserSettings() async {
    try {
      // For now, using default values - in real app, load from SharedPreferences
      // Budget feature removed - no longer needed
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  // Update food filtering using service
  void _updateFoodFilter() {
    _availableFoodTypes = FoodDataService.getAvailableFoodTypes(
      _monthlyFoodData,
    );
  }

  // Get filtered food data using service
  Map<String, List<Map<String, dynamic>>> get _filteredFoodData =>
      FoodCalculationService.getFilteredFoodData(
        _monthlyFoodData,
        _eatenForDayData,
        _selectedFoodFilter,
      );

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
                  color: Colors.green.withOpacity(0.2),
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
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 14),
                    SizedBox(width: 6),
                    Text('Хоолны жагсаалт'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 14),
                    SizedBox(width: 6),
                    Text('Төлбөрийн түүх'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        SizedBox(
          height: 600, // Fixed height for the tab content
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Daily Breakdown
              DailyTabScreen(
                unpaidFoodData: _filteredFoodData,
                selectedFoodFilter: _selectedFoodFilter,
                onMarkMealAsPaid:
                    (String mealId, int amount, Map<String, dynamic> food) {
                      // No payment functionality
                    },
                onPayMonthly: () {
                  // No payment functionality
                },
                hasAnyFoodsInMonth: _hasAnyFoodsInMonth,
              ),
              // Tab 2: History
              const HistoryTabScreen(),
            ],
          ),
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
        currentScreen: DrawerScreenType.foodReport,
        onNavigateToTab: widget.onNavigateToTab,
      ),
      appBar: const CommonAppBar(
        title: 'Хоолны тайлан',
        variant: AppBarVariant.standard,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                color: Colors.black.withOpacity(0.1),
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
                                    'Хоолны зардал',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Төлөх дүн',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          MoneyFormatService.formatWithSymbol(
                                            _totalPaymentAmount,
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
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Төлбөрийн үлдэгдэл',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          MoneyFormatService.formatWithSymbol(
                                            _paymentBalance,
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
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () {
                                  // No payment functionality
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Төлбөр төлөх (Идэвхгүй)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 15),
                      // Tabbed breakdown section
                      _buildTabbedBreakdownSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
