import 'package:flutter/material.dart';

class ScheduleInfoWidget extends StatelessWidget {
  final bool isWorking;
  final DateTime? scheduledEndTime;

  const ScheduleInfoWidget({
    super.key,
    required this.isWorking,
    this.scheduledEndTime,
  });

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!isWorking || scheduledEndTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final timeLeft = scheduledEndTime!.difference(now);

    if (timeLeft.isNegative) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ажлын цаг дууссан байна! Ажлаа дуусгаарай.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Ажлын цагийн хуваарь',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Дуусах цаг: ${_formatTime(scheduledEndTime!)}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Text(
            'Үлдсэн хугацаа: ${timeLeft.inHours}:${(timeLeft.inMinutes % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
