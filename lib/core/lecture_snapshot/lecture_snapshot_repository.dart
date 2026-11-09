import 'package:sqflite/sqflite.dart';

import 'lecture_snapshot_record.dart';

class LectureSnapshotRepository {
  LectureSnapshotRepository(Database db)
      : _db = db,
        _memory = null;

  /// Keeps rows in memory only (used on web, where SQLite is unavailable).
  LectureSnapshotRepository.inMemory()
      : _db = null,
        _memory = <String, Map<String, Object?>>{};

  final Database? _db;
  final Map<String, Map<String, Object?>>? _memory;
  static const _table = 'lecture_snapshots';

  Future<void> upsert(LectureSnapshotRecord record) async {
    final memory = _memory;
    if (memory != null) {
      final row = Map<String, Object?>.from(record.toRow());
      memory[row['link_record']! as String] = row;
      return;
    }
    await _db!.insert(
      _table,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LectureSnapshotRecord?> get(String linkRecord) async {
    final memory = _memory;
    if (memory != null) {
      final row = memory[linkRecord];
      return row == null ? null : LectureSnapshotRecord.fromRow(row);
    }
    final rows = await _db!.query(
      _table,
      where: 'link_record = ?',
      whereArgs: [linkRecord],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LectureSnapshotRecord.fromRow(rows.first);
  }

  Future<bool> exists(String linkRecord) async {
    final memory = _memory;
    if (memory != null) return memory.containsKey(linkRecord);
    final rows = await _db!.query(
      _table,
      columns: ['link_record'],
      where: 'link_record = ?',
      whereArgs: [linkRecord],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> delete(String linkRecord) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(linkRecord);
      return;
    }
    await _db!.delete(
      _table,
      where: 'link_record = ?',
      whereArgs: [linkRecord],
    );
  }
}
