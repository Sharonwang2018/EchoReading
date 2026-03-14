import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:echo_reading/services/doubao_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// 拍照读页 TTS：优先豆包云端，失败时自动降级为设备 TTS，确保一定能读出
class PageTtsService {
  final DoubaoService _doubao = DoubaoService();
  final AudioPlayer _player = AudioPlayer();
  FlutterTts? _flutterTts;

  FlutterTts get _tts => _flutterTts ??= FlutterTts();

  /// 朗读文本，优先豆包，失败则用设备 TTS。返回 Future 在朗读结束时完成。
  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      final audioBytes = await _doubao.textToSpeech(t);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/page_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(audioBytes);
      final completer = Completer<void>();
      late final StreamSubscription sub;
      sub = _player.onPlayerComplete.listen((_) {
        sub.cancel();
        completer.complete();
      });
      await _player.play(DeviceFileSource(file.path));
      await completer.future;
    } catch (_) {
      await _fallbackSpeak(t);
    }
  }

  /// 设备 TTS 兜底（无需任何 API，确保一定能读）
  Future<void> _fallbackSpeak(String text) async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
