import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

PhraseLibraryItem item({
  required String id,
  required String language,
  String content = 'x',
}) {
  return PhraseLibraryItem(
    id: id,
    language: language,
    content: content,
    createdAtUtc: '2026-07-14T00:00:00.000Z',
  );
}

void main() {
  test('languageOptionsFromItems returns unique sorted languages', () {
    final options = languageOptionsFromItems([
      item(id: '1', language: 'vi'),
      item(id: '2', language: 'Transcript'),
      item(id: '3', language: 'vi'),
      item(id: '4', language: ''),
    ]);
    expect(options, ['', 'Transcript', 'vi']);
  });

  test('defaultLanguageForFilter prefers Transcript', () {
    expect(
      defaultLanguageForFilter(['en', 'Transcript', 'vi']),
      'Transcript',
    );
  });

  test('defaultLanguageForFilter falls back to first sorted option', () {
    expect(defaultLanguageForFilter(['vi', 'en']), 'en');
  });

  test('defaultLanguageForFilter returns null when empty', () {
    expect(defaultLanguageForFilter(const []), isNull);
  });

  test('itemsForLanguage filters exact language match', () {
    final items = [
      item(id: '1', language: 'en', content: 'a'),
      item(id: '2', language: 'vi', content: 'b'),
      item(id: '3', language: 'en', content: 'c'),
    ];
    expect(
      itemsForLanguage(items, 'en').map((e) => e.id).toList(),
      ['1', '3'],
    );
    expect(itemsForLanguage(items, null), isEmpty);
  });
}
