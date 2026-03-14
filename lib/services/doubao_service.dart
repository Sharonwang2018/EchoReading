import 'dart:convert';

import 'package:http/http.dart' as http;

/// 豆包 API 服务：图片识别（火山方舟视觉）+ 语音合成（豆包语音）+ 文本对话（Chat）
/// 支持一个 API Key 调用多服务：DOUBAO_API_KEY / ARK_API_KEY 同时用于视觉、TTS、Chat
/// model 支持：Endpoint ID (ep-xxx) 或 模型 ID (如 doubao-seed-2-0-mini-260215)
const _apiKey = String.fromEnvironment('DOUBAO_API_KEY');
const _arkApiKey = String.fromEnvironment('DOUBAO_ARK_API_KEY');
const _arkApiKeyAlt = String.fromEnvironment('ARK_API_KEY');
const _arkEndpointId = String.fromEnvironment('DOUBAO_ARK_ENDPOINT_ID');
const _arkModelId = String.fromEnvironment('DOUBAO_ARK_MODEL');
const _ttsAppId = String.fromEnvironment('DOUBAO_TTS_APPID');
const _ttsToken = String.fromEnvironment('DOUBAO_TTS_TOKEN');
const _ttsCluster = String.fromEnvironment('DOUBAO_TTS_CLUSTER');
const _asrAppId = String.fromEnvironment('DOUBAO_ASR_APPID');
const _asrAccessKey = String.fromEnvironment('DOUBAO_ASR_ACCESS_KEY');

const _arkBaseUrl = 'https://ark.cn-beijing.volces.com';
const _ttsBaseUrl = 'https://openspeech.bytedance.com';
const _asrBaseUrl = 'https://openspeech.bytedance.com';

String get _visionApiKey =>
    _apiKey.isNotEmpty ? _apiKey : (_arkApiKey.isNotEmpty ? _arkApiKey : _arkApiKeyAlt);

String get _visionModel =>
    _arkModelId.isNotEmpty ? _arkModelId : _arkEndpointId;

