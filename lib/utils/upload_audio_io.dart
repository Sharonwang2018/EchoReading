import 'dart:io' show File;

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';

/// 移动端/桌面：path 为本地文件路径，上传到 API 服务器
Future<String> uploadAudioToCloudBase(
  String pathOrBlobUrl,
  String bucket,
  String objectPath, {
  String contentType = 'audio/mp4',
}) async {
  if (!EnvConfig.isConfigured) {
    throw Exception(
      'API 未配置。请设置 API_BASE_URL（如 http://localhost:3000）',
    );
  }

  final file = File(pathOrBlobUrl);
  if (!await file.exists()) {
    throw Exception('录音文件不存在');
  }

  return ApiService.uploadAudio(file, contentType: contentType);
}
