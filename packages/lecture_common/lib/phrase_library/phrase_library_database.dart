import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _dbName = 'phrase_library.db';
const _schemaVersion = 2;

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE phrase_library_items (
      id TEXT PRIMARY KEY NOT NULL,
      language TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at_utc TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT ''
    )
  ''');
}

Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      "ALTER TABLE phrase_library_items ADD COLUMN note TEXT NOT NULL DEFAULT ''",
    );
  }
}

@visibleForTesting
Future<void> createPhraseLibrarySchemaForTest(Database db) =>
    _createSchema(db);

Future<Database> openPhraseLibraryDatabase({
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
    onUpgrade: (db, oldVersion, newVersion) =>
        _upgradeSchema(db, oldVersion, newVersion),
  );
}
