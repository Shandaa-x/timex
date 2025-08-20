import 'package:flutter/material.dart';
import 'package:timex/screens/time/time_track/widgets/time_utils.dart';

class WorkingHoursCard extends StatefulWidget {
  final DateTime startTime;
  final DateTime? endTime;
  final bool isWorking;
  final double totalWorkingHours; // Total accumulated hours for the day

  const WorkingHoursCard({
    super.key,
    required this.startTime,
    this.endTime,
    required this.isWorking,
    required this.totalWorkingHours,
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
                final currentSessionDuration = now.difference(widget.startTime);
                final currentSessionHours = currentSessionDuration.inMinutes / 60.0;
                final totalHoursWithCurrent = widget.totalWorkingHours + currentSessionHours;

                return Column(
                  children: [
                    Text(
                      TimeUtils.formatDuration(Duration(minutes: (totalHoursWithCurrent * 60).round())),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${totalHoursWithCurrent.toStringAsFixed(1)}ц',
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
              TimeUtils.formatDuration(Duration(minutes: (widget.totalWorkingHours * 60).round())),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.totalWorkingHours.toStringAsFixed(1)}ц',
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