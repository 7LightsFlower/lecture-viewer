import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_repository.dart';

void main() {
  const linkA = 'host/mobile/session/lecture-a';
  const linkB = 'host/mobile/session/lecture-b';

  SavedLecture sample({
    required String id,
    required String linkRecord,
    required String savedAt,
    String? lastJoinedAt,
    String? joinUrl,
  }) {
    return SavedLecture(
      id: id,
      displayName: 'Name $id',
      linkRecord: linkRecord,
      sessionId: linkRecord.split('/').last,
      savedAt: savedAt,
      lastJoinedAt: lastJoinedAt ?? savedAt,
      joinUrl: joinUrl,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns empty when unset', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    expect(repo.load(), isEmpty);
  });

  test('add persists and load returns most recently joined first', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);

    final older = sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z');
    final newer = sample(id: '2', linkRecord: linkB, savedAt: '2026-05-18T12:00:00.000Z');

    expect(await repo.add(older), isTrue);
    expect(await repo.add(newer), isTrue);

    final loaded = repo.load();
    expect(loaded.map((e) => e.id), ['2', '1']);
  });

  test('add rejects duplicate linkRecord', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);

    final first = sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z');
    final dup = sample(id: '2', linkRecord: linkA, savedAt: '2026-05-18T11:00:00.000Z');

    expect(await repo.add(first), isTrue);
    expect(await repo.add(dup), isFalse);
    expect(repo.load(), hasLength(1));
  });

  test('containsLinkRecord', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);

    expect(repo.containsLinkRecord(linkA), isFalse);
    await repo.add(
      sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z'),
    );
    expect(repo.containsLinkRecord(linkA), isTrue);
  });

  test('removeByIds removes only matching', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);

    await repo.add(sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z'));
    await repo.add(sample(id: '2', linkRecord: linkB, savedAt: '2026-05-18T11:00:00.000Z'));

    await repo.removeByIds({'1'});
    final loaded = repo.load();
    expect(loaded.map((e) => e.id), ['2']);
  });

  test('recordLastJoin updates timestamp and sort order', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);

    await repo.add(
      sample(
        id: '1',
        linkRecord: linkA,
        savedAt: '2026-05-18T10:00:00.000Z',
        lastJoinedAt: '2026-05-18T10:00:00.000Z',
      ),
    );
    await repo.add(
      sample(
        id: '2',
        linkRecord: linkB,
        savedAt: '2026-05-18T11:00:00.000Z',
        lastJoinedAt: '2026-05-18T11:00:00.000Z',
      ),
    );
    expect(repo.load().first.id, '2');

    expect(await repo.recordLastJoin('1'), isTrue);

    final loaded = repo.load();
    expect(loaded.first.id, '1');
    expect(
      loaded.first.lastJoinedAt.compareTo('2026-05-18T11:00:00.000Z'),
      greaterThan(0),
    );
  });

  test('updateDisplayName changes name and persists', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    await repo.add(
      sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z'),
    );

    expect(await repo.updateDisplayName('1', 'Renamed'), isTrue);
    expect(repo.load().single.displayName, 'Renamed');
  });

  test('updateDisplayName rejects empty name', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    await repo.add(
      sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z'),
    );

    expect(await repo.updateDisplayName('1', '   '), isFalse);
    expect(repo.load().single.displayName, 'Name 1');
  });

  test('updateDisplayName returns false for unknown id', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    expect(await repo.updateDisplayName('missing', 'X'), isFalse);
  });

  test('setJoinUrlIfMissing writes when bookmark joinUrl is null', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    await repo.add(
      sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z'),
    );

    const url =
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/lecture-a';
    expect(await repo.setJoinUrlIfMissing(linkA, url), isTrue);
    expect(repo.load().single.joinUrl, url);
  });

  test('setJoinUrlIfMissing does not overwrite existing joinUrl', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    await repo.add(
      SavedLecture(
        id: '1',
        displayName: 'Name 1',
        linkRecord: linkA,
        sessionId: 'lecture-a',
        savedAt: '2026-05-18T10:00:00.000Z',
        lastJoinedAt: '2026-05-18T10:00:00.000Z',
        joinUrl: 'https://lectureviewer.app.link/old?link_record=host/mobile/session/lecture-a',
      ),
    );

    expect(
      await repo.setJoinUrlIfMissing(
        linkA,
        'https://lectureviewer.app.link/new?link_record=host/mobile/session/lecture-a',
      ),
      isFalse,
    );
    expect(
      repo.load().single.joinUrl,
      'https://lectureviewer.app.link/old?link_record=host/mobile/session/lecture-a',
    );
  });

  test('setJoinUrlIfMissing returns false when lecture missing', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    expect(
      await repo.setJoinUrlIfMissing(
        linkA,
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/lecture-a',
      ),
      isFalse,
    );
  });
}
