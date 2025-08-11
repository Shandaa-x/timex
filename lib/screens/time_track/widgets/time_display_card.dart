import 'package:flutter/material.dart';
import 'package:timex/screens/time_track/widgets/time_utils.dart';

class TimeDisplayCard extends StatefulWidget {
  final bool isWorking;

  const TimeDisplayCard({super.key, required this.isWorking});

  @override
  State<TimeDisplayCard> createState() => _TimeDisplayCardState();
}

class _TimeDisplayCardState extends State<TimeDisplayCard> {
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isWorking
              ? [const Color(0xFF059669), const Color(0xFF047857)]
              : [Colors.red, Colors.red],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (widget.isWorking
                        ? const Color(0xFF059669)
                        : const Color(0xFF3B82F6))
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: StreamBuilder<DateTime>(
        stream: _timeStream,
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();

          return Column(
            children: [
              // Current Time
              Text(
                TimeUtils.formatTime(now),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),

              const SizedBox(height: 8),

              // Date and Day
              Text(
                '${TimeUtils.getWeekdayName(now.weekday)}, ${now.day} ${TimeUtils.getMonthName(now.month)} ${now.year}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.isWorking ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isWorking ? 'Ажил хийж байна' : 'Ажилд ороогүй',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
