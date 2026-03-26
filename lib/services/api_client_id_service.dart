import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 稳定设备标识，供服务端匿名/访客配额分桶（与 IP 组合，避免无限注册 guest 刷接口）。
class ApiClientIdService {
  ApiClientIdService._();

  static const _key = 'echo_api_client_id_v1';
  static String? _mem;

  static Future<String> getOrCreate() async {
    if (_mem != null && _mem!.isNotEmpty) return _mem!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_key, id);
    }
    _mem = id;
    return id;
  }
}
