import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // kIsWeb を使うため

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // 画像を選択してアップロードし、ダウンロードURLを返す
  Future<String?> uploadProfileImage(String userId) async {
    try {
      // 1. 画像を選択
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // アイコン用なので小さくてOK
        maxHeight: 512,
        imageQuality: 70, // 容量節約
      );

      if (image == null) return null;

      // 2. アップロード先のパスを設定 (users/{uid}/profile.jpg)
      final Reference ref = _storage.ref().child('users/$userId/profile.jpg');

      // 3. アップロード
      if (kIsWeb) {
        await ref.putData(await image.readAsBytes());
      } else {
        await ref.putFile(File(image.path));
      }

      // 4. ダウンロードURLを取得して返す
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('画像のアップロードに失敗しました: $e');
    }
  }

  // 汎用的な画像選択
  Future<XFile?> pickImage() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024, // 投稿用は少し大きめ
      maxHeight: 1024,
      imageQuality: 80,
    );
  }

  // 投稿画像のアップロード
  Future<String> uploadPostImage({
    required XFile file,
    required String userId,
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('posts/$userId/$fileName');

      if (kIsWeb) {
        await ref.putData(await file.readAsBytes());
      } else {
        await ref.putFile(File(file.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('画像のアップロードに失敗しました: $e');
    }
  }
}
