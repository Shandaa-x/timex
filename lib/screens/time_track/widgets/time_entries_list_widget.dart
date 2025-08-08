import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeEntriesListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> todayEntries;
  final Function(Map<String, dynamic>) onLocationTap;

  const TimeEntriesListWidget({
    super.key,
    required this.todayEntries,
    required this.onLocationTap,
  });

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (todayEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF6B7280)),
            SizedBox(width: 12),
            Text(
              'Өнөөдөр ямар ч орсон гарсан байхгүй байна',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
              maxLines: 3,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                const Text(
                  'Өнөөдрийн орсон гарсан',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayEntries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = todayEntries[index];
              final timestamp = (entry['timestamp'] as Timestamp).toDate();
              final isCheckIn = entry['type'] == 'check_in';
              final location = entry['location'] as Map<String, dynamic>?;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCheckIn
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isCheckIn ? Icons.login : Icons.logout,
                        color: isCheckIn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCheckIn ? 'Ирлээ' : 'Явлаа',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            _formatTime(timestamp),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          if (location != null)
                            Text(
                              'GPS: ${location['latitude'].toStringAsFixed(4)}, ${location['longitude'].toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onLocationTap(location),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
