import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyStatisticsScreen extends StatefulWidget {
  const MonthlyStatisticsScreen({super.key});

  @override
  State<MonthlyStatisticsScreen> createState() => _MonthlyStatisticsScreenState();
}

class _MonthlyStatisticsScreenState extends State<MonthlyStatisticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedWeekNumber;

  Map<String, dynamic> _monthlyData = {};
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = true;
  double _totalHours = 0.0;

  final List<String> _monthNames = [
    '1-сар', '2-сар', '3-сар', '4-сар',
    '5-сар', '6-сар', '7-сар', '8-сар',
    '9-сар', '10-сар', '11-сар', '12-сар'
  ];

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('calendarDays')
          .where('month', isEqualTo: _selectedMonth)
          .where('year', isEqualTo: _selectedYear)
          .get();

      print('Found ${querySnapshot.docs.length} documents for month $_selectedMonth');

      final List<Map<String, dynamic>> processedDays = [];
      double totalWorkedHours = 0.0;
      Set<int> weekNumbers = {};

      for (final doc in querySnapshot.docs) {
        final calendarDay = doc.data();
        final dateString = doc.id;

        print('Processing day: $dateString, data: $calendarDay');

        final Map<String, dynamic> dayData = {
          'date': dateString,
          'day': calendarDay['day'],
          'weekNumber': calendarDay['weekNumber'],
          'workingHours': calendarDay['workingHours']?.toDouble() ?? 0.0,
          'confirmed': calendarDay['confirmed'] ?? false,
          'isHoliday': calendarDay['isHoliday'] ?? false,
        };

        if (dayData['confirmed'] && !dayData['isHoliday'] && dayData['workingHours'] > 0) {
          totalWorkedHours += dayData['workingHours'];
        }

        if (calendarDay['weekNumber'] != null) {
          weekNumbers.add(calendarDay['weekNumber']);
        }
        processedDays.add(dayData);
      }

      processedDays.sort((a, b) => a['date'].compareTo(b['date']));

      List<Map<String, dynamic>> filteredData = processedDays;
      if (_selectedWeekNumber != null) {
        filteredData = processedDays.where((day) => day['weekNumber'] == _selectedWeekNumber).toList();
      }

      print('Processed ${processedDays.length} days, filtered to ${filteredData.length}');

      setState(() {
        _monthlyData = {
          'days': processedDays,
          'weekNumbers': weekNumbers.toList()..sort(),
        };
        _weeklyData = filteredData;
        _totalHours = totalWorkedHours;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading monthly data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDay(String dateString) async {
    try {
      await _firestore.collection('calendarDays').doc(dateString).update({'confirmed': true});
      _loadMonthlyData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$dateString-ны цагийг баталгаажууллаа'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 70,
            floating: false,
            pinned: true,
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Сарын статистик',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                ),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
            sliver: _isLoading
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Мэдээлэл ачаалж байна...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : SliverList(
              delegate: SliverChildListDelegate([
                // Date Selection Section
                _buildModernCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFF3B82F6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Хугацаа сонгох',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildModernDropdown<int>(
                              value: _selectedMonth,
                              label: 'Сар',
                              icon: Icons.event,
                              items: List.generate(12, (index) {
                                return DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(_monthNames[index]),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value!;
                                  _selectedWeekNumber = null;
                                });
                                _loadMonthlyData();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 130,
                            child: Expanded(
                              child: _buildModernDropdown<int>(
                                value: _selectedYear,
                                label: 'Жил',
                                icon: Icons.date_range,
                                items: [2024, 2025, 2026].map((year) {
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year.toString()),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value!;
                                    _selectedWeekNumber = null;
                                  });
                                  _loadMonthlyData();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Total Hours Display
                _buildTotalHoursCard(isTablet),

                const SizedBox(height: 20),

                // Week Selector
                if (_monthlyData['weekNumbers'] != null && _monthlyData['weekNumbers'].isNotEmpty)
                  _buildWeekSelectorCard(),

                if (_monthlyData['weekNumbers'] != null && _monthlyData['weekNumbers'].isNotEmpty)
                  const SizedBox(height: 20),

                // Days List
                _buildDaysListCard(isTablet),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildModernDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: items,
        onChanged: onChanged,
        dropdownColor: Colors.white,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTotalHoursCard(bool isTablet) {
    return _buildModernCard(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 32 : 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  _totalHours.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: isTablet ? 56 : 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'НИЙТ ЦАГ',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$_selectedMonth',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Сонгосон сар',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelectorCard() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.view_week_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Долоо хоног сонгох',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWeekChip('Бүгд', _selectedWeekNumber == null, () {
                setState(() {
                  _selectedWeekNumber = null;
                  _weeklyData = List<Map<String, dynamic>>.from(_monthlyData['days'] ?? []);
                });
              }),
              ..._monthlyData['weekNumbers'].map<Widget>((weekNum) {
                return _buildWeekChip(
                  weekNum.toString(),
                  _selectedWeekNumber == weekNum,
                      () {
                    setState(() {
                      _selectedWeekNumber = weekNum;
                      _weeklyData = List<Map<String, dynamic>>.from(_monthlyData['days'] ?? [])
                          .where((day) => day['weekNumber'] == weekNum)
                          .toList();
                    });
                  },
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDaysListCard(bool isTablet) {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.list_alt_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Өдрийн жагсаалт',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Check if we have data
          if (_weeklyData.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Сонгосон хугацаанд мэдээлэл олдсонгүй',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Өөр сар эсвэл жил сонгоно уу',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._weeklyData.asMap().entries.map((entry) {
              final index = entry.key;
              final dayData = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index == _weeklyData.length - 1 ? 0 : 12),
                child: _buildDayItem(dayData, isTablet),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildDayItem(Map<String, dynamic> dayData, bool isTablet) {
    final isConfirmed = dayData['confirmed'] ?? false;
    final workingHours = dayData['workingHours']?.toDouble() ?? 0.0;
    final isHoliday = dayData['isHoliday'] ?? false;
    final day = dayData['day'] ?? 0;
    final dateString = dayData['date'] ?? '';

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isConfirmed ? const Color(0xFFFEFCE8) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed ? const Color(0xFFEAB308) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Date Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isConfirmed ? const Color(0xFFEAB308) : const Color(0xFF64748B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_selectedMonth/$day',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Hours
          Text(
            '${workingHours.toStringAsFixed(1)}ц',
            style: TextStyle(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),

          const Spacer(),

          // Status Badge
          _buildStatusBadge(isHoliday, workingHours, isConfirmed, dateString),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isHoliday, double workingHours, bool isConfirmed, String dateString) {
    if (isHoliday) {
      return _buildBadge('Баяр', const Color(0xFFFB923C), const Color(0xFFFED7AA));
    } else if (workingHours == 0.0) {
      return _buildBadge('Амралт', const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    } else if (isConfirmed) {
      return _buildBadge('Батлагдсан', const Color(0xFF10B981), const Color(0xFFD1FAE5));
    } else {
      return _buildConfirmButton(dateString);
    }
  }

  Widget _buildBadge(String text, Color color, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildConfirmButton(String dateString) {
    return GestureDetector(
      onTap: () => _confirmDay(dateString),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Батлах',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}