import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class RecognitionResult {
  final List<String> tileCodes; // 例: ["1m","2m","0p",...]
  final String confidence; // "high" | "medium" | "low"
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

class ApiService {
  /// 画像(バイト列)とパスワードを送り、認識結果を取得する
  static Future<RecognitionResult> recognizeTiles({
    required List<int> imageBytes,
    required String mediaType, // "image/jpeg" 等
    required String password,
  }) async {
    final uri = Uri.parse(AppConfig.recognizeTilesEndpoint);
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-App-Password': password,
      },
      body: jsonEncode({
        'imageBase64': base64Encode(imageBytes),
        'mediaType': mediaType,
      }),
    );

    if (response.statusCode == 401) {
      throw ApiException('パスワードが正しくありません');
    }
    if (response.statusCode != 200) {
      throw ApiException('認識に失敗しました (status: ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RecognitionResult.fromJson(json);
  }
}
