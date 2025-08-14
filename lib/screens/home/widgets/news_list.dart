import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comments_bottom_sheet.dart';

class NewsList extends StatelessWidget {
  final List<Map<String, dynamic>> newsList;

  const NewsList({
    super.key,
    required this.newsList,
  });

  @override
  Widget build(BuildContext context) {
    if (newsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: const Center(
          child: Column(
            children: [
              Icon(
                Icons.article_outlined,
                size: 48,
                color: Color(0xFF6B7280),
              ),
              SizedBox(height: 16),
              Text(
                'Одоогоор мэдээ байхгүй байна',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: newsList.take(5).map((news) => NewsCard(news: news)).toList(),
    );
  }
}

class NewsCard extends StatefulWidget {
  final Map<String, dynamic> news;

  const NewsCard({
    super.key,
    required this.news,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  late int _likesCount;
  late int _commentsCount;
  late bool _isLiked;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.news['likes'] ?? 0;
    _commentsCount = widget.news['comments'] ?? 0;
    
    // Check if current user has liked this news
    final likedBy = widget.news['likedBy'] as List<dynamic>? ?? [];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isLiked = currentUserId != null && likedBy.contains(currentUserId);
  }

  @override
  void didUpdateWidget(NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update counts if the widget data changed
    if (oldWidget.news != widget.news) {
      _likesCount = widget.news['likes'] ?? 0;
      _commentsCount = widget.news['comments'] ?? 0;
      
      final likedBy = widget.news['likedBy'] as List<dynamic>? ?? [];
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      _isLiked = currentUserId != null && likedBy.contains(currentUserId);
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лайк дарахын тулд нэвтэрнэ үү'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLiking = true);

    try {
      // Determine which collection to update based on source_collection field
      final sourceCollection = widget.news['source_collection'] as String? ?? 'news';
      final newsRef = FirebaseFirestore.instance
          .collection(sourceCollection)
          .doc(widget.news['id']);

      if (_isLiked) {
        // Unlike
        await newsRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUser.uid]),
        });
        setState(() {
          _isLiked = false;
          _likesCount--;
        });
      } else {
        // Like
        await newsRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUser.uid]),
        });
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLiking = false);
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        newsId: widget.news['id'],
        sourceCollection: widget.news['source_collection'] as String? ?? 'news',
        currentCommentCount: _commentsCount,
        onCommentsUpdated: (newCount) {
          setState(() {
            _commentsCount = newCount;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishedAt = widget.news['publishedAt'] as Timestamp?;
    final name = widget.news['name'] as String? ?? widget.news['title'] as String? ?? 'Гарчиггүй';
    final description = widget.news['description'] as String? ?? widget.news['content'] as String? ?? 'Агуулгагүй';
    final source = widget.news['source'] as String? ?? 'unknown';
    final category = widget.news['category'] as String? ?? '';
    final imageUrl = widget.news['imageUrl'] as String? ?? '';
    final authorName = widget.news['authorName'] as String? ?? 'Үл мэдэгдэх зохиогч';
    final authorPhotoUrl = widget.news['authorPhotoUrl'] as String? ?? '';
    
    String timeAgo = 'Огноо тодорхойгүй';
    if (publishedAt != null) {
      final now = DateTime.now();
      final publishedDate = publishedAt.toDate();
      final difference = now.difference(publishedDate);
      
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} өдрийн өмнө';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} цагийн өмнө';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes} минутын өмнө';
      } else {
        timeAgo = 'Саяхан';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (if available)
          if (imageUrl.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl.startsWith('data:') || imageUrl.length > 500
                    ? Image.memory(
                        base64Decode(imageUrl.contains(',') ? imageUrl.split(',')[1] : imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, size: 50),
                          );
                        },
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, size: 50),
                          );
                        },
                      ),
              ),
            ),
          ],
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: authorPhotoUrl.isNotEmpty 
                          ? NetworkImage(authorPhotoUrl)
                          : null,
                      child: authorPhotoUrl.isEmpty 
                          ? Text(
                              authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getCategoryColor(category),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: source == 'global' 
                            ? const Color(0xFF3B82F6).withOpacity(0.1)
                            : const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        source == 'global' ? 'Ерөнхий' : 'Хувийн',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: source == 'global' 
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: _isLiking ? null : _toggleLike,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isLiked 
                              ? const Color(0xFFEF4444).withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isLiked 
                                ? const Color(0xFFEF4444).withOpacity(0.3)
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isLiking 
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _isLiked 
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF6B7280),
                                    ),
                                  )
                                : Icon(
                                    _isLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 16,
                                    color: _isLiked 
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF6B7280),
                                  ),
                            const SizedBox(width: 6),
                            Text(
                              _likesCount > 0 ? _likesCount.toString() : 'Лайк',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _isLiked 
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Comment button
                    GestureDetector(
                      onTap: _showComments,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.comment_outlined,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _commentsCount > 0 ? _commentsCount.toString() : 'Сэтгэгдэл',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Show like count if there are likes
                    if (_likesCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          '${_likesCount} хүн таалагдсан',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'business':
        return const Color(0xFF3B82F6);
      case 'technology':
        return const Color(0xFF8B5CF6);
      case 'health':
        return const Color(0xFF10B981);
      case 'sports':
        return const Color(0xFFEF4444);
      case 'entertainment':
        return const Color(0xFFF59E0B);
      case 'politics':
        return const Color(0xFF6B7280);
      case 'science':
        return const Color(0xFF06B6D4);
      case 'education':
        return const Color(0xFF84CC16);
      case 'travel':
        return const Color(0xFFEC4899);
      case 'food':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
