import 'package:shared_preferences/shared_preferences.dart';

/// 拍照 / 复述「成功识别」次数累计；每满 5 次后的下一次成功（第 6、12…次）触发打赏提示。
class TipDonationTrigger {
  TipDonationTrigger._();

  static const String _kPhoto = 'tip_donation_photo_success_total';
  static const String _kRetelling = 'tip_donation_retelling_success_total';

  /// 每 [interval] 次成功弹出一次（6、12、18… 对应「5 次后再下一次」）。
  static const int interval = 6;

  static Future<bool> recordPhotoSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_kPhoto) ?? 0) + 1;
    await prefs.setInt(_kPhoto, n);
    return n >= interval && n % interval == 0;
  }

  static Future<bool> recordRetellingSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_kRetelling) ?? 0) + 1;
    await prefs.setInt(_kRetelling, n);
    return n >= interval && n % interval == 0;
  }
}
