import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/doubao_service.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/utils/recording_path.dart';
import 'package:echo_reading/utils/upload_audio.dart';
import 'package:echo_reading/services/page_tts_service.dart';
import 'package:echo_reading/services/transcription_service.dart';
import 'package:echo_reading/services/doubao_streaming_asr_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final _doubao = DoubaoService();
final _transcriptionService = TranscriptionService();
const _audioBucket = 'read-audios';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.bookId,
    required this.summary,
    this.language,
  });

  final String bookId;
  final String summary;
  final String? language;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioRecorder _streamRecorder = AudioRecorder(); // 用于边说边识别
  final PageTtsService _ttsService = PageTtsService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final DoubaoStreamingAsrService _streamingAsr = DoubaoStreamingAsrService();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _streamSubscription;
  Timer? _recordingTimer;
  String _speechTranscript = '';
  Future<void> Function()? _closeStreamingAsr;

  List<String> _questions = const [];
  List<double> _waveBars = List<double>.filled(20, 0.1);

  String? _audioPath;
  String? _transcript;
  String _language = 'zh';

  bool _loadingQuestions = true;
  bool _recording = false;
  bool _processing = false;
  bool _usedOpusEncoder = false;

  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _language = widget.language ?? 'zh';
    _loadGuideQuestions();
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _streamSubscription?.cancel();
    _recordingTimer?.cancel();
    _closeStreamingAsr?.call();
    try {
      _speech.stop();
    } catch (_) {}
    _recorder.dispose();
    _streamRecorder.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  List<String> _defaultQuestionsFor(String lang) {
    switch (lang) {
      case 'en':
        return const [
          'Who impressed you most in the story?',
          'What happened at the beginning?',
          'What would you do if you were in the story?',
        ];
      case 'mixed':
        return const [
          '故事里谁最让你印象深刻？Who impressed you most?',
          '故事开始发生了什么？What happened at the start?',
          '如果你在故事里会怎么做？What would you do?',
        ];
      default:
        return const [
          '故事里最让你印象深刻的是谁？',
          '故事开始发生了什么事情？',
          '如果你在故事里，你会怎么做？',
        ];
    }
  }

  Future<void> _loadGuideQuestions() async {
    setState(() {
      _loadingQuestions = true;
    });

    try {
      final result = await _askDoubaoForQuestions(widget.summary, _language);
      if (!mounted) return;
      setState(() {
        _questions = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _questions = _defaultQuestionsFor(_language);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 提问获取失败，已使用默认问题：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingQuestions = false;
        });
      }
    }
  }

  Future<List<String>> _askDoubaoForQuestions(String summary, String lang) async {
    final (langHint, outputHint) = switch (lang) {
      'en' => (
          'Generate 3 simple guiding questions in English for a 5-year-old to retell the story.',
          'Return JSON: {"questions":["Q1","Q2","Q3"]}',
        ),
      'mixed' => (
          'Generate 3 simple guiding questions in Chinese-English mix (中英混合) for a 5-year-old.',
          'Return JSON: {"questions":["问题1/Q1","问题2/Q2","问题3/Q3"]}',
        ),
      _ => (
          '给 5 岁孩子提 3 个简单的中文启发性问题，引导他复述故事。',
          '返回 JSON: {"questions":["问题1","问题2","问题3"]}',
        ),
    };

    final content = await _doubao.chatCompletion(
      messages: [
        {'role': 'system', 'content': 'You are a children\'s reading guide. Output must be simple, gentle, suitable for ages 3-8.'},
        {
          'role': 'user',
          'content':
              '''
Based on this book summary, $langHint

Book summary:
$summary

$outputHint
''',
        },
      ],
      temperature: 0.6,
      jsonMode: true,
    );

    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final list = (parsed['questions'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();

    if (list.length < 3) {
      throw Exception('豆包返回问题数量不足 3 条');
    }
    return list;
  }

  Future<void> _startRecording() async {
    if (_recording || _processing) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先授予麦克风权限')));
        return;
      }

      final filePath = getRecordingPath();
      // Web 用 Opus（豆包支持 OGG OPUS），移动端用 AAC
      final config = kIsWeb
          ? const RecordConfig(
              encoder: AudioEncoder.opus,
              bitRate: 128000,
              sampleRate: 48000,
            )
          : const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            );

      final encoderSupported =
          await _recorder.isEncoderSupported(config.encoder);
      final effectiveConfig = encoderSupported
          ? config
          : const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            );

      await _recorder.start(effectiveConfig, path: filePath);
      _usedOpusEncoder = effectiveConfig.encoder == AudioEncoder.opus;

      _speechTranscript = '';
      bool useDoubaoStream = false;
      if (kIsWeb && await _streamingAsr.isConfigured) {
        try {
          final pcmSupported = await _streamRecorder.isEncoderSupported(AudioEncoder.pcm16bits);
          if (pcmSupported) {
            _closeStreamingAsr = await _streamingAsr.connect(
              onText: (t) {
                if (mounted && _recording) setState(() => _speechTranscript = t);
              },
              onError: (_) {},
              language: _language,
            );
            final stream = await _streamRecorder.startStream(const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
            ));
            _streamSubscription = stream.listen((chunk) {
              _streamingAsr.sendAudio(chunk);
            });
            useDoubaoStream = true;
          }
        } catch (_) {}
      }
      if (!useDoubaoStream && kIsWeb) {
        try {
          final ok = await _speech.initialize();
          if (ok) {
            _speech.listen(
              onResult: (r) {
                if (mounted && _recording) {
                  setState(() => _speechTranscript = r.recognizedWords);
                }
              },
              localeId: _language == 'zh' ? 'zh_CN' : (_language == 'en' ? 'en_US' : null),
              listenOptions: stt.SpeechListenOptions(partialResults: true),
            );
          }
        } catch (_) {}
      }

      _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
          final normalized = ((amp.current + 45) / 45).clamp(0.05, 1.0);
          setState(() {
            _waveBars = [..._waveBars.skip(1), normalized];
          });
        });

    _recordingTimer?.cancel();
    _seconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds += 1;
      });
    });

    setState(() {
      _audioPath = null;
      _transcript = null;
      _recording = true;
    });
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音启动失败：$e')),
      );
      debugPrint('_startRecording error: $e\n$st');
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    if (!_recording || _processing) return;

    setState(() {
      _processing = true;
    });

    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _streamSubscription?.cancel();
    _streamingAsr.sendEnd();
    await _closeStreamingAsr?.call();
    if (_streamSubscription != null) {
      await _streamRecorder.stop();
    }
    if (kIsWeb) {
      try {
        await _speech.stop();
      } catch (_) {}
    }

    final path = await _recorder.stop();
    setState(() {
      _recording = false;
      _audioPath = path;
    });

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _processing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('录音失败，请重试')));
      return;
    }

    try {
      final isRealUser = EnvConfig.isConfigured && await _hasCloudBaseUser();
      String transcript = _speechTranscript.trim();

      if (transcript.isEmpty) {
        try {
          if (isRealUser) {
            final audioUrl = await _uploadToCloudBase(path);
            transcript = await _transcriptionService.transcribe(
              audioUrl: audioUrl,
              audioPath: path,
            );
            await _saveReadLog(audioUrl: audioUrl, transcript: transcript);
          } else {
            transcript = await _transcribeWithoutLogin(path);
          }
        } catch (e) {
          transcript = '';
          if (isRealUser) {
            final audioUrl = await _uploadToCloudBase(path);
            await _saveReadLog(audioUrl: audioUrl, transcript: transcript);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('识别未完成，录音已保存。')),
              );
            }
          }
        }
      } else if (isRealUser) {
        final audioUrl = await _uploadToCloudBase(path);
        await _saveReadLog(audioUrl: audioUrl, transcript: transcript);
      }

      if (!mounted) return;
      setState(() {
        _transcript = transcript;
        _processing = false; // 立即结束「处理中」，不等待 TTS
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRealUser ? 'Hi-Doo！你讲得真棒！' : 'Hi-Doo！你讲得真棒！登录后可保存到阅读日记',
          ),
        ),
      );
      // TTS 后台播放，不阻塞按钮恢复
      unawaited(
        _ttsService.speak('Hi-Doo！你讲得真棒！').catchError((_) {}),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<String> _transcribeWithoutLogin(String pathOrBlobUrl) async {
    return _transcriptionService.transcribe(
      audioUrl: null,
      audioPath: pathOrBlobUrl,
    );
  }

  Future<bool> _hasCloudBaseUser() async {
    try {
      final userInfo = await ApiAuthService.getUserInfo();
      return userInfo != null && userInfo.uuid.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _uploadToCloudBase(String pathOrBlobUrl) async {
    final userInfo = await ApiAuthService.getUserInfo();
    if (userInfo == null) throw Exception('请先登录。');
    final uid = userInfo.uuid;
    if (uid.isEmpty) {
      throw Exception('请先登录。');
    }

    final ext = _usedOpusEncoder ? 'webm' : 'm4a';
    final objectPath =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}.$ext';

    return uploadAudioToCloudBase(
      pathOrBlobUrl,
      _audioBucket,
      objectPath,
      contentType: _usedOpusEncoder ? 'audio/webm' : 'audio/mp4',
    );
  }

  Future<void> _saveReadLog({
    required String audioUrl,
    required String transcript,
  }) async {
    final userInfo = await ApiAuthService.getUserInfo();
    if (userInfo == null || userInfo.uuid.isEmpty) {
      throw Exception('请先登录。');
    }

    await ApiService.createReadLog(
      bookId: widget.bookId,
      audioUrl: audioUrl,
      transcript: transcript,
      sessionType: 'retelling',
      language: _language,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 引导复述')),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('本次复述语言', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'zh', label: Text('中文')),
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'mixed', label: Text('中英混合')),
                ],
                selected: {_language},
                onSelectionChanged: (s) {
                  final newLang = s.single;
                  setState(() => _language = newLang);
                  _loadGuideQuestions();
                },
              ),
              const SizedBox(height: 16),
              _QuestionCard(loading: _loadingQuestions, questions: _questions),
              const SizedBox(height: 16),
              _WaveformCard(
                isRecording: _recording,
                bars: _waveBars,
                elapsedSeconds: _seconds,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _processing
                    ? null
                    : _recording
                    ? _stopRecordingAndProcess
                    : _startRecording,
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(
                  _processing
                      ? '处理中...'
                      : _recording
                      ? '结束录音'
                      : '开始录音',
                ),
              ),
              const SizedBox(height: 12),
              if (_recording && kIsWeb) ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '边说边识别',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_speechTranscript.isEmpty ? '聆听中...' : _speechTranscript),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_audioPath != null)
                Text(
                  '录音文件：$_audioPath',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_transcript != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '识别结果',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_transcript!),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.loading, required this.questions});

  final bool loading;
  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: loading
            ? const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('AI 正在生成引导问题...'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 引导问题',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < questions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${i + 1}. ${questions[i]}'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _WaveformCard extends StatelessWidget {
  const _WaveformCard({
    required this.isRecording,
    required this.bars,
    required this.elapsedSeconds,
  });

  final bool isRecording;
  final List<double> bars;
  final int elapsedSeconds;

  String get _timeLabel {
    final minute = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final second = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: isRecording
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(isRecording ? '正在录音 $_timeLabel' : '等待开始录音'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final value in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          height: 10 + (value * 52),
                          decoration: BoxDecoration(
                            color: isRecording
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
