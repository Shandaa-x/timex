import 'package:flutter/material.dart';
import 'package:timex/screens/main/home/widgets/custom_sliver_appbar.dart';
import 'package:intl/intl.dart';
  String formatMoney(num value) {
    return NumberFormat('#,##0.00', 'en_US').format(value);
  }

class SalaryBreakdownScreen extends StatefulWidget {
  final double monthlySalary;
  final List<Map<String, dynamic>> allWorkedDaysDetails;

  const SalaryBreakdownScreen({
    Key? key,
    required this.monthlySalary,
    required this.allWorkedDaysDetails,
  }) : super(key: key);

  @override
  State<SalaryBreakdownScreen> createState() => _SalaryBreakdownScreenState();
}

class _SalaryBreakdownScreenState extends State<SalaryBreakdownScreen>
    with SingleTickerProviderStateMixin {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  final monthNames = [
    '1-сар',
    '2-сар',
    '3-сар',
    '4-сар',
    '5-сар',
    '6-сар',
    '7-сар',
    '8-сар',
    '9-сар',
    '10-сар',
    '11-сар',
    '12-сар',
  ];

  double monthlySalary = 0.0;
  int eligibleDays = 0;
  double totalWorkingHours = 0.0;
  double grossSalary = 0.0;
  double socialSecurity = 0.0;
  double incomeTax = 0.0;
  double netSalary = 0.0;
  List<Map<String, dynamic>> workedDaysDetails = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    monthlySalary = widget.monthlySalary;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _calculateSalaryForMonth();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateSalaryForMonth() {
    workedDaysDetails = widget.allWorkedDaysDetails.where((day) {
      final date = DateTime.tryParse(day['date'] ?? '') ?? DateTime(2000);
      return date.month == selectedMonth && date.year == selectedYear;
    }).toList();
    eligibleDays = workedDaysDetails.length;
    totalWorkingHours = 0.0;
    for (final day in workedDaysDetails) {
      final hours = (day['workingHours'] ?? 0.0) as double;
      totalWorkingHours += hours;
    }

    // Calculate workdays in month, excluding weekends
    int workingDaysInMonth = 0;
    final daysInMonth = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(selectedYear, selectedMonth, day);
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        workingDaysInMonth++;
      }
    }
    final expectedMonthlyHours = workingDaysInMonth * 8;
    double hourlyRate = monthlySalary > 0 && expectedMonthlyHours > 0
        ? monthlySalary / expectedMonthlyHours
        : 0.0;

    grossSalary = 0.0;
    for (final day in workedDaysDetails) {
      final hours = (day['workingHours'] ?? 0.0) as double;
      final daySalary = hourlyRate * hours;
      day['salary'] = daySalary;
      grossSalary += daySalary;
    }

    socialSecurity = grossSalary * 0.24;
    netSalary = grossSalary - socialSecurity;
    setState(() {});
  }

  void _changeMonth(int delta) {
    setState(() {
      selectedMonth += delta;
      if (selectedMonth < 1) {
        selectedMonth = 12;
        selectedYear--;
      } else if (selectedMonth > 12) {
        selectedMonth = 1;
        selectedYear++;
      }
      _calculateSalaryForMonth();
    });
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          Text(
            title.contains('цалин') || title.contains('Нийлбэр')
                ? formatMoney(double.tryParse(value.replaceAll('₮', '')) ?? 0) + '₮'
                : value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkDayCard(Map<String, dynamic> day) {
    final date = day['date'] ?? '';
    final hours = day['workingHours'] ?? 0.0;
    final salary = day['salary'] ?? 0.0;

    final parsedDate = DateTime.tryParse(date);
    final dayOfWeek = parsedDate != null
        ? ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'][parsedDate.weekday - 1]
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.withOpacity(0.2),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  dayOfWeek,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${hours.floor()} цаг ${((hours - hours.floor()) * 60).round()} мин',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(salary) + '₮',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(salary / monthlySalary * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          const CustomSliverAppBar(
            title: 'Цалингийн задаргаа',
            gradientColors: [Color(0xFF3B82F6), Color(0xFF3B82F6)],
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.chevron_left,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${monthNames[selectedMonth - 1]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                '$selectedYear',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(1),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.7,
                      children: [
                        _buildStatCard(
                          icon: Icons.account_balance_wallet,
                          title: 'Сарын цалин',
                          value: monthlySalary.toString(),
                          color: Colors.purple,
                        ),
                        _buildStatCard(
                          icon: Icons.calendar_today,
                          title: 'Ажилласан өдөр',
                          value: eligibleDays.toString(),
                          color: Colors.blue,
                          subtitle: 'өдөр',
                        ),
                        _buildStatCard(
                          icon: Icons.access_time,
                          title: 'Нийт цаг',
                          value:
                              '${totalWorkingHours.floor()}ц ${((totalWorkingHours - totalWorkingHours.floor()) * 60).round()}м',
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          icon: Icons.trending_up,
                          title: 'Нийлбэр цалин',
                          value: grossSalary.toString(),
                          color: Colors.green,
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Суутгалууд',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Нийгмийн даатгал (24%)',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                '-${formatMoney(socialSecurity)}₮',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.withOpacity(0.1),
                            Colors.green.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.attach_money,
                              color: Colors.green,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Гар дээр авах цалин',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatMoney(netSalary) + '₮',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (workedDaysDetails.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.list_alt,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Ажлын өдрүүд',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...workedDaysDetails
                          .map((day) => _buildWorkDayCard(day))
                          .toList(),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Тайлбар',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ажлын өдөр бүрийн ажилласан цаг, цалинг дэлгэрэнгүй харуулна. Сарын нийт цалин, суутгалууд, гар дээр авах цалин дэлгэрэнгүй тооцоолно.',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
