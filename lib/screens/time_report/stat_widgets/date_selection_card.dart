import 'package:flutter/material.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
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
          // Single row layout for all dropdowns
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ModernDropdown<int>(
                  value: selectedMonth,
                  label: 'Сар',
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(monthNames[index]),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      onMonthChanged(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onShowCalendarDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Өдөр',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedDay == null ? 'Бүгд' : selectedDay.toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedDay != null)
                                GestureDetector(
                                  onTap: onClearDaySelection,
                                  child: const Icon(
                                    Icons.clear,
                                    color: Color(0xFF64748B),
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ModernDropdown<int>(
                  value: selectedYear,
                  label: 'Жил',
                  items: [2024, 2025, 2026].map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onYearChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