class DoubaoService {
  /// 从图片中识别并提取文字（适合朗读的阅读顺序）
  /// 兼容 Python SDK 格式：model 可用 doubao-seed-2-0-mini-260215
  Future<String> extractTextFromImage(String imageBase64) async {
    if (_visionApiKey.isEmpty || _visionModel.isEmpty) {
      throw Exception(
        '请配置 DOUBAO_API_KEY（或 ARK_API_KEY）和 DOUBAO_ARK_ENDPOINT_ID（或 DOUBAO_ARK_MODEL）',
      );
    }

    final imageDataUrl = 'data:image/jpeg;base64,$imageBase64';
    final uri = Uri.parse('$_arkBaseUrl/api/v3/responses');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_visionApiKey',
      },
      body: jsonEncode({
        'model': _visionModel,
        'input': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_image',
                'image_url': imageDataUrl,
              },
              {
                'type': 'input_text',
                'text': '请识别并提取图片中的全部文字内容，按阅读顺序逐行输出，适合朗读。'
                    '只输出纯文字，不要加任何说明或标点以外的内容。',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('豆包视觉识别失败(${response.statusCode})：${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final output = data['output'] as List<dynamic>? ?? [];
    String text = '';
    for (var i = output.length - 1; i >= 0; i--) {
      final item = output[i] as Map<String, dynamic>?;
      if (item?['type'] == 'message') {
        final content = item!['content'] as List<dynamic>? ?? [];
        for (final c in content) {
          final t = (c as Map<String, dynamic>?)?['text'] as String?;
          if (t != null && t.isNotEmpty) {
            text = t.trim();
            break;
          }
        }
        if (text.isNotEmpty) break;
      }
    }
    if (text.isEmpty) {
      throw Exception('未识别到文字内容');
    }
    return text;
  }

  /// 文本转语音，返回 MP3 字节
  /// 若豆包支持一个 key 调用 TTS，可只配 DOUBAO_API_KEY；否则需 TTS 专用参数
  Future<List<int>> textToSpeech(String text) async {
    final useUnifiedKey = _apiKey.isNotEmpty &&
        (_ttsAppId.isEmpty || _ttsToken.isEmpty || _ttsCluster.isEmpty);
    final useTtsParams = _ttsAppId.isNotEmpty && _ttsToken.isNotEmpty && _ttsCluster.isNotEmpty;

    if (!useUnifiedKey && !useTtsParams) {
      throw Exception(
        '请配置 DOUBAO_API_KEY（统一 key）或 DOUBAO_TTS_APPID/TOKEN/CLUSTER',
      );
    }

    final uri = Uri.parse('$_ttsBaseUrl/api/v1/tts');
    final reqId = DateTime.now().millisecondsSinceEpoch.toString();
    final token = useUnifiedKey ? _apiKey : _ttsToken;
    final appId = useUnifiedKey ? _apiKey : _ttsAppId;
    final cluster = useUnifiedKey ? 'volcano_tts' : _ttsCluster;

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer;$token',
      },
      body: jsonEncode({
        'app': appId,
        'token': token,
        'cluster': cluster,
        'reqid': reqId,
        'text': text,
        'text_type': 'plain',
        'operation': 'query',
        'with_frontend': 1,
        'frontend_type': 'unitTson',
        'voice_type': 'zh_female_shuangkuaisisi_moon_bigtts',
        'encoding': 'mp3',
        'speed_ratio': 1.0,
        'volume_ratio': 1.0,
        'pitch_ratio': 1.0,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('豆包 TTS 失败(${response.statusCode})：${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final dataBase64 = data['data'] as String?;
    if (dataBase64 == null || dataBase64.isEmpty) {
      throw Exception('TTS 返回无音频数据');
    }

    return base64Decode(dataBase64);
  }

  /// 文本对话（兼容 OpenAI Chat 格式），用于 AI 引导问题、点评等
  Future<String> chatCompletion({
    required List<Map<String, String>> messages,
    double temperature = 0.6,
    bool jsonMode = false,
  }) async {
    if (_visionApiKey.isEmpty || _visionModel.isEmpty) {
      throw Exception(
        '请配置 DOUBAO_API_KEY 和 DOUBAO_ARK_MODEL',
      );
    }

    final uri = Uri.parse('$_arkBaseUrl/api/v3/chat/completions');
    final body = <String, dynamic>{
      'model': _visionModel,
      'temperature': temperature,
      'messages': messages,
    };
    // 豆包模型不支持 response_format.json_object，依赖 prompt 要求返回 JSON

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_visionApiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('豆包对话失败(${response.statusCode})：${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('豆包返回为空');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    final content = (message['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) {
      throw Exception('豆包返回内容为空');
    }
    return content;
  }

  /// 录音转写（豆包语音）
  /// 优先标准版（需公网 audioUrl，https://www.volcengine.com/docs/6561/1354868）
  /// 否则极速版（支持 base64，https://www.volcengine.com/docs/6561/1631584）
  Future<String> speechToText({String? audioUrl, String? audioBase64}) async {
    final appId = _asrAppId.isNotEmpty ? _asrAppId : _apiKey;
    final accessKey = _asrAccessKey.isNotEmpty ? _asrAccessKey : _apiKey;
    if (appId.isEmpty || accessKey.isEmpty) {
      throw Exception('请配置 DOUBAO_ASR_APPID、DOUBAO_ASR_ACCESS_KEY，或 DOUBAO_API_KEY');
    }

    if ((audioUrl == null || audioUrl.isEmpty) && (audioBase64 == null || audioBase64.isEmpty)) {
      throw Exception('需提供 audioUrl 或 audioBase64');
    }

    // 有公网 URL 时优先用标准版（豆包录音文件识别模型2.0，volc.seedasr.auc）
    if (audioUrl != null && audioUrl.isNotEmpty && !audioUrl.startsWith('blob:')) {
      try {
        return await _speechToTextStandard(audioUrl: audioUrl, appId: appId, accessKey: accessKey);
      } catch (_) {
        // 标准版失败，继续极速版
      }
    }

    final uri = Uri.parse('$_asrBaseUrl/api/v3/auc/bigmodel/recognize/flash');
    final body = <String, dynamic>{
      'user': {'uid': appId},
      'audio': audioUrl != null && audioUrl.isNotEmpty
          ? {'url': audioUrl}
          : {'data': audioBase64},
      'request': {'model_name': 'bigmodel'},
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Api-App-Key': appId,
        'X-Api-Access-Key': accessKey,
        'X-Api-Resource-Id': 'volc.bigasr.auc_turbo',
        'X-Api-Request-Id': '${DateTime.now().millisecondsSinceEpoch}-${appId.hashCode}',
        'X-Api-Sequence': '-1',
      },
      body: jsonEncode(body),
    );

    final statusCode = response.headers['x-api-status-code'];
    if (statusCode != '20000000') {
      throw Exception('豆包 ASR 失败($statusCode)：${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>?;
    final text = (result?['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw Exception('豆包 ASR 返回为空');
    }
    return text;
  }

  /// 标准版：submit + 轮询 query（豆包录音文件识别模型2.0，volc.seedasr.auc）
  /// 文档 https://www.volcengine.com/docs/6561/1354868
  Future<String> _speechToTextStandard({
    required String audioUrl,
    required String appId,
    required String accessKey,
  }) async {
    const resourceId = 'volc.seedasr.auc';
    final requestId = '${DateTime.now().millisecondsSinceEpoch}-${appId.hashCode}';
    final format = _guessAudioFormat(audioUrl);

    final submitUri = Uri.parse('$_asrBaseUrl/api/v3/auc/bigmodel/submit');
    final submitResponse = await http.post(
      submitUri,
      headers: {
        'Content-Type': 'application/json',
        'X-Api-App-Key': appId,
        'X-Api-Access-Key': accessKey,
        'X-Api-Resource-Id': resourceId,
        'X-Api-Request-Id': requestId,
        'X-Api-Sequence': '-1',
      },
      body: jsonEncode({
        'user': {'uid': appId},
        'audio': {'url': audioUrl, 'format': format},
        'request': {'model_name': 'bigmodel', 'enable_itn': true},
      }),
    );

    final submitCode = submitResponse.headers['x-api-status-code'];
    if (submitCode != '20000000') {
      throw Exception('豆包 ASR 标准版提交失败($submitCode)：${submitResponse.body}');
    }

    // 轮询查询结果
    final queryUri = Uri.parse('$_asrBaseUrl/api/v3/auc/bigmodel/query');
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final queryResponse = await http.post(
        queryUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-App-Key': appId,
          'X-Api-Access-Key': accessKey,
          'X-Api-Resource-Id': resourceId,
          'X-Api-Request-Id': requestId,
        },
        body: '{}',
      );

      final queryCode = queryResponse.headers['x-api-status-code'];
      if (queryCode == '20000000') {
        final data = jsonDecode(queryResponse.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        final text = (result?['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) {
          throw Exception('豆包 ASR 标准版返回为空');
        }
        return text;
      }
      if (queryCode != '20000001' && queryCode != '20000002') {
        throw Exception('豆包 ASR 标准版查询失败($queryCode)：${queryResponse.body}');
      }
    }
    throw Exception('豆包 ASR 标准版超时');
  }

  String _guessAudioFormat(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.wav')) return 'wav';
    if (lower.contains('.mp3')) return 'mp3';
    if (lower.contains('.ogg') || lower.contains('.webm')) return 'ogg';
    return 'mp3';
  }
}
