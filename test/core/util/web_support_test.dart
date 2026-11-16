import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_record.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_repository.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';

void main() {
  group('linkRecordFromUserInput', () {
    test('app link → its link_record', () {
      expect(
        linkRecordFromUserInput(
          'https://lectureviewer.app.link/Il4A2yzQrPb'
          '?link_record=lt2srv.iar.kit.edu/mobile/session/tkq-lecture',
        ),
        'lt2srv.iar.kit.edu/mobile/session/tkq-lecture',
      );
    });

    test('link record with or without scheme', () {
      expect(
        linkRecordFromUserInput('https://lt2srv.iar.kit.edu/mobile/session/abc?x=1'),
        'lt2srv.iar.kit.edu/mobile/session/abc',
      );
      expect(
        linkRecordFromUserInput(' lt2srv.iar.kit.edu/mobile/session/abc '),
        'lt2srv.iar.kit.edu/mobile/session/abc',
      );
    });

    test('KIT join link is kept; bare name → KIT public server', () {
      expect(
        linkRecordFromUserInput(
          'https://lt2srv-backup.iar.kit.edu/webapi/shorten/TestLongSession',
        ),
        'lt2srv-backup.iar.kit.edu/webapi/shorten/TestLongSession',
      );
      expect(
        linkRecordFromUserInput('lt2srv-backup.iar.kit.edu/webapi/shorten/x'),
        'lt2srv-backup.iar.kit.edu/webapi/shorten/x',
      );
      expect(
        linkRecordFromUserInput('foo-lecture'),
        'lecture-translator.kit.edu/webapi/shorten/foo-lecture',
      );
    });

    test('garbage → null', () {
      expect(linkRecordFromUserInput(''), isNull);
      expect(linkRecordFromUserInput('two words'), isNull);
      expect(linkRecordFromUserInput('https://host.only/'), isNull);
    });
  });

  test('in-memory snapshot repository round-trips records', () async {
    final repo = LectureSnapshotRepository.inMemory();
    final record = LectureSnapshotRecord(
      linkRecord: 'lt2srv.iar.kit.edu/mobile/session/abc',
      sessionId: '277216',
      updatedAtUtc: DateTime.utc(2026, 11, 9),
      transcript: const SessionTranscriptState.empty(),
      computedSenders: const {
        'asr:0': ComputedSenderInfo(language: 'English', type: 'asr', percent: 0),
      },
      activeLanguages: const ['English'],
      selectedLanguage: 'English',
      selectedRawSender: 'asr:0',
    );

    expect(await repo.exists(record.linkRecord), isFalse);
    await repo.upsert(record);
    expect(await repo.exists(record.linkRecord), isTrue);
    final loaded = await repo.get(record.linkRecord);
    expect(loaded?.sessionId, '277216');
    expect(loaded?.computedSenders['asr:0']?.language, 'English');
    await repo.delete(record.linkRecord);
    expect(await repo.get(record.linkRecord), isNull);
  });
}
