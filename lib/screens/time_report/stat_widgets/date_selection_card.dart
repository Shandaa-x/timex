import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'modern_dropdown.dart';
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final bool showCurrentMonth = filterRange == null;
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
              const SizedBox(width: 8),
              Text(
                'Хугацаа:',
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 5),
              if (filterRange != null)
                Row(
                  children: [
                    Text(
                      '${DateFormat('yyyy.MM.dd').format(filterRange!.start)} - ${DateFormat('yyyy.MM.dd').format(filterRange!.end)}',
                      style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
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
          // Single row layout for all dropdowns
          // Row(
          //   children: [
          //     Expanded(
          //       flex: 3,
          //       child: ModernDropdown<int>(
          //         value: selectedMonth,
          //         label: 'Сар',
          //         items: List.generate(12, (index) {
          //           return DropdownMenuItem(
          //             value: index + 1,
          //             child: Text(monthNames[index]),
          //           );
          //         }),
          //         onChanged: (value) {
          //           if (value != null) {
          //             onMonthChanged(value);
          //           }
          //         },
          //       ),
          //     ),
          //     const SizedBox(width: 8),
          //     Expanded(
          //       flex: 2,
          //       child: GestureDetector(
          //         onTap: onShowCalendarDialog,
          //         child: Container(
          //           decoration: BoxDecoration(
          //             color: const Color(0xFFF8FAFC),
          //             borderRadius: BorderRadius.circular(12),
          //             border: Border.all(
          //               color: const Color(0xFFE2E8F0),
          //             ),
          //           ),
          //           child: Padding(
          //             padding: const EdgeInsets.symmetric(
          //               horizontal: 16,
          //               vertical: 12,
          //             ),
          //             child: Row(
          //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //               children: [
          //                 Expanded(
          //                   child: Column(
          //                     crossAxisAlignment: CrossAxisAlignment.start,
          //                     children: [
          //                       const Text(
          //                         'Өдөр',
          //                         style: TextStyle(
          //                           color: Color(0xFF64748B),
          //                           fontWeight: FontWeight.w500,
          //                           fontSize: 12,
          //                         ),
          //                       ),
          //                       const SizedBox(height: 2),
          //                       Text(
          //                         selectedDay == null ? 'Бүгд' : selectedDay.toString(),
          //                         style: const TextStyle(
          //                           color: Color(0xFF1E293B),
          //                           fontWeight: FontWeight.w500,
          //                           fontSize: 16,
          //                         ),
          //                       ),
          //                     ],
          //                   ),
          //                 ),
          //                 Row(
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     if (selectedDay != null)
          //                       GestureDetector(
          //                         onTap: onClearDaySelection,
          //                         child: const Icon(
          //                           Icons.clear,
          //                           color: Color(0xFF64748B),
          //                           size: 18,
          //                         ),
          //                       ),
          //                   ],
          //                 ),
          //               ],
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(width: 8),
          //     Expanded(
          //       flex: 2,
          //       child: ModernDropdown<int>(
          //         value: selectedYear,
          //         label: 'Жил',
          //         items: [2024, 2025, 2026].map((year) {
          //           return DropdownMenuItem(
          //             value: year,
          //             child: Text(year.toString()),
          //           );
          //         }).toList(),
          //         onChanged: (value) {
          //           if (value != null) {
          //             onYearChanged(value);
          //           }
          //         },
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}
