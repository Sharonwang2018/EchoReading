import 'dart:async';
import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// 豆包流式语音识别（边说边识别）
/// 通过后端 WebSocket 代理连接豆包，需配置 DOUBAO_ASR_APPID, DOUBAO_ASR_TOKEN, DOUBAO_ASR_CLUSTER
class DoubaoStreamingAsrService {
  WebSocketChannel? _channel;

  /// 检查后端是否已配置流式识别
  Future<bool> get isConfigured async {
    try {
      final uri = Uri.parse('${EnvConfig.apiBaseUrl}/api/asr-stream-ready');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return json['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// 建立连接并返回识别结果 Stream
  /// [onText] 每次收到识别文字时回调（累计或分句）
  /// 返回 close 函数，调用后结束并关闭连接
  Future<Future<void> Function()> connect({
    required void Function(String text) onText,
    required void Function(Object error) onError,
    String language = 'zh',
  }) async {
    final base = EnvConfig.apiBaseUrl;
    if (base.isEmpty) {
      onError(Exception('API 未配置'));
      return () async {};
    }
    final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
    final uri = Uri.parse(base.replaceFirst(RegExp(r'^https?'), wsScheme));
    final wsUrl = '${wsScheme}://${uri.host}:${uri.port}/ws/asr-stream?lang=${language == 'en' ? 'en-US' : 'zh-CN'}';
    final streamUri = Uri.parse(wsUrl);

    try {
      _channel = WebSocketChannel.connect(streamUri);
    } catch (e) {
      onError(e);
      return () async {};
    }

    String fullText = '';
    final subscription = _channel!.stream.listen(
      (data) {
        if (data is String) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final type = json['type'] as String?;
            if (type == 'result') {
              final text = (json['text'] as String?)?.trim() ?? '';
              if (text.isNotEmpty) {
                fullText = text;
                onText(fullText);
              }
            } else if (type == 'error') {
              onError(Exception(json['message'] ?? '识别错误'));
            }
          } catch (_) {}
        }
      },
      onError: onError,
      onDone: () {},
    );

    return () async {
      await subscription.cancel();
      _channel?.sink.close();
    };
  }

  /// 发送音频数据
  void sendAudio(List<int> bytes) {
    _channel?.sink.add(bytes);
  }

  /// 发送结束标记
  void sendEnd() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'end'}));
    } catch (_) {}
  }
}
