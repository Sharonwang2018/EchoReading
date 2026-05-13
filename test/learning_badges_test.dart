import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/read_log.dart';
import 'package:echo_reading/models/read_log_with_book.dart';
import 'package:echo_reading/services/learning_badges.dart';
import 'package:flutter_test/flutter_test.dart';

ReadLogWithBook _row({
  required String sessionType,
  String? language,
}) {
  final log = ReadLog(
    id: 'x',
    userId: 'u',
    bookId: 'b',
    sessionType: sessionType,
    language: language,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  const book = Book(
    id: 'b',
    isbn: '9780000000000',
    title: 'T',
    author: 'A',
    coverUrl: null,
    summary: 'S',
  );
  return ReadLogWithBook(readLog: log, book: book);
}

void main() {
  test('LearningBadges unlocks first retell and shared reading', () {
    final badges = LearningBadges.fromLogs([
      _row(sessionType: 'retelling', language: 'zh'),
      _row(sessionType: 'shared_reading', language: 'zh'),
    ]);
    expect(badges.firstWhere((b) => b.id == 'first_retell').unlocked, isTrue);
    expect(badges.firstWhere((b) => b.id == 'shared_once').unlocked, isTrue);
    expect(badges.firstWhere((b) => b.id == 'five_sessions').unlocked, isFalse);
    expect(badges.firstWhere((b) => b.id == 'bilingual').unlocked, isFalse);
  });

  test('LearningBadges bilingual when zh and en present', () {
    final badges = LearningBadges.fromLogs([
      _row(sessionType: 'retelling', language: 'zh-CN'),
      _row(sessionType: 'retelling', language: 'en'),
    ]);
    expect(badges.firstWhere((b) => b.id == 'bilingual').unlocked, isTrue);
  });
}
