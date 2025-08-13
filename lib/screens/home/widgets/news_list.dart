import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInteractionData();
  }

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _newsId => widget.news['id'] ?? '';

  Future<void> _loadInteractionData() async {
    if (_newsId.isEmpty || _currentUserId.isEmpty) return;

    try {
      // Load likes count and check if current user liked
      final likesSnapshot = await _firestore
          .collection('news')
          .doc(_newsId)
          .collection('likes')
          .get();

      final userLikeDoc = await _firestore
          .collection('news')
          .doc(_newsId)
          .collection('likes')
          .doc(_currentUserId)
          .get();

      // Load comments count
      final commentsSnapshot = await _firestore
          .collection('news')
          .doc(_newsId)
          .collection('comments')
          .get();

      if (mounted) {
        setState(() {
          _likesCount = likesSnapshot.docs.length;
          _isLiked = userLikeDoc.exists;
          _commentsCount = commentsSnapshot.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading interaction data: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_newsId.isEmpty || _currentUserId.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final likeRef = _firestore
          .collection('news')
          .doc(_newsId)
          .collection('likes')
          .doc(_currentUserId);

      if (_isLiked) {
        // Unlike
        await likeRef.delete();
        setState(() {
          _isLiked = false;
          _likesCount = (_likesCount - 1).clamp(0, double.infinity).toInt();
        });
      } else {
        // Like
        await likeRef.set({
          'userId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа гарлаа: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCommentsBottomSheet() async {
    if (_newsId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(newsId: _newsId),
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
    final authorName = widget.news['authorName'] as String? ?? widget.news['author'] as String? ?? 'Зэвэр нилээд';
    
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
          // Author header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2D5A27),
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category and source badges
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
                ],
              ],
            ),
          ),

          // Image (if available)
          if (imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
                right: Radius.circular(12),
              ),
              child: imageUrl.startsWith('data:') || imageUrl.length > 500
                  ? Image.memory(
                      base64Decode(imageUrl.contains(',') ? imageUrl.split(',')[1] : imageUrl),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        );
                      },
                    )
                  : Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),

          // Interaction buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Like button
                InkWell(
                  onTap: _isLoading ? null : _toggleLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: _isLiked ? Colors.red : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _likesCount.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: _isLiked ? Colors.red : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Comment button
                InkWell(
                  onTap: _showCommentsBottomSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.comment_outlined,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _commentsCount.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Source badge
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

class CommentsBottomSheet extends StatefulWidget {
  final String newsId;

  const CommentsBottomSheet({
    super.key,
    required this.newsId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _currentUserName => FirebaseAuth.instance.currentUser?.displayName ?? 'Зэвэр нилээд';

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    try {
      final commentsSnapshot = await _firestore
          .collection('news')
          .doc(widget.newsId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();

      setState(() {
        _comments = commentsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _isSubmitting || _currentUserId.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestore
          .collection('news')
          .doc(widget.newsId)
          .collection('comments')
          .add({
            'userId': _currentUserId,
            'userName': _currentUserName,
            'comment': _commentController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          });

      _commentController.clear();
      await _loadComments(); // Refresh comments
    } catch (e) {
      debugPrint('Error submitting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сэтгэгдэл илгээхэд алдаа гарлаа: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Text(
                  'Сэтгэгдэл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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

          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 48,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Одоогоор сэтгэгдэл байхгүй байна',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentCard(comment);
                        },
                      ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Сэтгэгдэл бичнэ үү...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF2D5A27)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D5A27),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSubmitting ? null : _submitComment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final userName = comment['userName'] as String? ?? 'Зэвэр нилээд';
    final commentText = comment['comment'] as String? ?? '';
    final timestamp = comment['timestamp'] as Timestamp?;

    String timeAgo = '';
    if (timestamp != null) {
      final now = DateTime.now();
      final commentDate = timestamp.toDate();
      final difference = now.difference(commentDate);

      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}ө';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}ц';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}м';
      } else {
        timeAgo = 'саяхан';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2D5A27),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
