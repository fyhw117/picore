import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String uid;
  final String imageUrl;
  final String description;
  final DateTime createdAt;

  // AI Scoring fields (nullable initially)
  final int? totalScore;
  final Map<String, dynamic>? scoreDetails; // e.g., {'composition': 30, ...}
  final String? aiComment;
  final bool isPublic;

  Post({
    required this.id,
    required this.uid,
    required this.imageUrl,
    this.description = '',
    required this.createdAt,
    this.totalScore,
    this.scoreDetails,
    this.aiComment,
    this.isPublic = false,
  });

  factory Post.fromMap(Map<String, dynamic> data, String id) {
    return Post(
      id: id,
      uid: data['uid'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalScore: data['totalScore'],
      scoreDetails: data['scoreDetails'],
      aiComment: data['aiComment'],
      isPublic: data['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt':
          FieldValue.serverTimestamp(), // Use server timestamp on create
      'totalScore': totalScore,
      'scoreDetails': scoreDetails,
      'aiComment': aiComment,
      'isPublic': isPublic,
    };
  }
}

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 投稿を作成
  Future<void> createPost({
    required String uid,
    required String imageUrl,
    String description = '',
    int? totalScore,
    Map<String, dynamic>? scoreDetails,
    String? aiComment,
  }) async {
    try {
      await _firestore.collection('posts').add({
        'uid': uid,
        'imageUrl': imageUrl,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': false,
        'totalScore': totalScore,
        'scoreDetails': scoreDetails,
        'aiComment': aiComment,
      });
    } catch (e) {
      throw Exception('投稿の作成に失敗しました: $e');
    }
  }

  // ユーザーの投稿履歴を取得
  Stream<List<Post>> getUserPosts(String uid) {
    return _firestore
        .collection('posts')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}
