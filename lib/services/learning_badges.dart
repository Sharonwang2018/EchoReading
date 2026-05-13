import 'package:echo_reading/models/read_log_with_book.dart';

/// Lightweight gamification derived from existing read logs (no schema migration).
class LearningBadge {
  const LearningBadge({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.unlocked,
  });

  final String id;
  final String titleZh;
  final String titleEn;
  final bool unlocked;
}

class LearningBadges {
  LearningBadges._();

  static List<LearningBadge> fromLogs(List<ReadLogWithBook> logs) {
    final retellings = logs.where((e) => e.readLog.sessionType == 'retelling').length;
    final shared = logs.where((e) => e.readLog.isSharedReading).length;
    final langs = logs.map((e) => (e.readLog.language ?? '').toLowerCase()).where((s) => s.isNotEmpty).toSet();
    final hasZh = langs.any((s) => s.startsWith('zh'));
    final hasEn = langs.any((s) => s.startsWith('en'));

    return [
      LearningBadge(
        id: 'first_retell',
        titleZh: '复述小星星',
        titleEn: 'First retell star',
        unlocked: retellings >= 1,
      ),
      LearningBadge(
        id: 'five_sessions',
        titleZh: '阅读小书虫（5 次）',
        titleEn: 'Book worm (5 sessions)',
        unlocked: logs.length >= 5,
      ),
      LearningBadge(
        id: 'shared_once',
        titleZh: '共读时光',
        titleEn: 'Shared reading',
        unlocked: shared >= 1,
      ),
      LearningBadge(
        id: 'bilingual',
        titleZh: '双语小使者',
        titleEn: 'Bilingual explorer',
        unlocked: hasZh && hasEn,
      ),
    ];
  }
}
