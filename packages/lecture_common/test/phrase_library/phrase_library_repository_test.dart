import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> openIsolatedTestDb() {
    return openPhraseLibraryDatabase(
      inMemory: true,
      inMemoryName:
          'phrase_library_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  test('add then getAll returns newest first', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    final older = await repo.add(
      language: 'en',
      content: 'first',
      now: DateTime.utc(2026, 7, 14, 10),
      id: 'id-1',
    );
    final newer = await repo.add(
      language: 'vi',
      content: 'second',
      now: DateTime.utc(2026, 7, 14, 11),
      id: 'id-2',
    );

    final all = await repo.getAll();
    expect(all.map((e) => e.id).toList(), ['id-2', 'id-1']);
    expect(newer!.language, 'vi');
    expect(older!.content, 'first');
  });

  test('add skips empty or whitespace content', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    expect(await repo.add(language: 'en', content: '  '), isNull);
    expect(await repo.add(language: 'en', content: ''), isNull);
    expect(await repo.getAll(), isEmpty);
  });

  test('add skips duplicate content', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    await repo.add(language: 'en', content: 'same', id: 'a');
    expect(await repo.add(language: 'vi', content: 'same', id: 'b'), isNull);
    expect(await repo.containsContent('same'), isTrue);

    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.single.id, 'a');
  });

  test('add skips duplicate content ignoring case', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    await repo.add(language: 'en', content: 'Hello', id: 'a');
    expect(await repo.add(language: 'en', content: 'hello', id: 'b'), isNull);
    expect(await repo.containsContent('HELLO'), isTrue);
    expect(await repo.getAll(), hasLength(1));
  });

  test('add with empty language still persists content', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    final item = await repo.add(language: '', content: 'hello', id: 'x');
    expect(item!.language, '');
    expect(item.content, 'hello');
  });

  test('deleteById removes row', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    await repo.add(language: 'en', content: 'bye', id: 'del-me');
    await repo.deleteById('del-me');
    expect(await repo.getAll(), isEmpty);
  });

  test('add persists trimmed note', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    final item = await repo.add(
      language: 'en',
      content: 'hello',
      note: '  meaning  ',
      id: 'n1',
    );
    expect(item!.note, 'meaning');
    expect((await repo.getAll()).single.note, 'meaning');
  });

  test('add defaults note to empty', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    final item = await repo.add(language: 'en', content: 'plain', id: 'n0');
    expect(item!.note, '');
  });

  test('updateNote trims and persists', () async {
    final db = await openIsolatedTestDb();
    final repo = PhraseLibraryRepository(db);

    await repo.add(language: 'en', content: 'word', note: 'old', id: 'u1');
    await repo.updateNote('u1', '  new note  ');
    expect((await repo.getAll()).single.note, 'new note');
  });

  test('fromRow treats missing note as empty', () {
    final item = PhraseLibraryItem.fromRow({
      'id': 'x',
      'language': 'en',
      'content': 'hi',
      'created_at_utc': '2026-07-14T00:00:00.000Z',
    });
    expect(item.note, '');
  });
}
