import 'package:flutter/foundation.dart' show kIsWeb;

/// API 与运行配置
///
/// Web: Uri.base.origin（页面加载地址 = 永远正确，无 localhost）
/// 非 Web: API_BASE_URL 或 http://localhost:3000
class EnvConfig {
  static String get apiBaseUrl {
    if (!kIsWeb) return _apiBaseUrlIo;
    final b = Uri.base;
    final scheme = b.scheme;
    // 同源：3000 直连、443/80 经 ngrok 等代理
    if (b.port == 3000 || b.port == 443 || b.port == 80) return b.origin;
    return '$scheme://${b.host}:3000';
  }

  static const String _apiBaseUrlIo =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://10.0.0.138:3000');

  static const int timeout =
      int.fromEnvironment('API_TIMEOUT', defaultValue: 15000);

  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
