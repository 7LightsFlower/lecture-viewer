import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'phrase_library_item.dart';

class PhraseLibraryRepository {
  PhraseLibraryRepository(this._db);

  final Database _db;
  static const _table = 'phrase_library_items';

  /// Inserts a row. Returns null when [content] is empty after trim, or when
  /// the same trimmed content already exists in the library.
  Future<PhraseLibraryItem?> add({
    required String language,
    required String content,
    String note = '',
    DateTime? now,
    String? id,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    if (await containsContent(trimmed)) return null;

    final item = PhraseLibraryItem(
      id: id ?? const Uuid().v4(),
      language: language,
      content: trimmed,
      createdAtUtc: (now ?? DateTime.now()).toUtc().toIso8601String(),
      note: note.trim(),
    );
    await _db.insert(_table, item.toRow());
    return item;
  }

  /// True when trimmed [content] already exists (any language), case-insensitive.
  Future<bool> containsContent(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    final rows = await _db.query(
      _table,
      columns: ['id'],
      where: 'LOWER(content) = LOWER(?)',
      whereArgs: [trimmed],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<PhraseLibraryItem>> getAll() async {
    final rows = await _db.query(
      _table,
      orderBy: 'created_at_utc DESC',
    );
    return rows.map(PhraseLibraryItem.fromRow).toList();
  }

  Future<void> updateNote(String id, String note) async {
    await _db.update(
      _table,
      {'note': note.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteById(String id) async {
    await _db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
