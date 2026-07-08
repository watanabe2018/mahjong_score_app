import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class RecognitionResult {
  final List<String> tileCodes;
  final String confidence;
  final String notes;

  RecognitionResult({
    required this.tileCodes,
    required this.confidence,
    required this.notes,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      tileCodes: List<String>.from(json['tiles'] ?? []),
      confidence: json['confidence'] ?? 'medium',
      notes: json['notes'] ?? '',
    );
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

const String _recognitionPrompt = '''
あなたは麻雀の牌画像を認識するアシスタントです。
添付された麻雀の手牌の写真を見て、写っている牌をすべて識別してください。

出力は必ず次のJSON形式のみで返してください。説明文やコードブロックの記号(```)は一切含めないでください。

{
  "tiles": ["1m", "2m", "3m", "4p", "5p", "0p", "7s", "8s", "9s", "1z", "1z", "5z", "5z", "5z"],
  "confidence": "high" | "medium" | "low",
  "notes": "認識が難しかった点があれば日本語で簡潔に記載。無ければ空文字"
}

表記ルール:
- 萬子は m、筒子は p、索子は s、字牌は z を末尾に付ける (例: 3m, 7p, 2s)
- 字牌の数字: 1=東 2=南 3=西 4=北 5=白 6=發 7=中
- 赤ドラ(赤5)は通常の5ではなく "0" で表記する (例: 赤5萬なら "0m")
- 手牌に写っている枚数分だけ配列に入れる(通常13枚または和了後14枚)
- 牌の並び順は問わない
''';

class ApiService {
  /// 画像(バイト列)を直接Anthropic APIに送り、認識結果を取得する。
  /// [重要] APIキーはこの端末上(ブラウザ)から直接送信されます。config.dart参照。
  static Future<RecognitionResult> recognizeTiles({
    required List<int> imageBytes,
    required String mediaType, // "image/jpeg" 等
  }) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConfig.anthropicApiKey,
        'anthropic-version': '2023-06-01',
        // ブラウザから直接APIを呼ぶために必要なヘッダー
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': AppConfig.recognitionModel,
        'max_tokens': 2048,
        // 単純な認識タスクなので思考は最小限にし、テキスト出力のトークンを確保する
        'output_config': {'effort': 'low'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Encode(imageBytes),
                },
              },
              {'type': 'text', 'text': _recognitionPrompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 401) {
      throw ApiException('APIキーが正しくありません。config.dartを確認してください');
    }
    if (response.statusCode != 200) {
      throw ApiException('認識に失敗しました (status: ${response.statusCode}, body: ${response.body})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Anthropic APIがエラーオブジェクトを返した場合(200以外で弾かれなかった場合の保険)
    if (json['type'] == 'error') {
      final errMsg = json['error']?['message'] ?? response.body;
      throw ApiException('APIエラー: $errMsg');
    }

    final content = json['content'] as List<dynamic>? ?? [];
    final textBlock = content.firstWhere(
      (b) => b is Map && b['type'] == 'text',
      orElse: () => null,
    );
    if (textBlock == null) {
      // デバッグ用に生のレスポンスをそのまま表示する
      throw ApiException(
        '認識結果を取得できませんでした。\n'
        'stop_reason: ${json['stop_reason']}\n'
        'raw: ${response.body}',
      );
    }

    final rawText = textBlock['text'] as String;
    final cleaned = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return RecognitionResult.fromJson(parsed);
    } catch (_) {
      throw ApiException('認識結果の解析に失敗しました: $rawText');
    }
  }
}
