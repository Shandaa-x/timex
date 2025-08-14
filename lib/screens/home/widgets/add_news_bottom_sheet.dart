import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class AddNewsBottomSheet extends StatefulWidget {
  final Function() onNewsAdded;

  const AddNewsBottomSheet({
    super.key,
    required this.onNewsAdded,
  });

  @override
  State<AddNewsBottomSheet> createState() => _AddNewsBottomSheetState();
}

class _AddNewsBottomSheetState extends State<AddNewsBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _excerptController = TextEditingController();
  
  String _selectedCategory = 'Business';
  bool _isLoading = false;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Business',
    'Technology',
    'Health',
    'Sports',
    'Entertainment',
    'Politics',
    'Science',
    'Education',
    'Travel',
    'Food',
    'Other'
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Зураг сонгоход алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveNews() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Нэвтрээгүй байна');
      }

      final now = DateTime.now();
      
      // Get user information
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data();
      final authorName = userData?['name'] ?? user.displayName ?? 'Нэргүй хэрэглэгч';
      final authorPhotoUrl = userData?['photoUrl'] ?? user.photoURL ?? '';
      
      final newsData = {
        'title': _titleController.text.trim(),
        'name': _titleController.text.trim(), // For compatibility
        'content': _contentController.text.trim(),
        'description': _contentController.text.trim(), // For compatibility
        'excerpt': _excerptController.text.trim().isNotEmpty 
            ? _excerptController.text.trim() 
            : _contentController.text.trim().substring(0, 
                _contentController.text.trim().length > 100 ? 100 : _contentController.text.trim().length),
        'category': _selectedCategory,
        'imageUrl': _base64Image ?? '',
        'authorId': user.uid,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'source': 'user',
        'isPublished': true,
        'likes': 0,
        'likedBy': [], // Array to store user IDs who liked
        'comments': 0,
        'readingTime': '${(_contentController.text.trim().split(' ').length / 200).ceil()} min read',
        'publishedAt': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to user's subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('news')
          .add(newsData);

      // Also save to public news collection for display
      await FirebaseFirestore.instance
          .collection('news')
          .add(newsData);

      widget.onNewsAdded();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Мэдээ амжилттай нэмэгдлээ! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Шинэ мэдээ нэмэх',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Гарчиг',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Гарчиг оруулна уу';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Ангилал',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Excerpt
                    TextFormField(
                      controller: _excerptController,
                      decoration: const InputDecoration(
                        labelText: 'Товч агуулга (заавал биш)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // Content
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Дэлгэрэнгүй агуулга',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Агуулга оруулна уу';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Image picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Зураг (заавал биш)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_base64Image != null) ...[
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_base64Image!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.edit),
                                label: const Text('Зураг солих'),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _base64Image = null;
                                  });
                                },
                                icon: const Icon(Icons.delete),
                                label: const Text('Устгах'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          InkWell(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Зураг нэмэх',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          
          // Save button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5A27),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Мэдээ нэмэх',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _excerptController.dispose();
    super.dispose();
  }
}
