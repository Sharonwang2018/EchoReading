import 'dart:convert';
import 'dart:typed_data';

import 'package:echo_reading/services/api_service.dart';
import 'package:http/http.dart' as http;

/// 非 Web：普通 [http.post]。
Future<Uint8List> fetchTtsMp3Bytes(String apiBaseUrl, String text) async {
  final base =
      apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
  final uri = Uri.parse('$base/api/tts');
  final headers = await ApiService.quotaHttpHeaders();
  final res = await http
      .post(
        uri,
        headers: headers,
        body: jsonEncode({'text': text}),
      )
      .timeout(const Duration(seconds: 95));
  if (res.statusCode != 200) {
    throw Exception('TTS 失败: ${ApiService.responseErrorMessage(res)}');
  }
  if (res.bodyBytes.isEmpty) {
    throw Exception('TTS 空响应');
  }
  return Uint8List.fromList(res.bodyBytes);
}
