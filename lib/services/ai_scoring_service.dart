import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class AiScoringResult {
  final int totalScore;
  final Map<String, dynamic> scoreDetails;
  final String comment;

  AiScoringResult({
    required this.totalScore,
    required this.scoreDetails,
    required this.comment,
  });

  factory AiScoringResult.fromJson(Map<String, dynamic> json) {
    return AiScoringResult(
      totalScore: json['total_score'] ?? 0,
      scoreDetails: json['details'] ?? {},
      comment: json['comment'] ?? '',
    );
  }
}

class AiScoringService {
  late final GenerativeModel _model;
  final String? _apiKey;

  AiScoringService({String? apiKey}) : _apiKey = apiKey;

  Future<AiScoringResult> scoreImage(XFile imageFile, {String? apiKey}) async {
    final key = apiKey ?? _apiKey ?? dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty || key == 'YOUR_API_KEY_HERE') {
      throw Exception('Gemini APIキーが必要です');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: key,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.4,
      ),
    );

    final imageBytes = await imageFile.readAsBytes();
    final content = [
      Content.multi([TextPart(_prompt), DataPart('image/jpeg', imageBytes)]),
    ];

    try {
      final response = await _model.generateContent(content);
      final text = response.text;

      if (text == null) throw Exception('Geminiからの応答が空でした');

      // JSONパース
      final json = jsonDecode(text) as Map<String, dynamic>;
      return AiScoringResult.fromJson(json);
    } catch (e) {
      throw Exception('AI採点に失敗しました: $e');
    }
  }

  static const String _prompt = '''
あなたはプロのフォトグラファー兼写真評論家です。
アップロードされた写真を、技術点と芸術点の両面から厳正に評価し、採点してください。
JSON形式で以下の情報を出力してください。

【評価基準】
- 構図 (composition): 30点満点
- 光と露出 (lighting): 30点満点
- 色彩とトーン (color): 20点満点
- 独創性とインパクト (originality): 20点満点
- 合計 (total_score): 100点満点

【出力フォーマット】
{
  "total_score": 85,
  "details": {
    "composition": 25,
    "lighting": 28,
    "color": 18,
    "originality": 14
  },
  "comment": "素晴らしい朝焼けですね。空のグラデーションが美しく捉えられています。手前のシルエットが少し重たいので、もう少しハイライトを入れても良かったかもしれません。"
}

※コメントは日本語で、100文字以内で、具体的かつ建設的なアドバイスを含めてください。
辛口すぎず、かつ褒めすぎず、投稿者のモチベーションが上がるようなトーンでお願いします。
''';
}
