import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_service.dart';

class ReadLogsService {
  ReadLogsService();

  Future<void> createSharedReadingLog({
    required String bookId,
    String? language,
  }) async {
    if (!EnvConfig.isConfigured) {
      throw Exception(
        'API 未配置。请设置 API_BASE_URL（如 http://localhost:3000）',
      );
    }
    final userInfo = await ApiAuthService.getUserInfo();
    if (userInfo == null || userInfo.uuid.isEmpty) {
      throw Exception('请先登录后再记录阅读');
    }
    await ApiService.createReadLog(
      bookId: bookId,
      sessionType: 'shared_reading',
      language: language,
    );
  }
}
