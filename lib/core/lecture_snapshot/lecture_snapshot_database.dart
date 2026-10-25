import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _dbName = 'lecture_snapshots.db';
const _schemaVersion = 1;

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE lecture_snapshots (
      link_record TEXT PRIMARY KEY NOT NULL,
      session_id TEXT NOT NULL,
      updated_at_utc TEXT NOT NULL,
      transcript_json TEXT NOT NULL,
      computed_senders_json TEXT NOT NULL,
      active_languages_json TEXT NOT NULL,
      selected_language TEXT NOT NULL,
      selected_raw_sender TEXT NOT NULL
    )
  ''');
}

@visibleForTesting
Future<void> createLectureSnapshotSchemaForTest(Database db) => _createSchema(db);

Future<Database> openLectureSnapshotDatabase({
  bool inMemory = false,
  String? inMemoryName,
}) async {
  final path = inMemory
      ? (inMemoryName != null
          ? 'file:$inMemoryName?mode=memory&cache=shared'
          : inMemoryDatabasePath)
      : p.join(
          (await getApplicationDocumentsDirectory()).path,
          _dbName,
        );
  return openDatabase(
    path,
    version: _schemaVersion,
    onCreate: (db, _) => _createSchema(db),
  );
}
