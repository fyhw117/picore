import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:picore/config/theme.dart';
import 'package:picore/services/post_service.dart';
import 'package:picore/services/storage_service.dart';
import 'package:picore/services/user_service.dart';
import 'package:picore/services/ai_scoring_service.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final StorageService _storageService = StorageService();
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final AiScoringService _aiScoringService =
      AiScoringService(); // Added AiScoringService

  XFile? _selectedImage;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _apiKeyController =
      TextEditingController(); // API Key Input
  bool _isLoading = false;
  String? _errorMessage;

  // デバッグ用: 毎回入力するのが面倒なので
  // static const String _debugApiKey = '';

  Future<void> _pickImage() async {
    try {
      final image = await _storageService.pickImage();
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = '画像の選択に失敗しました');
    }
  }

  Future<void> _uploadAndPost() async {
    if (_selectedImage == null) return;
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _errorMessage = 'Gemini APIキーを入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = _userService.currentUserId;
      if (uid == null) throw Exception('ログインが必要です');

      // 1. AI Scoring (並行して走らせてもいいが、スコア取得後に保存したい)
      final scoreResult = await _aiScoringService.scoreImage(
        _selectedImage!,
        apiKey: apiKey,
      );

      // 2. Upload Image
      final imageUrl = await _storageService.uploadPostImage(
        file: _selectedImage!,
        userId: uid,
      );

      // 3. Create Post Document with Score
      await _postService.createPost(
        uid: uid,
        imageUrl: imageUrl,
        description: _descriptionController.text.trim(),
        totalScore: scoreResult.totalScore,
        scoreDetails: scoreResult.scoreDetails,
        aiComment: scoreResult.comment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('採点完了！スコア: ${scoreResult.totalScore}点')),
        );
        Navigator.pop(context); // Go back to Home
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写真を投稿')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // API Key Input (本来は設定画面や環境変数で管理すべき)
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AI Studioで取得したAPIキーを入力',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // Image Preview Area
            GestureDetector(
              onTap: _isLoading ? null : _pickImage,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.royalBlue.withValues(alpha: 0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.network(
                                _selectedImage!.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                              ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 64,
                            color: AppColors.royalBlue.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '写真をタップして選択',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Description Input
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'コメント (任意)',
                hintText: '写真のポイントや撮影場所など',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Upload Button
            ElevatedButton(
              onPressed: (_selectedImage == null || _isLoading)
                  ? null
                  : _uploadAndPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined),
                        SizedBox(width: 8),
                        Text('採点を依頼する'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
