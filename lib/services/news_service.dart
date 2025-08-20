import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/my_news/widgets/news_model.dart';

class NewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference
  CollectionReference get _newsCollection => _firestore.collection('news');

  // Create news
  Future<String?> createNews({
    required String title,
    required String content,
    String? imageUrl,
    String? category,
    String? description,
    String? excerpt,
    bool isPublished = false,
    String? readingTime,
    String? source,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final user = _auth.currentUser;
      final now = DateTime.now();
      final news = NewsModel(
        title: title,
        content: content,
        userId: currentUserId!,
        createdAt: now,
        updatedAt: now,
        imageUrl: imageUrl,
        authorId: currentUserId!,
        authorName: user?.displayName ?? 'Unknown User',
        authorPhotoUrl: user?.photoURL ?? '',
        category: category ?? '',
        description: description ?? '',
        excerpt: excerpt ?? '',
        isPublished: isPublished,
        publishedAt: isPublished ? now : DateTime.now(),
        readingTime: readingTime ?? '',
        source: source ?? '',
      );

      final docRef = await _newsCollection.add(news.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating news: $e');
      return null;
    }
  }

  // Get user's news with optional month filter
  Stream<List<NewsModel>> getUserNews({DateTime? filterMonth}) {
    if (currentUserId == null) {
      print('❌ User not authenticated');
      return Stream.value([]);
    }

    print('✅ Loading news for user: $currentUserId');
    
    // Query both userId and authorId fields and combine results
    final userIdStream = _getUserNewsByField('userId', filterMonth);
    final authorIdStream = _getUserNewsByField('authorId', filterMonth);
    
    return userIdStream.asyncMap((userIdResults) async {
      final authorIdResults = await authorIdStream.first;
      
      // Combine results and remove duplicates by document ID
      final allResults = <String, NewsModel>{};
      
      for (final news in userIdResults) {
        if (news.id != null) allResults[news.id!] = news;
      }
      
      for (final news in authorIdResults) {
        if (news.id != null) allResults[news.id!] = news;
      }
      
      final combinedList = allResults.values.toList();
      combinedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('📝 Returning ${combinedList.length} combined news items');
      return combinedList;
    });
  }

  Stream<List<NewsModel>> _getUserNewsByField(String field, DateTime? filterMonth) {
    Query query = _newsCollection.where(field, isEqualTo: currentUserId);

    if (filterMonth != null) {
      final startOfMonth = DateTime(filterMonth.year, filterMonth.month, 1);
      final endOfMonth = DateTime(filterMonth.year, filterMonth.month + 1, 1);

      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth));
    }

    return query.snapshots().map((snapshot) {
      print('📰 Found ${snapshot.docs.length} news documents for field: $field');
      
      // Sort in memory to avoid index requirement
      final newsList = snapshot.docs.map((doc) {
        return NewsModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      return newsList;
    });
  }

  // Update news
  Future<bool> updateNews({
    required String newsId,
    required String title,
    required String content,
    String? imageUrl,
    String? category,
    String? description,
    String? excerpt,
    bool? isPublished,
    String? readingTime,
    String? source,
  }) async {
    try {
      final updateData = {
        'title': title,
        'content': content,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (category != null) updateData['category'] = category;
      if (description != null) updateData['description'] = description;
      if (excerpt != null) updateData['excerpt'] = excerpt;
      if (isPublished != null) {
        updateData['isPublished'] = isPublished;
        if (isPublished) {
          updateData['publishedAt'] = Timestamp.fromDate(DateTime.now());
        }
      }
      if (readingTime != null) updateData['readingTime'] = readingTime;
      if (source != null) updateData['source'] = source;

      await _newsCollection.doc(newsId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating news: $e');
      return false;
    }
  }

  // Delete news
  Future<bool> deleteNews(String newsId) async {
    try {
      await _newsCollection.doc(newsId).delete();
      return true;
    } catch (e) {
      print('Error deleting news: $e');
      return false;
    }
  }

  // Get news by ID
  Future<NewsModel?> getNewsById(String newsId) async {
    try {
      final doc = await _newsCollection.doc(newsId).get();
      if (doc.exists) {
        return NewsModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting news: $e');
      return null;
    }
  }

  // Toggle like for news
  Future<bool> toggleLike(String newsId) async {
    try {
      if (currentUserId == null) return false;

      final doc = await _newsCollection.doc(newsId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final likes = data['likes'] ?? 0;

      if (likedBy.contains(currentUserId)) {
        // Unlike
        likedBy.remove(currentUserId);
        await _newsCollection.doc(newsId).update({
          'likedBy': likedBy,
          'likes': likes - 1,
        });
      } else {
        // Like
        likedBy.add(currentUserId!);
        await _newsCollection.doc(newsId).update({
          'likedBy': likedBy,
          'likes': likes + 1,
        });
      }
      return true;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  // Increment comment count
  Future<bool> incrementCommentCount(String newsId) async {
    try {
      final doc = await _newsCollection.doc(newsId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final comments = data['comments'] ?? 0;

      await _newsCollection.doc(newsId).update({
        'comments': comments + 1,
      });
      return true;
    } catch (e) {
      print('Error incrementing comment count: $e');
      return false;
    }
  }
}
