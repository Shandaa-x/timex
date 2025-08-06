import 'package:flutter/material.dart';
import 'package:timex/screens/time_track/time_utils.dart';
import 'package:timex/screens/time_track/work_day.dart';
import 'holiday_utils.dart';

class StatusCard extends StatelessWidget {
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isWorking;
  final WorkDay? todayData;

  const StatusCard({
    super.key,
    this.startTime,
    this.endTime,
    required this.isWorking,
    this.todayData,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isHoliday = HolidayUtils.isHoliday(now);
    final holidayName = HolidayUtils.getHolidayName(now);

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHoliday ? Icons.celebration : Icons.work,
                color: isHoliday ? const Color(0xFFEAB308) : const Color(0xFF3B82F6),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Өнөөдрийн мэдээлэл',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Holiday Status
          if (isHoliday)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEAB308)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: Color(0xFFEAB308), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      holidayName ?? 'Амралтын өдөр',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (isHoliday) const SizedBox(height: 16),

          // Work Info
          _buildInfoRow('Өдөр:', '${now.day}'),
          _buildInfoRow('Сар:', '${now.month}'),
          _buildInfoRow('Жил:', '${now.year}'),
          _buildInfoRow('Долоо хоног:', '${TimeUtils.getWeekNumber(now)}'),

          if (startTime != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow('Ирсэн цаг:', TimeUtils.formatTime(startTime!)),
            if (endTime != null)
              _buildInfoRow('Явсан цаг:', TimeUtils.formatTime(endTime!)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}