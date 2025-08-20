import 'package:flutter/material.dart';
import 'modern_card.dart';

class WeekSelectorCard extends StatelessWidget {
  final List<int> weekNumbers;
  final int? selectedWeekNumber;
  final Function(int?) onWeekSelected;

  const WeekSelectorCard({
    super.key,
    required this.weekNumbers,
    required this.selectedWeekNumber,
    required this.onWeekSelected,
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
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.view_week_rounded, color: Color(0xFF8B5CF6), size: 20),
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
              _buildWeekChip('Бүгд', selectedWeekNumber == null, () {
                onWeekSelected(null);
              }),
              ...weekNumbers.map<Widget>((weekNum) {
                return _buildWeekChip(weekNum.toString(), selectedWeekNumber == weekNum, () {
                  onWeekSelected(weekNum);
                });
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
          border: Border.all(color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0)),
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
}