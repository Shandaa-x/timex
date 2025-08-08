import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

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
  
  @override
  void initState() {
    super.initState();
    _loadMonthlyFoodData();
  }

  Future<void> _loadMonthlyFoodData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      _monthlyFoodData.clear();
      _foodStats.clear();

      // Optimized: Use range query instead of individual document queries
      final startDocId = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01-foods';
      final endDocId = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}-foods';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get();

      // Process all documents at once
      for (final doc in querySnapshot.docs) {
        if (doc.exists) {
          final data = doc.data();
          final dateKey = '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';
          
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
      print('Error loading monthly food data: $e');
      // Fallback to individual queries if range query fails
      await _loadMonthlyFoodDataFallback();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fallback method for individual document queries
  Future<void> _loadMonthlyFoodDataFallback() async {
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    // Use batch processing to reduce loading time
    final futures = <Future<void>>[];
    
    for (int day = 1; day <= endOfMonth.day; day++) {
      final documentId = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}-foods';
      futures.add(_loadSingleDayFood(documentId));
    }

    // Wait for all queries to complete
    await Future.wait(futures);
  }

  Future<void> _loadSingleDayFood(String documentId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final dateKey = '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';
        
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
    } catch (e) {
      // Skip documents that don't exist
    }
  }

  void _navigatePreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadMonthlyFoodData();
  }

  void _navigateNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadMonthlyFoodData();
  }

  String _getMonthName(int month) {
    const months = [
      '1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар',
      '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'
    ];
    return months[month - 1];
  }

  int get _totalFoodsCount {
    return _monthlyFoodData.values.fold(0, (sum, foods) => sum + foods.length);
  }

  int get _totalSpent {
    int total = 0;
    for (final foods in _monthlyFoodData.values) {
      for (final food in foods) {
        total += (food['price'] as int? ?? 0);
      }
    }
    return total;
  }

  double get _averageDailySpending {
    final daysWithFood = _monthlyFoodData.keys.length;
    return daysWithFood > 0 ? _totalSpent / daysWithFood : 0;
  }

  void _showPaymentBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPaymentBottomSheet(),
    );
  }

  Widget _buildPaymentBottomSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Төлбөр төлөх',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Хоолны төлбөрөө төлөх аргыг сонгоно уу',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Payment options
              _buildPaymentOption(
                theme,
                colorScheme,
                'Өдрөөр төлөх',
                'Өнөөдрийн хоолны төлбөр',
                _getTodaySpending(),
                Icons.today,
                () => _processPayment('daily', _getTodaySpending()),
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                theme,
                colorScheme,
                'Сараар төлөх',
                'Энэ сарын хоолны төлбөр',
                _totalSpent,
                Icons.calendar_month,
                () => _processPayment('monthly', _totalSpent),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String subtitle,
    int amount,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: amount > 0 ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: amount > 0 ? AppTheme.primaryLight.withOpacity(0.1) : colorScheme.outline.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: amount > 0 ? AppTheme.primaryLight.withOpacity(0.3) : colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: amount > 0 ? AppTheme.primaryLight : colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: amount > 0 ? Colors.white : colorScheme.onSurface.withOpacity(0.5),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: amount > 0 ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: amount > 0 ? colorScheme.onSurface.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₮$amount',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: amount > 0 ? AppTheme.primaryLight : colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getTodaySpending() {
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayFoods = _monthlyFoodData[todayKey] ?? [];
    return todayFoods.fold<int>(0, (sum, food) => sum + (food['price'] as int? ?? 0));
  }

  Future<void> _processPayment(String type, int amount) async {
    Navigator.of(context).pop(); // Close bottom sheet

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Төлөх дүн байхгүй байна'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show QPay simulation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildQPayDialog(type, amount),
    );
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                  
                  _buildPaymentInfoRow('Төрөл:', type == 'daily' ? 'Өдрийн төлбөр' : 'Сарын төлбөр', theme, colorScheme),
                  _buildPaymentInfoRow('Дүн:', '₮$amount', theme, colorScheme),
                  _buildPaymentInfoRow('Огноо:', '${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', theme, colorScheme),
                  _buildPaymentInfoRow('Цаг:', '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', theme, colorScheme),
                  _buildPaymentInfoRow('Гүйлгээний дугаар:', 'TXN${DateTime.now().millisecondsSinceEpoch}', theme, colorScheme),
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
                    ...(_getTodayFoodsList().map((food) => Padding(
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
                    ))),
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
                    _buildPaymentInfoRow('Хоолтой өдөр:', '${_monthlyFoodData.keys.length}', theme, colorScheme),
                    _buildPaymentInfoRow('Өдрийн дундаж:', '₮${_averageDailySpending.toStringAsFixed(0)}', theme, colorScheme),
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
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  Widget _buildPaymentInfoRow(String label, String value, ThemeData theme, ColorScheme colorScheme) {
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
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Хоолны тайлан',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPaymentBottomSheet,
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.payment),
        label: const Text(
          'Төлөх',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Month navigation
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _navigatePreviousMonth,
                  icon: Icon(
                    Icons.chevron_left,
                    color: AppTheme.primaryLight,
                    size: 32,
                  ),
                ),
                Text(
                  '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: _navigateNextMonth,
                  icon: Icon(
                    Icons.chevron_right,
                    color: AppTheme.primaryLight,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    _buildSummarySection(theme, colorScheme),
                    
                    const SizedBox(height: 24),
                    
                    // Food frequency chart
                    _buildFoodFrequencySection(theme, colorScheme),
                    
                    const SizedBox(height: 24),
                    
                    // Daily breakdown
                    _buildDailyBreakdownSection(theme, colorScheme),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Нийт тойм',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Нийт хоол',
                '$_totalFoodsCount',
                Icons.restaurant,
                AppTheme.successLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Нийт зардал',
                '₮$_totalSpent',
                Icons.attach_money,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Өдрийн дундаж',
                '₮${_averageDailySpending.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                theme,
                colorScheme,
                'Хоолтой өдөр',
                '${_monthlyFoodData.keys.length}',
                Icons.calendar_today,
                Colors.purple,
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodFrequencySection(ThemeData theme, ColorScheme colorScheme) {
    final sortedFoods = _foodStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Хамгийн их идсэн хоол',
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
                'Энэ сард хоол бүртгэгдээгүй байна',
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
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
          }).toList(),
      ],
    );
  }

  Widget _buildDailyBreakdownSection(ThemeData theme, ColorScheme colorScheme) {
    final sortedDates = _monthlyFoodData.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Өдрийн задаргаа',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
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
              child: Text(
                'Энэ сард хоол бүртгэгдээгүй байна',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          )
        else
          ...sortedDates.map((dateKey) {
            final foods = _monthlyFoodData[dateKey]!;
            final date = DateTime.parse(dateKey);
            final dayTotal = foods.fold<int>(0, (sum, food) => sum + (food['price'] as int? ?? 0));
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successLight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successLight.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${date.month}/${date.day}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '₮$dayTotal',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${foods.length} хоол: ${foods.map((f) => f['name']).join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
}
