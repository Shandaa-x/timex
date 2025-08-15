import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String? id;
  final String title;
  final String content;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  
  // Additional fields from Firestore structure
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String category;
  final int comments;
  final String description;
  final String excerpt;
  final bool isPublished;
  final List<String> likedBy;
  final int likes;
  final String name;
  final DateTime publishedAt;
  final String readingTime;
  final String source;

  NewsModel({
    this.id,
    required this.title,
    required this.content,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.authorId = '',
    this.authorName = '',
    this.authorPhotoUrl = '',
    this.category = '',
    this.comments = 0,
    this.description = '',
    this.excerpt = '',
    this.isPublished = false,
    this.likedBy = const [],
    this.likes = 0,
    this.name = '',
    DateTime? publishedAt,
    this.readingTime = '',
    this.source = '',
  }) : publishedAt = publishedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'imageUrl': imageUrl,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'category': category,
      'comments': comments,
      'description': description,
      'excerpt': excerpt,
      'isPublished': isPublished,
      'likedBy': likedBy,
      'likes': likes,
      'name': name,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'readingTime': readingTime,
      'source': source,
    };
  }

  factory NewsModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NewsModel(
      id: documentId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      category: map['category'] ?? '',
      comments: map['comments'] ?? 0,
      description: map['description'] ?? '',
      excerpt: map['excerpt'] ?? '',
      isPublished: map['isPublished'] ?? false,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      likes: map['likes'] ?? 0,
      name: map['name'] ?? '',
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readingTime: map['readingTime'] ?? '',
      source: map['source'] ?? '',
    );
  }

  NewsModel copyWith({
    String? id,
    String? title,
    String? content,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? category,
    int? comments,
    String? description,
    String? excerpt,
    bool? isPublished,
    List<String>? likedBy,
    int? likes,
    String? name,
    DateTime? publishedAt,
    String? readingTime,
    String? source,
  }) {
    return NewsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      category: category ?? this.category,
      comments: comments ?? this.comments,
      description: description ?? this.description,
      excerpt: excerpt ?? this.excerpt,
      isPublished: isPublished ?? this.isPublished,
      likedBy: likedBy ?? this.likedBy,
      likes: likes ?? this.likes,
      name: name ?? this.name,
      publishedAt: publishedAt ?? this.publishedAt,
      readingTime: readingTime ?? this.readingTime,
      source: source ?? this.source,
    );
  }
}
