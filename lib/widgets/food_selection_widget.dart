import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../models/food_payment_models.dart';
import '../services/food_payment_service.dart';
import '../services/money_format.dart';

/// Widget for selecting and adding food items
class FoodSelectionWidget extends StatefulWidget {
  final Function(List<FoodItem>)? onFoodsAdded;
  final Function(FoodItem)? onFoodAdded;

  const FoodSelectionWidget({super.key, this.onFoodsAdded, this.onFoodAdded});

  @override
  State<FoodSelectionWidget> createState() => _FoodSelectionWidgetState();
}

class _FoodSelectionWidgetState extends State<FoodSelectionWidget> {
  final List<FoodItemBuilder> _foodBuilders = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addNewFoodBuilder();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addNewFoodBuilder() {
    setState(() {
      _foodBuilders.add(FoodItemBuilder());
    });
  }

  void _removeFoodBuilder(int index) {
    if (_foodBuilders.length > 1) {
      setState(() {
        _foodBuilders.removeAt(index);
      });
    }
  }

  Future<void> _saveFoodItems() async {
    // Validate all food items
    final validFoodItems = <FoodItem>[];

    for (final builder in _foodBuilders) {
      final foodItem = builder.buildFoodItem();
      if (foodItem != null) {
        validFoodItems.add(foodItem);
      }
    }

    if (validFoodItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one valid food item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await FoodPaymentService.addMultipleFoodItems(
        validFoodItems,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${validFoodItems.length} food items successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Notify parent widget
        if (widget.onFoodsAdded != null) {
          widget.onFoodsAdded!(validFoodItems);
        }

        // Notify parent widget for single food callback
        if (widget.onFoodAdded != null && validFoodItems.isNotEmpty) {
          widget.onFoodAdded!(validFoodItems.first);
        }

        // Clear the form
        setState(() {
          _foodBuilders.clear();
          _addNewFoodBuilder();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add food items'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Food Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              IconButton(
                onPressed: _addNewFoodBuilder,
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: 'Add another food item',
              ),
            ],
          ),
        ),

        // Food builders list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _foodBuilders.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: FoodItemCard(
                  builder: _foodBuilders[index],
                  canRemove: _foodBuilders.length > 1,
                  onRemove: () => _removeFoodBuilder(index),
                  onChanged: () => setState(() {}),
                ),
              );
            },
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addNewFoodBuilder,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Food'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveFoodItems,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Foods'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Individual food item card for building food items
class FoodItemCard extends StatefulWidget {
  final FoodItemBuilder builder;
  final bool canRemove;
  final VoidCallback? onRemove;
  final VoidCallback? onChanged;

  const FoodItemCard({
    super.key,
    required this.builder,
    this.canRemove = true,
    this.onRemove,
    this.onChanged,
  });

  @override
  State<FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<FoodItemCard> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          widget.builder.imageBase64 = base64String;
        });

        if (widget.onChanged != null) {
          widget.onChanged!();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with remove button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Food Item ${widget.builder.id.split('_').last}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.canRemove)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    iconSize: 20,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Image section
            Row(
              children: [
                // Image preview
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: widget.builder.imageBase64 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(widget.builder.imageBase64!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildImagePlaceholder();
                              },
                            ),
                          )
                        : _buildImagePlaceholder(),
                  ),
                ),

                const SizedBox(width: 16),

                // Image actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Food Image',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: Text(
                          widget.builder.imageBase64 != null
                              ? 'Change Photo'
                              : 'Take Photo',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      if (widget.builder.imageBase64 != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              widget.builder.imageBase64 = null;
                            });
                            if (widget.onChanged != null) {
                              widget.onChanged!();
                            }
                          },
                          child: const Text('Remove Photo'),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Food name input
            TextFormField(
              initialValue: widget.builder.name,
              decoration: const InputDecoration(
                labelText: 'Food Name',
                hintText: 'e.g., Beef Burger, Caesar Salad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant),
              ),
              onChanged: (value) {
                widget.builder.name = value;
                if (widget.onChanged != null) {
                  widget.onChanged!();
                }
              },
            ),

            const SizedBox(height: 16),

            // Food price input
            TextFormField(
              initialValue: widget.builder.price > 0
                  ? widget.builder.price.toStringAsFixed(0)
                  : '',
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: 'Enter price in tugrik',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: '₮',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                widget.builder.price = double.tryParse(value) ?? 0.0;
                if (widget.onChanged != null) {
                  widget.onChanged!();
                }
              },
            ),

            const SizedBox(height: 16),

            // Validation status
            Row(
              children: [
                Icon(
                  widget.builder.isValid ? Icons.check_circle : Icons.error,
                  color: widget.builder.isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.builder.isValid
                      ? 'Ready to save'
                      : 'Please fill all fields',
                  style: TextStyle(
                    color: widget.builder.isValid ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.builder.price > 0)
                  Expanded(
                    child: Text(
                      ' • ${MoneyFormatService.formatWithSymbol(widget.builder.price.toInt())}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, color: Colors.grey[600], size: 24),
        const SizedBox(height: 4),
        Text(
          'Tap to\nadd photo',
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Builder class for creating food items
class FoodItemBuilder {
  late String id;
  String name = '';
  double price = 0.0;
  String? imageBase64;
  DateTime selectedDate = DateTime.now();

  FoodItemBuilder() {
    id =
        'food_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }

  bool get isValid => name.trim().isNotEmpty && price > 0;

  FoodItem? buildFoodItem() {
    if (!isValid) return null;

    return FoodItem(
      id: id,
      name: name.trim(),
      price: price,
      imageBase64: imageBase64,
      selectedDate: selectedDate,
      paidAmount: 0.0,
      remainingBalance: price,
      status: FoodPaymentStatus.unpaid,
      paymentHistory: [],
    );
  }
}
