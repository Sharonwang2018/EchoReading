// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_reading/models/book.dart';

void main() {
  test('Book model json conversion works', () {
    final json = {
      'id': 'book-id-1',
      'isbn': '9787115428028',
      'title': 'Sample Book',
      'author': 'Author A',
      'cover_url': 'https://example.com/cover.png',
      'summary': 'Summary text',
    };

    final book = Book.fromJson(json);
    final output = book.toJson();

    expect(book.title, 'Sample Book');
    expect(output['isbn'], '9787115428028');
  });
}
