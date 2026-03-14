import 'dart:io';

import 'package:whisper_kit/whisper_kit.dart';

bool get canUseLocal => Platform.isAndroid;

/// 本地转写，whisper_kit 推荐 WAV；m4a 可能失败则自动回退 API
Future<String?> transcribeWithLocal(String audioPath) async {
  try {
    final whisper = Whisper(model: WhisperModel.tiny);
    final request = TranscribeRequest(audio: audioPath, language: 'auto');
    final result = await whisper.transcribe(transcribeRequest: request);
    return result.text.trim();
  } catch (_) {
    return null;
  }
}
