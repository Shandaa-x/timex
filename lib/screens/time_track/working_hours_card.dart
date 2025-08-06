import 'package:flutter/material.dart';
import 'package:timex/screens/time_track/time_utils.dart';

class WorkingHoursCard extends StatefulWidget {
  final DateTime startTime;
  final DateTime? endTime;
  final bool isWorking;

  const WorkingHoursCard({
    super.key,
    required this.startTime,
    this.endTime,
    required this.isWorking,
  });

  @override
  State<WorkingHoursCard> createState() => _WorkingHoursCardState();
}

class _WorkingHoursCardState extends State<WorkingHoursCard> {
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _timeStream = Stream.periodic(
      const Duration(seconds: 1),
          (_) => DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Icons.schedule,
                color: widget.isWorking ? const Color(0xFF059669) : const Color(0xFF3B82F6),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                widget.isWorking ? 'Ажиллаж буй цаг' : 'Ажилласан цаг',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (widget.isWorking)
            StreamBuilder<DateTime>(
              stream: _timeStream,
              builder: (context, snapshot) {
                final now = snapshot.data ?? DateTime.now();
                final duration = now.difference(widget.startTime);
                final hours = TimeUtils.calculateWorkingHours(widget.startTime, now);

                return Column(
                  children: [
                    Text(
                      TimeUtils.formatDuration(duration),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${hours.toStringAsFixed(1)} цаг',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            )
          else if (widget.endTime != null) ...[
            Text(
              TimeUtils.formatDuration(widget.endTime!.difference(widget.startTime)),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${TimeUtils.calculateWorkingHours(widget.startTime, widget.endTime!).toStringAsFixed(1)} цаг',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}