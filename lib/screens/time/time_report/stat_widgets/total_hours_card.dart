import 'package:flutter/material.dart';
import 'modern_card.dart';

class TotalHoursCard extends StatelessWidget {
  final double totalHours;
  final int selectedMonth;
  final int selectedYear;
  final List<String> monthNames;
  final bool isTablet;

  const TotalHoursCard({
    super.key,
    required this.totalHours,
    required this.selectedMonth,
    required this.selectedYear,
    required this.monthNames,
    required this.isTablet,
  });

  String formatMongolianHours(double hours) {
    final int h = hours.floor();
    final int m = ((hours - h) * 60).round();
    if (h > 0 && m > 0) return '$h цаг, $m минут';
    if (h > 0) return '$h цаг';
    return '$h цаг, $m минут';
  }

  @override
  Widget build(BuildContext context) {
    return ModernCard(
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
                  formatMongolianHours(totalHours),
                  style: TextStyle(
                    fontSize: isTablet ? 30 : 24,
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
        ],
      ),
    );
  }
}