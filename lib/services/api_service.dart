import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_upload.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static void _checkConfigured() {
    if (!EnvConfig.isConfigured) {
      throw Exception(
        'API 未配置。请设置 API_BASE_URL（如 http://localhost:3000）',
      );
    }
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await ApiAuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// 根据 ISBN 查询书籍（可选，用于 API 查重）
  static Future<Book?> getBookByIsbn(String isbn) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/books?isbn=$Uri.encodeComponent(isbn)');
    final res = await http.get(uri, headers: await _headers(withAuth: false));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('查询失败: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Book(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['cover_url'] as String?,
      summary: json['summary'] as String?,
    );
  }

  /// 创建或更新书籍
  static Future<Book> upsertBook(BookLookupResult lookup) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/books');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'isbn': lookup.isbn,
        'title': lookup.title,
        'author': lookup.author,
        'cover_url': lookup.coverUrl,
        'summary': lookup.summary ?? Book.defaultSummary,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('保存失败: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Book(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['cover_url'] as String?,
      summary: json['summary'] as String?,
    );
  }

  /// 创建阅读记录
  static Future<void> createReadLog({
    required String bookId,
    String? audioUrl,
    String? transcript,
    String? aiFeedback,
    String? language,
    String sessionType = 'retelling',
  }) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/read-logs');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'book_id': bookId,
        'audio_url': audioUrl,
        'transcript': transcript,
        'ai_feedback': aiFeedback,
        'language': language,
        'session_type': sessionType,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('保存失败: ${res.body}');
    }
  }

  /// 更新阅读记录的 AI 点评
  static Future<void> updateReadLogAiFeedback(String logId, String aiFeedback) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/read-logs/$logId');
    final res = await http.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode({'ai_feedback': aiFeedback}),
    );
    if (res.statusCode != 200) {
      throw Exception('更新失败: ${res.body}');
    }
  }

  /// 上传音频文件，返回 URL（移动端/桌面端）
  static Future<String> uploadAudio(Object fileOrPath, {String contentType = 'audio/webm'}) async {
    return uploadAudioFile(fileOrPath, contentType: contentType);
  }
}
