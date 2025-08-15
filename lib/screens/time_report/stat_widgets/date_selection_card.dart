import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'modern_card.dart';

class DateSelectionCard extends StatelessWidget {
  final int selectedMonth;
  final int? selectedDay;
  final int selectedYear;
  final List<String> monthNames;
  final VoidCallback onShowCalendarDialog;
  final VoidCallback onClearDaySelection;
  final Function(int) onMonthChanged;
  final Function(int) onYearChanged;
  // New props for filter
  final DateTimeRange? filterRange;
  final void Function()? onDateRangeSelected;
  final VoidCallback? onClearFilter;

  const DateSelectionCard({
    super.key,
    required this.selectedMonth,
    required this.selectedDay,
    required this.selectedYear,
    required this.monthNames,
    required this.onShowCalendarDialog,
    required this.onClearDaySelection,
    required this.onMonthChanged,
    required this.onYearChanged,
    this.filterRange,
    this.onDateRangeSelected,
    this.onClearFilter,
  });

  void _navigateMonth(int direction) {
    int newMonth = selectedMonth + direction;
    int newYear = selectedYear;

    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }

    onMonthChanged(newMonth);
    onYearChanged(newYear);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final String currentMonthRange = '${DateFormat('yyyy.MM.dd').format(firstDayOfMonth)} - ${DateFormat('yyyy.MM.dd').format(lastDayOfMonth)}';

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_alt_rounded, color: Color.fromARGB(255, 38, 102, 190)),
                  tooltip: 'Хугацааны интервал сонгох',
                  onPressed: onDateRangeSelected,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Хугацаа:',
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(width: 5),
              if (filterRange != null)
                Row(
                  children: [
                    Text(
                      '${DateFormat('yyyy.MM.dd').format(filterRange!.start)} - ${DateFormat('yyyy.MM.dd').format(filterRange!.end)}',
                      style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 15, color: Color(0xFF64748B)),
                      tooltip: 'Шүүлт цуцлах',
                      onPressed: onClearFilter,
                    ),
                  ],
                ),
              if (filterRange == null)
                Text(
                  currentMonthRange,
                  style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
            ],
          ),
          // Month navigation section
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous month button
                InkWell(
                  onTap: () => _navigateMonth(-1),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ),
                // Current month display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${monthNames[selectedMonth - 1]} $selectedYear',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Next month button
                InkWell(
                  onTap: () => _navigateMonth(1),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[600],
                      size: 20,
                    ),
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
