import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/money_format.dart';

class FoodEatenStatusWidget extends StatefulWidget {
  final List<Map<String, dynamic>> todayFoods;
  final bool eatenForDay;
  final String dateString;
  final Function() onStatusChanged;

  const FoodEatenStatusWidget({
    super.key,
    required this.todayFoods,
    required this.eatenForDay,
    required this.dateString,
    required this.onStatusChanged,
  });

  @override
  State<FoodEatenStatusWidget> createState() => _FoodEatenStatusWidgetState();
}

class _FoodEatenStatusWidgetState extends State<FoodEatenStatusWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUpdating = false;

  Future<void> _showEatenConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Баталгаажуулах'),
            ],
          ),
          content: const Text(
            'Та өнөөдөр хоол идсэн гэж баталгаажуулж байна уу?\n\n⚠️ Анхааруулга: Нэгэнт идсэн гэж тэмдэглэсний дараа буцааж өөрчлөх боломжгүй!',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Цуцлах',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Тийм, идсэн'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateEatenStatus(true);
    }
  }

  Future<void> _updateEatenStatus(bool eaten) async {
    setState(() => _isUpdating = true);

    try {
      // Update the calendarDays document
      await _firestore
          .collection('calendarDays')
          .doc(widget.dateString)
          .update({
        'eatenForDay': eaten,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onStatusChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              eaten 
                ? 'Хоол идсэн гэж тэмдэглэлээ ✅' 
                : 'Хоол идээгүй гэж тэмдэглэлээ',
            ),
            backgroundColor: eaten ? Colors.green : Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  int get _totalFoodPrice {
    return widget.todayFoods.fold<int>(
      0, 
      (total, food) => total + (food['price'] as int? ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.todayFoods.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.no_meals, color: Colors.grey),
            SizedBox(width: 12),
            Text(
              'Өнөөдөр хоол бүртгэгдээгүй байна',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
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
          // Header with food count and total price
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.eatenForDay ? Colors.green[50] : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.eatenForDay ? Icons.check_circle : Icons.info_outline,
                  color: widget.eatenForDay ? Colors.green : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eatenForDay 
                          ? 'Өнөөдөр хоол идсэн ✅'
                          : 'Өнөөдөр хоол идээгүй',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.eatenForDay ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${widget.todayFoods.length} хоол • ${MoneyFormatService.formatWithSymbol(_totalFoodPrice)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.eatenForDay ? Colors.green[600] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Food list
          ...widget.todayFoods.map((food) => _buildFoodItem(food)),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: widget.eatenForDay 
              ? // Show confirmation message when already eaten
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Хоол идсэн гэж баталгаажуулсан ✅\nБуцааж өөрчлөх боломжгүй',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : // Show buttons when not eaten yet
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUpdating 
                          ? null 
                          : _showEatenConfirmationDialog,
                        icon: _isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                        label: const Text('Идсэн'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  void _showFoodDetailDialog(Map<String, dynamic> food) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Хоолны дэлгэрэнгүй',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                
                // Food image (larger)
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: food['image'] != null && food['image'].isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              base64Decode(food['image']),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.fastfood, size: 48, color: Colors.grey);
                              },
                            ),
                          )
                        : const Icon(Icons.fastfood, size: 48, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Food details
                _buildDetailRow('Нэр', food['name'] ?? 'Unknown Food', Icons.restaurant),
                const SizedBox(height: 16),
                
                if (food['description'] != null && food['description'].isNotEmpty) ...[
                  _buildDetailRow('Тайлбар', food['description'], Icons.description),
                  const SizedBox(height: 16),
                ],
                
                _buildDetailRow('Үнэ', MoneyFormatService.formatWithSymbol(food['price'] ?? 0), Icons.monetization_on),
                const SizedBox(height: 16),
                
                if (food['category'] != null && food['category'].isNotEmpty) ...[
                  _buildDetailRow('Ангилал', food['category'], Icons.category),
                  const SizedBox(height: 16),
                ],
                
                if (food['timestamp'] != null) ...[
                  _buildDetailRow(
                    'Бүртгэсэн цаг', 
                    _formatTimestamp(food['timestamp']), 
                    Icons.access_time,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Status indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.eatenForDay ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.eatenForDay ? Colors.green[200]! : Colors.orange[200]!
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.eatenForDay ? Icons.check_circle : Icons.schedule,
                        color: widget.eatenForDay ? Colors.green[700] : Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.eatenForDay ? 'Идсэн хоол' : 'Идээгүй хоол',
                        style: TextStyle(
                          color: widget.eatenForDay ? Colors.green[700] : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Хаах',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }
      
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildFoodItem(Map<String, dynamic> food) {
    return GestureDetector(
      onTap: () => _showFoodDetailDialog(food),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            // Food image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: food['image'] != null && food['image'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(food['image']),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.fastfood, color: Colors.grey);
                        },
                      ),
                    )
                  : const Icon(Icons.fastfood, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            
            // Food details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['name'] ?? 'Unknown Food',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (food['description'] != null && food['description'].isNotEmpty)
                    Text(
                      food['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // Price and tap indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MoneyFormatService.formatWithSymbol(food['price'] ?? 0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.eatenForDay ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
