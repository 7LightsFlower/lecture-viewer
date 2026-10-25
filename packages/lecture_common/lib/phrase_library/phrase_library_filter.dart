import 'phrase_library_item.dart';

List<String> languageOptionsFromItems(Iterable<PhraseLibraryItem> items) {
  final set = <String>{};
  for (final item in items) {
    set.add(item.language);
  }
  final list = set.toList()..sort();
  return list;
}

String? defaultLanguageForFilter(List<String> options) {
  if (options.isEmpty) return null;
  if (options.contains('Transcript')) return 'Transcript';
  return (List<String>.from(options)..sort()).first;
}

List<PhraseLibraryItem> itemsForLanguage(
  Iterable<PhraseLibraryItem> items,
  String? language,
) {
  if (language == null) return const [];
  return items.where((e) => e.language == language).toList();
}
