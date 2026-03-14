import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:echo_reading/services/doubao_service.dart';
import 'package:echo_reading/utils/audio_reader.dart';
import 'transcription_service_platform.dart';

/// 录音转写：豆包 ASR 优先（有公网 URL 时用标准版，否则极速版），Android 本地 Whisper 备选
class TranscriptionService {
  final _doubao = DoubaoService();

  /// 转写：audioUrl 用于已上传的音频（公网 URL 时优先标准版），audioPath 为 blob URL 或本地路径
  Future<String> transcribe({String? audioUrl, required String audioPath}) async {
    // 1. 豆包 ASR：有公网 URL 时优先标准版，否则极速版（base64）
    String? doubaoError;
    final hasPublicUrl = audioUrl != null &&
        audioUrl.isNotEmpty &&
        (audioUrl.startsWith('http://') || audioUrl.startsWith('https://'));

    if (hasPublicUrl) {
      try {
        return await _doubao.speechToText(audioUrl: audioUrl);
      } catch (e) {
        doubaoError = e.toString();
      }
    }

    final bytes = await _getAudioBytes(audioUrl: audioUrl, audioPath: audioPath);
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final base64 = base64Encode(bytes);
        return await _doubao.speechToText(audioBase64: base64);
      } catch (e) {
        doubaoError ??= e.toString();
        // 豆包失败，继续本地备选
      }
    }

    // 2. Android 本地 Whisper
    if (canUseLocal) {
      final result = await transcribeWithLocal(audioPath);
      if (result != null && result.trim().isNotEmpty) {
        return result;
      }
    }

    final hint = doubaoError != null
        ? '豆包 ASR 报错：$doubaoError。'
        : '请确认已配置 DOUBAO_ASR_APPID、DOUBAO_ASR_ACCESS_KEY，'
            '且豆包语音控制台已开通「录音文件识别大模型」标准版或极速版。';
    throw Exception('识别失败。$hint Web 端建议使用 Opus 录制。');
  }

  Future<List<int>?> _getAudioBytes({
    String? audioUrl,
    required String audioPath,
  }) async {
    final url = audioUrl ??
        ((audioPath.startsWith('http://') ||
                audioPath.startsWith('https://') ||
                audioPath.startsWith('blob:'))
            ? audioPath
            : null);

    if (url != null) {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
    }

    if (!audioPath.startsWith('http') && !audioPath.startsWith('blob:')) {
      return readAudioBytes(audioPath);
    }

    return null;
  }
}
