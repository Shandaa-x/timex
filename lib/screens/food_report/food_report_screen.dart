import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';
import '../../services/money_format.dart';
import 'widgets/month_navigation_widget.dart';
import 'widgets/summary_section_widget.dart';
import 'widgets/food_frequency_section_widget.dart';
import 'widgets/daily_breakdown_section_widget.dart';
import 'widgets/payment_history_section_widget.dart';
import 'widgets/filter_bottom_sheet_widget.dart';
import 'widgets/qpay_dialog_widget.dart';

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
  Map<String, bool> _paidMeals =
      {}; // Track which individual meals are paid for (key: dateKey-foodIndex)

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

      // Load all data in parallel for better performance
      await Future.wait([
        _loadEatenForDayDataOptimized(),
        _loadMealPaymentStatus(),
        _loadFoodDataOptimized(),
      ]);
    } catch (e) {
      print('Error loading monthly food data: $e');
      // Show error message to user
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

  // Optimized food data loading
  Future<void> _loadFoodDataOptimized() async {
    try {
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Use range query with better error handling
      final startDocId =
          '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01-foods';
      final endDocId =
          '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}-foods';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get(const GetOptions(source: Source.serverAndCache)); // Use cache when possible

      // Process all documents at once
      for (final doc in querySnapshot.docs) {
        if (doc.exists) {
          final data = doc.data();
          final dateKey =
              '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';

          if (data['foods'] != null && data['foods'] is List) {
            final foods = List<Map<String, dynamic>>.from(data['foods']);
            _monthlyFoodData[dateKey] = foods;

            // Calculate statistics
            for (final food in foods) {
              final foodName = food['name'] as String? ?? 'Unknown';
              _foodStats[foodName] = (_foodStats[foodName] ?? 0) + 1;
            }
          }
        }
      }
    } catch (e) {
      print('Range query failed, using fallback: $e');
      // If range query fails, we'll just have empty food data rather than slow fallback
      // Users can still use the app, just with limited food data
    }
  }

  // Optimized eaten for day data loading using batch queries
  Future<void> _loadEatenForDayDataOptimized() async {
    try {
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      final startDocId =
          '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01';
      final endDocId =
          '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}';

      // Use range query to get all calendar days for the month
      final querySnapshot = await FirebaseFirestore.instance
          .collection('calendarDays')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get(const GetOptions(source: Source.serverAndCache));

      // Process the results
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        _eatenForDayData[dateKey] = data['eatenForDay'] as bool? ?? false;
      }

      // Fill in missing days with false (not eaten)
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dateKey =
            '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        _eatenForDayData[dateKey] ??= false;
      }
    } catch (e) {
      print('Optimized eaten data loading failed, using fallback: $e');
      // Fallback to individual queries only if really necessary
      await _loadEatenForDayDataFallback();
    }
  }

  // Fallback method for eaten for day data (only used if optimized method fails)
  Future<void> _loadEatenForDayDataFallback() async {
    try {
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      final futures = <Future<void>>[];

      // Use batch processing to reduce loading time
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dateKey =
            '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        futures.add(_loadSingleDayEatenStatus(dateKey));
      }

      // Wait for all queries to complete
      await Future.wait(futures);
    } catch (e) {
      print('Error loading eaten for day data: $e');
    }
  }

  Future<void> _loadSingleDayEatenStatus(String dateKey) async {
    try {
      final calendarDoc = await FirebaseFirestore.instance
          .collection('calendarDays')
          .doc(dateKey)
          .get();

      if (calendarDoc.exists) {
        final data = calendarDoc.data()!;
        _eatenForDayData[dateKey] = data['eatenForDay'] as bool? ?? false;
      } else {
        _eatenForDayData[dateKey] = false;
      }
    } catch (e) {
      print('Error loading eaten status for $dateKey: $e');
      _eatenForDayData[dateKey] = false;
    }
  }

  void _navigatePreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
      _selectedFoodFilter = null; // Clear filter when changing month
    });
    _loadMonthlyFoodData();
    _loadPaymentHistory();
  }

  void _navigateNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      _selectedFoodFilter = null; // Clear filter when changing month
    });
    _loadMonthlyFoodData();
    _loadPaymentHistory();
  }

  String _getMonthName(int month) {
    const months = [
      '1-р сар',
      '2-р сар',
      '3-р сар',
      '4-р сар',
      '5-р сар',
      '6-р сар',
      '7-р сар',
      '8-р сар',
      '9-р сар',
      '10-р сар',
      '11-р сар',
      '12-р сар',
    ];
    return months[month - 1];
  }

  int get _totalFoodsCount {
    int count = 0;
    for (final entry in _monthlyFoodData.entries) {
      final dateKey = entry.key;
      final foods = entry.value;
      final wasEaten = _eatenForDayData[dateKey] ?? false;

      // Only count foods if they were eaten that day
      if (wasEaten) {
        count += foods.length;
      }
    }
    return count;
  }

  int get _totalSpent {
    int total = 0;
    for (final entry in _monthlyFoodData.entries) {
      final dateKey = entry.key;
      final foods = entry.value;
      final wasEaten = _eatenForDayData[dateKey] ?? false;

      // Only count cost if foods were eaten that day
      if (wasEaten) {
        for (final food in foods) {
          total += (food['price'] as int? ?? 0);
        }
      }
    }
    return total;
  }

  double get _averageDailySpending {
    final daysWithEatenFood = _monthlyFoodData.entries
        .where((entry) => _eatenForDayData[entry.key] == true && entry.value.isNotEmpty)
        .length;
    return daysWithEatenFood > 0 ? _totalSpent / daysWithEatenFood : 0;
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

  // Load payment history from Firestore
  Future<void> _loadPaymentHistory() async {
    try {
      final userId = 'current_user'; // Replace with actual user ID
      final monthKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

      final docSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .doc('$userId-$monthKey')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _paymentHistory = List<Map<String, dynamic>>.from(data['payments'] ?? []);
      } else {
        _paymentHistory = [];
      }
    } catch (e) {
      print('Error loading payment history: $e');
      _paymentHistory = [];
    }
  }

  // Load meal payment status from Firestore
  Future<void> _loadMealPaymentStatus() async {
    try {
      final userId = 'current_user'; // Replace with actual user ID
      final monthKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

      final docSnapshot = await FirebaseFirestore.instance
          .collection('mealPayments')
          .doc('$userId-$monthKey')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _paidMeals = Map<String, bool>.from(data['paidMeals'] ?? {});
      } else {
        _paidMeals = {};
      }
    } catch (e) {
      print('Error loading meal payment status: $e');
      _paidMeals = {};
    }
  }

  // Save meal payment status to Firestore
  Future<void> _saveMealPaymentStatus(String mealKey, bool isPaid) async {
    try {
      final userId = 'current_user'; // Replace with actual user ID
      final monthKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

      final docRef = FirebaseFirestore.instance.collection('mealPayments').doc('$userId-$monthKey');

      await docRef.set({
        'userId': userId,
        'year': _selectedMonth.year,
        'month': _selectedMonth.month,
        'paidMeals.$mealKey': isPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local state
      setState(() {
        _paidMeals[mealKey] = isPaid;
      });
    } catch (e) {
      print('Error saving meal payment status: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Алдаа гарлаа: $e'), backgroundColor: Colors.red));
    }
  }

  // Mark individual meal as paid
  Future<void> _markMealAsPaid(String dateKey, int foodIndex, Map<String, dynamic> food) async {
    final mealKey = '${dateKey}_$foodIndex';
    await _saveMealPaymentStatus(mealKey, true);

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${food['name']} төлбөр төлөгдлөө'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Update food filtering
  void _updateFoodFilter() {
    _availableFoodTypes.clear();
    final allFoods = <String>{};

    for (final foods in _monthlyFoodData.values) {
      for (final food in foods) {
        final foodName = food['name'] as String? ?? 'Unknown';
        allFoods.add(foodName);
      }
    }

    _availableFoodTypes = allFoods.toList()..sort();
  }

  // Get filtered food data (only from days where food was eaten)
  Map<String, List<Map<String, dynamic>>> get _filteredFoodData {
    final filtered = <String, List<Map<String, dynamic>>>{};

    for (final entry in _monthlyFoodData.entries) {
      final dateKey = entry.key;
      final wasEaten = _eatenForDayData[dateKey] ?? false;

      // Only include foods from days where food was eaten
      if (wasEaten) {
        List<Map<String, dynamic>> filteredFoods;

        if (_selectedFoodFilter == null) {
          filteredFoods = entry.value;
        } else {
          filteredFoods = entry.value.where((food) {
            final foodName = food['name'] as String? ?? 'Unknown';
            return foodName == _selectedFoodFilter;
          }).toList();
        }

        if (filteredFoods.isNotEmpty) {
          filtered[dateKey] = filteredFoods;
        }
      }
    }
    return filtered;
  }

  // Get only unpaid meals data for display
  Map<String, List<Map<String, dynamic>>> get _unpaidFoodData {
    final unpaid = <String, List<Map<String, dynamic>>>{};

    for (final entry in _monthlyFoodData.entries) {
      final dateKey = entry.key;
      final wasEaten = _eatenForDayData[dateKey] ?? false;

      // Only include foods from days where food was eaten
      if (wasEaten) {
        final unpaidMealsForDay = <Map<String, dynamic>>[];

        for (int i = 0; i < entry.value.length; i++) {
          final food = entry.value[i];
          final mealKey = '${dateKey}_$i';
          final isPaid = _paidMeals[mealKey] ?? false;

          // Apply food filter if selected
          final foodName = food['name'] as String? ?? 'Unknown';
          final matchesFilter = _selectedFoodFilter == null || foodName == _selectedFoodFilter;

          // Only include unpaid meals that match the filter
          if (!isPaid && matchesFilter) {
            final meal = Map<String, dynamic>.from(food);
            meal['_index'] = i; // Store the index for payment tracking
            unpaidMealsForDay.add(meal);
          }
        }

        if (unpaidMealsForDay.isNotEmpty) {
          unpaid[dateKey] = unpaidMealsForDay;
        }
      }
    }
    return unpaid;
  }

  // Get unpaid meals total
  int get _unpaidTotalAmount {
    int total = 0;
    for (final entry in _unpaidFoodData.entries) {
      final foods = entry.value;
      for (final food in foods) {
        total += (food['price'] as int? ?? 0);
      }
    }
    return total;
  }

  // Get paid meals total
  int get _paidTotalAmount {
    int total = 0;
    for (final entry in _filteredFoodData.entries) {
      final dateKey = entry.key;
      final foods = entry.value;

      for (int i = 0; i < foods.length; i++) {
        final mealKey = '${dateKey}_$i';
        final isPaid = _paidMeals[mealKey] ?? false;

        if (isPaid) {
          total += (foods[i]['price'] as int? ?? 0);
        }
      }
    }
    return total;
  }

  int _getTodaySpending() {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayFoods = _monthlyFoodData[todayKey] ?? [];
    return todayFoods.fold<int>(0, (total, food) => total + (food['price'] as int? ?? 0));
  }

  Future<void> _processPayment(String type, int amount) async {
    Navigator.of(context).pop(); // Close bottom sheet

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Төлөх дүн байхгүй байна'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Save payment to history
    await _savePaymentToHistory(type, amount);

    // Show QPay simulation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildQPayDialog(type, amount),
    );
  }

  // Save payment to Firestore
  Future<void> _savePaymentToHistory(String type, int amount) async {
    try {
      final userId = 'current_user'; // Replace with actual user ID
      final monthKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      final paymentData = {
        'type': type,
        'amount': amount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'date': DateTime.now().toIso8601String(),
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      };

      final docRef = FirebaseFirestore.instance.collection('payments').doc('$userId-$monthKey');

      await docRef.set({
        'userId': userId,
        'year': _selectedMonth.year,
        'month': _selectedMonth.month,
        'payments': FieldValue.arrayUnion([paymentData]),
      }, SetOptions(merge: true));

      // Update local payment history
      _paymentHistory.add(paymentData);
    } catch (e) {
      print('Error saving payment: $e');
    }
  }

  Widget _buildQPayDialog(String type, int amount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QPay logo placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'QPay',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'QPay төлбөр',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              type == 'daily' ? 'Өдрийн хоолны төлбөр' : 'Сарын хоолны төлбөр',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₮$amount',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Information for Printing
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ТӨЛБӨРИЙН МЭДЭЭЛЭЛ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildPaymentInfoRow(
                    'Төрөл:',
                    type == 'daily' ? 'Өдрийн төлбөр' : 'Сарын төлбөр',
                    theme,
                    colorScheme,
                  ),
                  _buildPaymentInfoRow('Дүн:', '₮$amount', theme, colorScheme),
                  _buildPaymentInfoRow(
                    'Огноо:',
                    '${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}',
                    theme,
                    colorScheme,
                  ),
                  _buildPaymentInfoRow(
                    'Цаг:',
                    '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    theme,
                    colorScheme,
                  ),
                  _buildPaymentInfoRow(
                    'Гүйлгээний дугаар:',
                    'TXN${DateTime.now().millisecondsSinceEpoch}',
                    theme,
                    colorScheme,
                  ),
                  _buildPaymentInfoRow('Төлбөрийн хэрэгсэл:', 'QPay', theme, colorScheme),

                  if (type == 'daily') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Өнөөдрийн хоолны жагсаалт:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_getTodayFoodsList().map(
                      (food) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '• ${food['name']}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                            Text(
                              '₮${food['price']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],

                  if (type == 'monthly') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Сарын статистик:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentInfoRow('Нийт хоол:', '$_totalFoodsCount', theme, colorScheme),
                    _buildPaymentInfoRow(
                      'Хоолтой өдөр:',
                      '${_monthlyFoodData.keys.length}',
                      theme,
                      colorScheme,
                    ),
                    _buildPaymentInfoRow(
                      'Өдрийн дундаж:',
                      '₮${_averageDailySpending.toStringAsFixed(0)}',
                      theme,
                      colorScheme,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(
                      'Цуцлах',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _printPaymentInfo(type, amount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.print, size: 18),
                        const SizedBox(width: 8),
                        const Text('Хэвлэх'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoRow(
    String label,
    String value,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getTodayFoodsList() {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _monthlyFoodData[todayKey] ?? [];
  }

  void _printPaymentInfo(String type, int amount) {
    Navigator.of(context).pop(); // Close QPay dialog

    // Show success message with print simulation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.print, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Төлбөрийн мэдээлэл бэлтгэгдлээ! Хэвлэх боломжтой.',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );

    // In a real app, you would save this information to prepare for QPay integration
    print('=== ТӨЛБӨРИЙН МЭДЭЭЛЭЛ ===');
    print('Төрөл: ${type == 'daily' ? 'Өдрийн төлбөр' : 'Сарын төлбөр'}');
    print('Дүн: ₮$amount');
    print('Огноо: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}');
    print('Гүйлгээний дугаар: TXN${DateTime.now().millisecondsSinceEpoch}');
    print('========================');
  }

  // Show filter bottom sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheetWidget(
        availableFoodTypes: _availableFoodTypes,
        selectedFoodFilter: _selectedFoodFilter,
        onApplyFilter: _applyFilter,
      ),
    );
  }

  // Get unpaid food statistics for frequency chart
  Map<String, int> _getUnpaidFoodStats() {
    final unpaidData = _unpaidFoodData;
    final unpaidStats = <String, int>{};

    for (final foods in unpaidData.values) {
      for (final food in foods) {
        final foodName = food['name'] as String? ?? 'Unknown';
        unpaidStats[foodName] = (unpaidStats[foodName] ?? 0) + 1;
      }
    }

    return unpaidStats;
  }

  void _applyFilter(String? filterValue) {
    setState(() {
      _selectedFoodFilter = filterValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const CommonAppBar(title: 'Хоолны тайлан', variant: AppBarVariant.standard),
      body: Column(
        children: [
          // Month navigation
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

  Widget _buildSummarySection(ThemeData theme, ColorScheme colorScheme) {
    final unpaidData = _unpaidFoodData;
    final unpaidTotal = _unpaidTotalAmount;
    final paidTotal = _paidTotalAmount;
    final unpaidCount = unpaidData.values.fold(0, (total, foods) => total + foods.length);
    final totalPayments = _paymentHistory.fold<double>(
      0.0,
      (total, payment) => total + (payment['amount'] as num).toDouble(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Төлбөрийн тойм',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            // Filter button
            TextButton.icon(
              onPressed: _showFilterBottomSheet,
              icon: Icon(
                _selectedFoodFilter != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 18,
                color: AppTheme.primaryLight,
              ),
              label: Text(
                _selectedFoodFilter ?? 'Бүгд',
                style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // First row: Unpaid meals count and paid amount
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                _selectedFoodFilter != null ? 'Шүүсэн төлөгдөөгүй' : 'Төлөгдөөгүй хоол',
                '$unpaidCount',
                Icons.schedule,
                AppTheme.warningLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Төлсөн дүн',
                '₮$paidTotal',
                Icons.check_circle,
                AppTheme.successLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Second row: Total food cost and payment balance
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Нийт хоолны зардал',
                '₮${unpaidTotal + paidTotal}',
                Icons.restaurant,
                colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Төлбөрийн үлдэгдэл',
                '₮${(totalPayments - (unpaidTotal + paidTotal)).toStringAsFixed(0)}',
                Icons.savings,
                (totalPayments - (unpaidTotal + paidTotal)) >= 0
                    ? AppTheme.successLight
                    : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodFrequencySection(ThemeData theme, ColorScheme colorScheme) {
    final unpaidData = _unpaidFoodData;
    final unpaidStats = <String, int>{};

    // Calculate statistics for unpaid food data
    for (final foods in unpaidData.values) {
      for (final food in foods) {
        final foodName = food['name'] as String? ?? 'Unknown';
        unpaidStats[foodName] = (unpaidStats[foodName] ?? 0) + 1;
      }
    }

    final sortedFoods = unpaidStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedFoodFilter != null ? 'Шүүсэн төлөгдөөгүй хоол' : 'Төлөгдөөгүй хоолны давтамж',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (sortedFoods.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                _selectedFoodFilter != null
                    ? 'Шүүсэн төлөгдөөгүй хоол олдсонгүй'
                    : 'Төлөгдөөгүй хоол байхгүй байна 🎉',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          )
        else
          ...sortedFoods.take(5).map((entry) {
            final maxCount = sortedFoods.first.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${entry.value} удаа',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value / maxCount,
                    backgroundColor: colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successLight),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDailyBreakdownSection(ThemeData theme, ColorScheme colorScheme) {
    final unpaidData = _unpaidFoodData;
    final sortedDates = unpaidData.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payment_outlined, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              _selectedFoodFilter != null
                  ? 'Шүүсэн төлөгдөөгүй хоол'
                  : 'Төлөгдөөгүй хоолны жагсаалт',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sortedDates.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFoodFilter != null
                        ? 'Шүүсэн хоолны төлөгдөөгүй зүйл олдсонгүй'
                        : 'Бүх хоол төлөгдсөн байна! 🎉',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedDates.map((dateKey) {
            final foods = unpaidData[dateKey]!;
            final date = DateTime.parse(dateKey);
            final dayTotal = foods.fold<int>(0, (sum, food) => sum + (food['price'] as int? ?? 0));

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningLight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningLight.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header with unpaid amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.month}/${date.day}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${_getWeekdayName(date.weekday)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warningLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 16, color: AppTheme.warningLight),
                            const SizedBox(width: 4),
                            Text(
                              '₮$dayTotal',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warningLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Individual unpaid meals list
                  ...foods.map((food) {
                    final foodIndex = food['_index'] as int;
                    final price = food['price'] as int? ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.warningLight.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          // Meal info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.schedule, size: 16, color: AppTheme.warningLight),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        food['name'] as String? ?? 'Unknown',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (food['comments']?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    food['comments'],
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Price and payment button
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₮$price',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.warningLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () => _markMealAsPaid(dateKey, foodIndex, food),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryLight,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(0, 32),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  icon: const Icon(Icons.payment, size: 14),
                                  label: const Text('Төлөх'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPaymentHistorySection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Төлбөрийн түүх',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            children: _paymentHistory.map((payment) {
              final date = DateTime.fromMillisecondsSinceEpoch(payment['timestamp'] as int);
              final isLast = _paymentHistory.last == payment;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: colorScheme.outline.withOpacity(0.1), width: 1),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.payment, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment['type'] == 'daily' ? 'Өдрийн төлбөр' : 'Сарын төлбөр',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₮${payment['amount']}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'];
    return weekdays[weekday - 1];
  }
}
