import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String bio;
  final String? photoUrl;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.bio = '',
    this.photoUrl,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'bio': bio,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ユーザープロフィールの取得
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ユーザープロフィールの更新（なければ作成）
  Future<void> updateUserProfile({
    required String displayName,
    String bio = '',
    String? photoUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No user logged in');

    final data = {
      'displayName': displayName,
      'bio': bio,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      // set with merge: true to create if not exists
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      // Update Firebase Auth profile as well for easy access
      await _auth.currentUser?.updateDisplayName(displayName);
      if (photoUrl != null) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }
    } catch (e) {
      rethrow;
    }
  }
}
