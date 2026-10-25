import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_database.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_record.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_repository.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_bucket_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  LectureSnapshotRecord sample(String link, {String partial = 'hello'}) {
    final key = lectureBucketKey(
      languageDisplayName: 'English',
      rawSender: 'mt:1_en',
    );
    return LectureSnapshotRecord(
      linkRecord: link,
      sessionId: 'sess-1',
      updatedAtUtc: DateTime.utc(2026, 5, 19, 12),
      transcript: SessionTranscriptState(
        buckets: {
          key: TranscriptBucket(
            paragraphs: const [],
            partialText: partial,
            speakerLabelByCompoundId: const {},
          ),
        },
      ),
      computedSenders: const {
        'mt:1_en': ComputedSenderInfo(
          language: 'English',
          type: 'mt',
          percent: 0,
        ),
      },
      activeLanguages: const ['English'],
      selectedLanguage: 'English',
      selectedRawSender: 'mt:1_en',
    );
  }

  Future<Database> openIsolatedTestDb() {
    return openLectureSnapshotDatabase(
      inMemory: true,
      inMemoryName: 'lecture_snapshots_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  test('upsert then get round-trip', () async {
    final db = await openIsolatedTestDb();
    final repo = LectureSnapshotRepository(db);
    await repo.upsert(sample('link-a'));
    final loaded = await repo.get('link-a');
    expect(loaded?.transcript.buckets.length, 1);
    expect(loaded?.selectedLanguage, 'English');
  });

  test('upsert overwrites same link_record', () async {
    final db = await openIsolatedTestDb();
    final repo = LectureSnapshotRepository(db);
    await repo.upsert(sample('link-a', partial: 'v1'));
    await repo.upsert(sample('link-a', partial: 'v2'));
    final loaded = await repo.get('link-a');
    final key = lectureBucketKey(
      languageDisplayName: 'English',
      rawSender: 'mt:1_en',
    );
    expect(loaded!.transcript.buckets[key]!.partialText, 'v2');
  });

  test('exists and delete', () async {
    final db = await openIsolatedTestDb();
    final repo = LectureSnapshotRepository(db);
    expect(await repo.exists('link-a'), isFalse);
    await repo.upsert(sample('link-a'));
    expect(await repo.exists('link-a'), isTrue);
    await repo.delete('link-a');
    expect(await repo.exists('link-a'), isFalse);
    expect(await repo.get('link-a'), isNull);
  });
}
