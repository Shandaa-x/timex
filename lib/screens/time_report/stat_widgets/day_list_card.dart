import 'dart:convert';
import 'package:flutter/material.dart';
import 'modern_card.dart';

class DaysListCard extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final int selectedMonth;
  final Set<String> confirmingDays;
  final Set<String> expandedDays;
  final Map<String, List<String>> selectedImages;
  final bool isTablet;
  final Function(String) onConfirmDay;
  final Function(String) onToggleExpand;
  final Function(String) onPickImage;
  final Function(String, int) onRemoveSelectedImage;
  final Function(String, Map<String, dynamic>)? onImageTap; // New parameter for navigation
  final Map<String, bool>? eatenForDayData; // New parameter for food eaten status

  const DaysListCard({
    super.key,
    required this.weeklyData,
    required this.selectedMonth,
    required this.confirmingDays,
    required this.expandedDays,
    required this.selectedImages,
    required this.isTablet,
    required this.onConfirmDay,
    required this.onToggleExpand,
    required this.onPickImage,
    required this.onRemoveSelectedImage,
    this.onImageTap, // New optional parameter
    this.eatenForDayData, // New optional parameter for food status
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.list_alt_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ажилласан өдрүүд',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Check if we have data
          if (weeklyData.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Сонгосон хугацаанд мэдээлэл олдсонгүй',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Өөр сар эсвэл жил сонгоно уу',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ...weeklyData.asMap().entries.map((entry) {
              final index = entry.key;
              final dayData = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index == weeklyData.length - 1 ? 0 : 12),
                child: _buildDayItem(dayData),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildDayItem(Map<String, dynamic> dayData) {
    final isConfirmed = dayData['confirmed'] ?? false;
    final workingHours = dayData['workingHours']?.toDouble() ?? 0.0;
    final isHoliday = dayData['isHoliday'] ?? false;
    final day = dayData['day'] ?? 0;
    final dateString = dayData['date'] ?? '';
    final isExpanded = expandedDays.contains(dateString);
    final attachmentImages = List<String>.from(dayData['attachmentImages'] ?? []);

    // For confirmed days, don't show selected images (they should be moved to attachmentImages)
    final selectedImagesForDay = isConfirmed ? <String>[] : (selectedImages[dateString] ?? []);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isConfirmed ? const Color(0xFFFEFCE8) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConfirmed ? const Color(0xFFEAB308) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Main row (always visible)
          InkWell(
            onTap: () => onToggleExpand(dateString),
            child: Row(
              children: [
                // Date Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isConfirmed ? const Color(0xFFEAB308) : const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$selectedMonth/$day',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Hours
                Text(
                  '${workingHours.toStringAsFixed(1)}ц',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),

                const Spacer(),

                // Status Badge
                _buildStatusBadge(isHoliday, workingHours, isConfirmed, dateString, dayData),

                // Food eaten status for confirmed days
                if (isConfirmed && eatenForDayData != null) ...[
                  const SizedBox(width: 8),
                  _buildFoodStatusBadge(dateString),
                ],

                const SizedBox(width: 8),

                // Expand Icon
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Icons.keyboard_arrow_right,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      if (!isConfirmed)
                        TextButton.icon(
                          onPressed: () => onPickImage(dateString),
                          icon: const Icon(Icons.add_photo_alternate, size: 16),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selected Images (not yet uploaded) - Only show for unconfirmed days
                  if (!isConfirmed && selectedImagesForDay.isNotEmpty) ...[
                    const Text(
                      'Selected (pending upload):',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: selectedImagesForDay.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(selectedImagesForDay[index]),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.error),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => onRemoveSelectedImage(dateString, index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Uploaded Images - Show for all days that have attachment images
                  if (attachmentImages.isNotEmpty) ...[
                    // Only show "Uploaded:" label if there were selected images above
                    if (!isConfirmed && selectedImagesForDay.isNotEmpty)
                      const Text(
                        'Uploaded:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (!isConfirmed && selectedImagesForDay.isNotEmpty) const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: attachmentImages.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Navigate to day info screen when image is tapped
                            if (onImageTap != null) {
                              onImageTap!(dateString, dayData);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(attachmentImages[index]),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.error),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // No images message - Only show when there are truly no images
                  if (attachmentImages.isEmpty && selectedImagesForDay.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No images',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isHoliday, double workingHours, bool isConfirmed, String dateString, Map<String, dynamic> dayData) {
    if (isHoliday) {
      return _buildBadge('Баяр', const Color(0xFFFB923C), const Color(0xFFFED7AA), () {});
    } else if (isConfirmed) {
      return _buildBadge('Батлагдсан', const Color(0xFF10B981), const Color(0xFFD1FAE5), () {});
    } else {
      return _buildConfirmButton(dateString, dayData);
    }
  }

  Widget _buildBadge(String text, Color color, Color backgroundColor, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(String dateString, Map<String, dynamic> dayData) {
    final isConfirming = confirmingDays.contains(dateString);
    final workingHours = dayData['workingHours']?.toDouble() ?? 0.0;
    final hasWorkEnded = dayData['hasWorkEnded'] ?? false;
    
    // Check if work day has ended (has working hours AND work was actually completed)
    final isDisabled = workingHours <= 0.0 || !hasWorkEnded;
    final isInteractionDisabled = isConfirming || isDisabled;

    return GestureDetector(
      onTap: isInteractionDisabled ? null : () => onConfirmDay(dateString),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDisabled 
              ? const Color(0xFF9CA3AF) // Gray when disabled
              : isConfirming 
                  ? const Color(0xFF64748B) 
                  : const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConfirming) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              isDisabled 
                  ? 'Ажил дуусаагүй' 
                  : isConfirming 
                      ? 'Батлаж байна...' 
                      : 'Батлах',
              style: TextStyle(
                fontSize: 12,
                color: isDisabled ? Colors.white70 : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodStatusBadge(String dateString) {
    final eatenForDay = eatenForDayData?[dateString] ?? false;
    
    // Only show badge if food was eaten
    if (!eatenForDay) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.restaurant,
            size: 12,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}