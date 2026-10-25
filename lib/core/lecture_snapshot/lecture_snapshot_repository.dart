import 'package:sqflite/sqflite.dart';

import 'lecture_snapshot_record.dart';

class LectureSnapshotRepository {
  LectureSnapshotRepository(this._db);

  final Database _db;
  static const _table = 'lecture_snapshots';

  Future<void> upsert(LectureSnapshotRecord record) async {
    await _db.insert(
      _table,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LectureSnapshotRecord?> get(String linkRecord) async {
    final rows = await _db.query(
      _table,
      where: 'link_record = ?',
      whereArgs: [linkRecord],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LectureSnapshotRecord.fromRow(rows.first);
  }

  Future<bool> exists(String linkRecord) async {
    final rows = await _db.query(
      _table,
      columns: ['link_record'],
      where: 'link_record = ?',
      whereArgs: [linkRecord],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> delete(String linkRecord) async {
    await _db.delete(
      _table,
      where: 'link_record = ?',
      whereArgs: [linkRecord],
    );
  }
}
