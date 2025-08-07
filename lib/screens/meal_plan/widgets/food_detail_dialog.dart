import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';

class FoodDetailDialog extends StatefulWidget {
  final Map<String, dynamic> food;
  final String dateKey;
  final Function(Map<String, dynamic> updatedFood) onFoodUpdated;

  const FoodDetailDialog({
    super.key,
    required this.food,
    required this.dateKey,
    required this.onFoodUpdated,
  });

  @override
  State<FoodDetailDialog> createState() => _FoodDetailDialogState();
}

class _FoodDetailDialogState extends State<FoodDetailDialog> {
  final TextEditingController _commentController = TextEditingController();
  late Map<String, dynamic> _foodData;
  bool _isLoading = false;
  bool _isLiked = false;
  final String _currentUserId = 'user_123'; // Mock user ID - in real app, get from auth

  @override
  void initState() {
    super.initState();
    _foodData = Map<String, dynamic>.from(widget.food);
    _checkIfLiked();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _checkIfLiked() {
    final likes = _foodData['likes'] as List<dynamic>? ?? [];
    setState(() {
      _isLiked = likes.contains(_currentUserId);
    });
  }

  Future<void> _toggleLike() async {
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = '${widget.dateKey}-foods';
      final docRef = FirebaseFirestore.instance.collection('foods').doc(documentId);
      
      // Get current document
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }

      final data = docSnapshot.data()!;
      final foods = List<Map<String, dynamic>>.from(data['foods'] ?? []);
      
      // Find the food item by ID
      final foodIndex = foods.indexWhere((f) => f['id'] == _foodData['id']);
      if (foodIndex == -1) {
        throw Exception('Food item not found');
      }

      final currentFood = Map<String, dynamic>.from(foods[foodIndex]);
      final likes = List<String>.from(currentFood['likes'] ?? []);
      
      if (_isLiked) {
        // Remove like
        likes.remove(_currentUserId);
      } else {
        // Add like
        if (!likes.contains(_currentUserId)) {
          likes.add(_currentUserId);
        }
      }
      
      // Update the food item
      currentFood['likes'] = likes;
      currentFood['likesCount'] = likes.length;
      foods[foodIndex] = currentFood;
      
      // Update Firestore
      await docRef.update({
        'foods': foods,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _foodData = currentFood;
        _isLiked = !_isLiked;
      });
      
      widget.onFoodUpdated(_foodData);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = '${widget.dateKey}-foods';
      final docRef = FirebaseFirestore.instance.collection('foods').doc(documentId);
      
      // Get current document
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }

      final data = docSnapshot.data()!;
      final foods = List<Map<String, dynamic>>.from(data['foods'] ?? []);
      
      // Find the food item by ID
      final foodIndex = foods.indexWhere((f) => f['id'] == _foodData['id']);
      if (foodIndex == -1) {
        throw Exception('Food item not found');
      }

      final currentFood = Map<String, dynamic>.from(foods[foodIndex]);
      final comments = List<Map<String, dynamic>>.from(currentFood['comments'] ?? []);
      
      // Create new comment
      final newComment = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': _currentUserId,
        'userName': 'You', // In real app, get from user profile
        'text': commentText,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'likes': <String>[],
        'likesCount': 0,
      };
      
      comments.add(newComment);
      
      // Update the food item
      currentFood['comments'] = comments;
      currentFood['commentsCount'] = comments.length;
      foods[foodIndex] = currentFood;
      
      // Update Firestore
      await docRef.update({
        'foods': foods,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _foodData = currentFood;
        _commentController.clear();
      });
      
      widget.onFoodUpdated(_foodData);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    // Add haptic feedback
    HapticFeedback.selectionClick();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = '${widget.dateKey}-foods';
      final docRef = FirebaseFirestore.instance.collection('foods').doc(documentId);
      
      // Get current document
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }

      final data = docSnapshot.data()!;
      final foods = List<Map<String, dynamic>>.from(data['foods'] ?? []);
      
      // Find the food item by ID
      final foodIndex = foods.indexWhere((f) => f['id'] == _foodData['id']);
      if (foodIndex == -1) {
        throw Exception('Food item not found');
      }

      final currentFood = Map<String, dynamic>.from(foods[foodIndex]);
      final comments = List<Map<String, dynamic>>.from(currentFood['comments'] ?? []);
      
      // Find the comment by ID
      final commentIndex = comments.indexWhere((c) => c['id'] == commentId);
      if (commentIndex == -1) {
        throw Exception('Comment not found');
      }

      final currentComment = Map<String, dynamic>.from(comments[commentIndex]);
      final likes = List<String>.from(currentComment['likes'] ?? []);
      
      if (likes.contains(_currentUserId)) {
        // Remove like
        likes.remove(_currentUserId);
      } else {
        // Add like
        likes.add(_currentUserId);
      }
      
      // Update the comment
      currentComment['likes'] = likes;
      currentComment['likesCount'] = likes.length;
      comments[commentIndex] = currentComment;
      
      // Update the food item
      currentFood['comments'] = comments;
      foods[foodIndex] = currentFood;
      
      // Update Firestore
      await docRef.update({
        'foods': foods,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _foodData = currentFood;
      });
      
      widget.onFoodUpdated(_foodData);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating comment like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = List<Map<String, dynamic>>.from(_foodData['comments'] ?? []);
    final likesCount = _foodData['likesCount'] ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with food info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _foodData['name'] ?? 'Unknown Food',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: AppTheme.primaryLight,
                      ),
                    ],
                  ),
                  
                  if (_foodData['image'] != null && _foodData['image'].isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(_foodData['image'])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  
                  if (_foodData['description'] != null && _foodData['description'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _foodData['description'],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  
                  Row(
                    children: [
                      Text(
                        'Price: ₮${_foodData['price']}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successLight,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Like button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _toggleLike,
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                      label: Text(
                        _isLiked ? 'Liked' : 'Like',
                        style: TextStyle(
                          color: _isLiked ? Colors.red : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        elevation: 0,
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Comments section
            if (comments.isNotEmpty)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comments (${comments.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final isCommentLiked = (comment['likes'] as List<dynamic>? ?? [])
                                .contains(_currentUserId);
                            final commentLikes = comment['likesCount'] ?? 0;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: Text(
                                          (comment['userName'] as String? ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['userName'] ?? 'Unknown User',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              _formatCommentTime(comment['createdAt']),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment['text'] ?? '',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _toggleCommentLike(comment['id']),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isCommentLiked ? Icons.favorite : Icons.favorite_border,
                                              color: isCommentLiked ? Colors.red : Colors.grey,
                                              size: 16,
                                            ),
                                            if (commentLikes > 0) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '$commentLikes',
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Add comment section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryLight,
                    child: const Text(
                      'Y',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: AppTheme.primaryLight),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isLoading ? null : _addComment,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryLight,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: AppTheme.primaryLight,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCommentTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    final DateTime commentTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(commentTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
