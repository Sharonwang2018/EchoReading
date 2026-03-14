import 'dart:convert';

import 'package:http/http.dart' as http;

/// Azure AI Vision Read API 服务
/// 用于本地 OCR 置信度不足时的云端补偿
const _endpoint = String.fromEnvironment('AZURE_VISION_ENDPOINT');
const _key = String.fromEnvironment('AZURE_VISION_KEY');

class AzureVisionService {
  bool get isConfigured =>
      _endpoint.isNotEmpty && _key.isNotEmpty;

  /// 从图片中识别文字，保持段落结构
  /// 使用 Read v3.2 API（异步：先提交再轮询结果）
  Future<String> extractTextFromImage(List<int> imageBytes) async {
    if (!isConfigured) {
      throw Exception(
        '请配置 AZURE_VISION_ENDPOINT 和 AZURE_VISION_KEY',
      );
    }

    final uri = Uri.parse(
      '$_endpoint/vision/v3.2/read/analyze',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Ocp-Apim-Subscription-Key': _key,
      },
      body: imageBytes,
    );

    if (response.statusCode != 202) {
      throw Exception(
        'Azure Read 提交失败(${response.statusCode})：${response.body}',
      );
    }

    final operationLocation =
        response.headers['operation-location'];
    if (operationLocation == null || operationLocation.isEmpty) {
      throw Exception('Azure 未返回 operation-location');
    }

    // 轮询结果
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final resultResponse = await http.get(
        Uri.parse(operationLocation),
        headers: {
          'Ocp-Apim-Subscription-Key': _key,
        },
      );

      if (resultResponse.statusCode != 200) {
        throw Exception(
          'Azure Read 查询失败(${resultResponse.statusCode})',
        );
      }

      final data =
          jsonDecode(resultResponse.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'succeeded') {
        return _parseReadResult(data);
      }
      if (status == 'failed') {
        throw Exception('Azure Read 分析失败');
      }
    }

    throw Exception('Azure Read 超时');
  }

  String _parseReadResult(Map<String, dynamic> data) {
    final analyzeResult =
        data['analyzeResult'] as Map<String, dynamic>?;
    if (analyzeResult == null) return '';

    final readResults =
        analyzeResult['readResults'] as List<dynamic>? ?? [];
    final sb = StringBuffer();

    for (final page in readResults) {
      final lines = page['lines'] as List<dynamic>? ?? [];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i] as Map<String, dynamic>;
        final text = line['text'] as String? ?? '';
        sb.writeln(text);
      }
    }

    return sb.toString().trim();
  }
}
