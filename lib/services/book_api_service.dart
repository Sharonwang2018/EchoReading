import 'dart:convert';

import 'package:echo_reading/models/book.dart';
import 'package:http/http.dart' as http;

class BookApiService {
  static final RegExp _isbnSanitizer = RegExp(r'[^0-9Xx]');

  String? normalizeIsbn(String raw) {
    final normalized = raw.replaceAll(_isbnSanitizer, '').toUpperCase();
    if (normalized.length == 10 || normalized.length == 13) {
      return normalized;
    }
    return null;
  }

  Future<BookLookupResult?> fetchByIsbn(String isbn) async {
    final uri = Uri.parse(
      'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Book API request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final key = 'ISBN:$isbn';
    final rawBook = decoded[key];
    if (rawBook is! Map<String, dynamic>) {
      return null;
    }

    final title = (rawBook['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return null;
    }

    final authors =
        (rawBook['authors'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((author) => (author['name'] as String?)?.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList() ??
        const <String>[];

    final cover = rawBook['cover'] as Map<String, dynamic>?;
    final descriptionRaw = rawBook['notes'] ?? rawBook['description'];

    String? summary;
    if (descriptionRaw is String) {
      summary = descriptionRaw.trim();
    } else if (descriptionRaw is Map<String, dynamic>) {
      summary = (descriptionRaw['value'] as String?)?.trim();
    }

    return BookLookupResult(
      isbn: isbn,
      title: title,
      author: authors.isEmpty ? 'Unknown Author' : authors.join(', '),
      coverUrl:
          (cover?['large'] ?? cover?['medium'] ?? cover?['small']) as String?,
      summary: (summary == null || summary.isEmpty)
          ? Book.defaultSummary
          : summary,
    );
  }
}
