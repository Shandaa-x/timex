import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String newsId;
  final String sourceCollection;
  final int currentCommentCount;
  final Function(int) onCommentsUpdated;

  const CommentsBottomSheet({
    super.key,
    required this.newsId,
    required this.sourceCollection,
    required this.currentCommentCount,
    required this.onCommentsUpdated,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final commentsSnapshot = await _firestore
          .collection(widget.sourceCollection)
          .doc(widget.newsId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();

      setState(() {
        _comments = commentsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сэтгэгдэл ачаалахад алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Нэвтрээгүй байна');
      }

      // Get user information
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final authorName = userData?['name'] ?? user.displayName ?? 'Нэргүй хэрэглэгч';
      final authorPhotoUrl = userData?['photoUrl'] ?? user.photoURL ?? '';

      final commentData = {
        'text': _commentController.text.trim(),
        'authorId': user.uid,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add comment to subcollection
      await _firestore
          .collection(widget.sourceCollection)
          .doc(widget.newsId)
          .collection('comments')
          .add(commentData);

      // Update comment count in main news document
      await _firestore.collection(widget.sourceCollection).doc(widget.newsId).update({
        'comments': FieldValue.increment(1),
      });

      // Clear the input
      _commentController.clear();

      // Reload comments
      await _loadComments();

      // Update parent widget
      widget.onCommentsUpdated(_comments.length);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сэтгэгдэл нэмэгдлээ ✅'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Сэтгэгдэл',
                      style: const TextStyle(
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5A27).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2D5A27).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 16,
                        color: const Color(0xFF2D5A27),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_comments.length} сэтгэгдэл',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D5A27),
                        ),
                      ),
                      if (_comments.length > 0) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_comments.map((c) => c['authorId']).toSet().length} хүн',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
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
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Одоогоор сэтгэгдэл байхгүй байна',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Сэтгэгдэл бичих...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
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

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final authorName = comment['authorName'] ?? 'Нэргүй хэрэглэгч';
    final authorPhotoUrl = comment['authorPhotoUrl'] ?? '';
    final text = comment['text'] ?? '';
    final createdAt = comment['createdAt'] as Timestamp?;

    String timeAgo = 'Огноо тодорхойгүй';
    String fullDate = '';
    if (createdAt != null) {
      final now = DateTime.now();
      final commentTime = createdAt.toDate();
      final difference = now.difference(commentTime);

      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} өдрийн өмнө';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} цагийн өмнө';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes} минутын өмнө';
      } else {
        timeAgo = 'Саяхан';
      }

      // Format full date for tooltip
      fullDate = '${commentTime.year}/${commentTime.month.toString().padLeft(2, '0')}/${commentTime.day.toString().padLeft(2, '0')} ${commentTime.hour.toString().padLeft(2, '0')}:${commentTime.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author photo
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[300],
            backgroundImage: authorPhotoUrl.isNotEmpty
                ? NetworkImage(authorPhotoUrl)
                : null,
            child: authorPhotoUrl.isEmpty
                ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tooltip(
                      message: fullDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF374151),
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
