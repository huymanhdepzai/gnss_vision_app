import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TelegramService {
  static String get _botToken => dotenv.env['FEEDBACK_BOT_TOKEN'] ?? '';
  static String get _chatId => dotenv.env['CHAT_ID'] ?? '';

  static Future<bool> sendFeedback({
    required int stars,
    required String comment,
    required String version,
  }) async {
    final String text = '''
      ĐÁNH GIÁ MỚI TỪ GNSS VISION
      Phiên bản: $version
      Đánh giá: $stars/5 sao
      Góp ý: ${comment.trim().isEmpty ? "_Không có bình luận_" : comment.trim()}
      ''';

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _chatId,
          'text': text,
          'parse_mode': 'Markdown',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi gửi Telegram Feedback: $e');
      return false;
    }
  }
}