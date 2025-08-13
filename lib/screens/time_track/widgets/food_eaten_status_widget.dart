import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  // Track selected foods
  Map<int, bool> _selectedFoods = {};

  @override
  void initState() {
    super.initState();
    _initializeFoodSelections();
  }

  @override
  void didUpdateWidget(FoodEatenStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todayFoods != oldWidget.todayFoods) {
      _initializeFoodSelections();
    }
  }

  void _initializeFoodSelections() {
    _selectedFoods.clear();
    
    for (int i = 0; i < widget.todayFoods.length; i++) {
      _selectedFoods[i] = false;
    }
  }

  // Helper to get current user ID
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  // Calculate total price of selected foods
  int get _selectedTotalPrice {
    int total = 0;
    for (int i = 0; i < widget.todayFoods.length; i++) {
      if (_selectedFoods[i] == true) {
        final price = widget.todayFoods[i]['price'] ?? 0;
        total += (price as int);
      }
    }
    return total;
  }

  // Get list of selected foods
  List<Map<String, dynamic>> get _selectedFoodsList {
    List<Map<String, dynamic>> selectedList = [];
    for (int i = 0; i < widget.todayFoods.length; i++) {
      if (_selectedFoods[i] == true) {
        final food = Map<String, dynamic>.from(widget.todayFoods[i]);
        selectedList.add(food);
      }
    }
    return selectedList;
  }

  Future<void> _showEatenConfirmationDialog() async {
    final selectedFoods = _selectedFoodsList;
    
    if (selectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Хоол сонгоно уу'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Сонгосон хоолоо идсэн гэж баталгаажуулах'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Сонгосон хоол: ${selectedFoods.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...selectedFoods.map((food) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${food['name']} = ${MoneyFormatService.formatWithSymbol(food['price'] ?? 0)}',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
              const SizedBox(height: 8),
              Text(
                'Нийт дүн: ${MoneyFormatService.formatWithSymbol(_selectedTotalPrice)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Анхааруулга: Нэгэнт идсэн гэж тэмдэглэсний дараа буцааж өөрчлөх боломжгүй!',
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Цуцлах', style: TextStyle(color: Colors.grey)),
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
      await _saveSelectedFoodsToEatens();
    }
  }
  Future<void> _saveSelectedFoodsToEatens() async {
    setState(() => _isUpdating = true);

    try {
      // Check if calendarDays document exists
      final docRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(widget.dateString);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Та ажлын ирцээ бүртгүүлээгүй байна'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
        }
        setState(() => _isUpdating = false);
        return;
      }

      final selectedFoods = _selectedFoodsList;
      final totalPrice = _selectedTotalPrice;

      // Update the calendarDays document
      await docRef.update({
        'eatenForDay': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save selected foods to eatens subcollection
      final now = DateTime.now();
      final eatenData = {
        'date': widget.dateString,
        'totalPrice': totalPrice,
        'foodCount': selectedFoods.length,
        'foods': selectedFoods,
        'eatenAt': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to eatens subcollection
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('eatens')
          .doc(widget.dateString)
          .set(eatenData);

      // Update users collection with totalFoodAmount
      await _firestore
          .collection('users')
          .doc(_userId)
          .update({
            'totalFoodAmount': FieldValue.increment(totalPrice),
            'lastFoodUpdate': FieldValue.serverTimestamp(),
          });

      widget.onStatusChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Сонгосон хоол хадгалагдлаа ✅ (${MoneyFormatService.formatWithSymbol(totalPrice)})',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving selected foods: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  int get _totalFoodPrice {
    return widget.todayFoods.fold<int>(
      0,
      (total, food) => total + ((food['price'] ?? 0) as int),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food, int index) {
    final isSelected = _selectedFoods[index] ?? false;
    final price = food['price'] ?? 0;

    return GestureDetector(
      onTap: () => _showFoodDetailDialog(food),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
          color: isSelected ? Colors.green[50] : Colors.white,
        ),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: widget.eatenForDay ? null : (bool? value) {
                setState(() {
                  _selectedFoods[index] = value ?? false;
                });
              },
              activeColor: Colors.green,
            ),
            
            // Food image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: food['image'] != null && food['image'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(food['image']),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.restaurant, color: Colors.grey);
                        },
                      ),
                    )
                  : const Icon(Icons.restaurant, color: Colors.grey),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (food['description'] != null && food['description'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        food['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormatService.formatWithSymbol(price),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Show selection indicator or tap indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ] else ...[
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                ],
              ],
            ),
          ],
        ),
      ),
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
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                          color: widget.eatenForDay
                              ? Colors.green[700]
                              : Colors.grey[700],
                        ),
                      ),
                      if (!widget.eatenForDay && _selectedFoodsList.isNotEmpty) ...[
                        Text(
                          'Сонгосон: ${_selectedFoodsList.length} хоол • ${MoneyFormatService.formatWithSymbol(_selectedTotalPrice)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      Text(
                        'Нийт: ${widget.todayFoods.length} хоол • ${MoneyFormatService.formatWithSymbol(_totalFoodPrice)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.eatenForDay
                              ? Colors.green[600]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selected foods summary (only show when foods are selected and not eaten yet)
          if (!widget.eatenForDay && _selectedFoodsList.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_cart, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Сонгосон хоол (${_selectedFoodsList.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._selectedFoodsList.map((food) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${food['name']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          MoneyFormatService.formatWithSymbol(food['price']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  )),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Нийт дүн:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        MoneyFormatService.formatWithSymbol(_selectedTotalPrice),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Food list
          ...widget.todayFoods.asMap().entries.map((entry) => _buildFoodItem(entry.value, entry.key)),

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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                                return const Icon(
                                  Icons.fastfood,
                                  size: 48,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.fastfood,
                            size: 48,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Food details
                _buildDetailRow(
                  'Нэр',
                  food['name'] ?? 'Unknown Food',
                  Icons.restaurant,
                ),
                const SizedBox(height: 16),

                if (food['description'] != null &&
                    food['description'].isNotEmpty) ...[
                  _buildDetailRow(
                    'Тайлбар',
                    food['description'],
                    Icons.description,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildDetailRow(
                  'Үнэ',
                  MoneyFormatService.formatWithSymbol(food['price'] ?? 0),
                  Icons.monetization_on,
                ),
                const SizedBox(height: 16),

                if (food['category'] != null &&
                    food['category'].isNotEmpty) ...[
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
                    color: widget.eatenForDay
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.eatenForDay
                          ? Colors.green[200]!
                          : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.eatenForDay
                            ? Icons.check_circle
                            : Icons.schedule,
                        color: widget.eatenForDay
                            ? Colors.green[700]
                            : Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.eatenForDay ? 'Идсэн хоол' : 'Идээгүй хоол',
                        style: TextStyle(
                          color: widget.eatenForDay
                              ? Colors.green[700]
                              : Colors.orange[700],
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
}
