import 'dart:convert';
import 'package:flutter/material.dart';

class TodayFoodsListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> todayFoods;
  final Function(Map<String, dynamic>) onFoodTap;

  const TodayFoodsListWidget({
    super.key,
    required this.todayFoods,
    required this.onFoodTap,
  });

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.restaurant, color: Colors.green),
                const SizedBox(width: 12),
                const Text(
                  'Өнөөдрийн хоол',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Text(
                  '${todayFoods.length} хоол',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (todayFoods.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Text(
                    'Өнөөдөр хоол нэмээгүй байна',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayFoods.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final food = todayFoods[index];
                return InkWell(
                  onTap: () => onFoodTap(food),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Food image or placeholder
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: food['image'] != null && food['image'].isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(food['image']),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.restaurant,
                                  color: Color(0xFFEF4444),
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Food details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food['name'] ?? 'Нэргүй хоол',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (food['description'] != null && food['description'].isNotEmpty)
                                Text(
                                  food['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (food['price'] != null)
                                Text(
                                  '₮ ${food['price']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF9CA3AF),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
