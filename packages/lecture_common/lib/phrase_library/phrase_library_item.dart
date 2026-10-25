class PhraseLibraryItem {
  const PhraseLibraryItem({
    required this.id,
    required this.language,
    required this.content,
    required this.createdAtUtc,
    this.note = '',
  });

  final String id;
  final String language;
  final String content;
  final String createdAtUtc;
  final String note;

  Map<String, Object?> toRow() => {
        'id': id,
        'language': language,
        'content': content,
        'created_at_utc': createdAtUtc,
        'note': note,
      };

  factory PhraseLibraryItem.fromRow(Map<String, Object?> row) {
    return PhraseLibraryItem(
      id: row['id']! as String,
      language: row['language']! as String,
      content: row['content']! as String,
      createdAtUtc: row['created_at_utc']! as String,
      note: (row['note'] as String?) ?? '',
    );
  }
}
