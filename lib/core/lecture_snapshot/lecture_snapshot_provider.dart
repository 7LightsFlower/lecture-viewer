import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lecture_snapshot_database.dart';
import 'lecture_snapshot_repository.dart';

/// Test-only bypass for SQLite/path setup in widget tests.
@visibleForTesting
Future<void> Function(String linkRecord)?
    deleteLectureSnapshotForLinkRecordOverride;

final lectureSnapshotRepositoryProvider =
    FutureProvider<LectureSnapshotRepository>((ref) async {
  final db = await openLectureSnapshotDatabase();
  return LectureSnapshotRepository(db);
});

final lectureSnapshotShareableProvider =
    FutureProvider.family<bool, String>((ref, linkRecord) async {
  final repo = await ref.watch(lectureSnapshotRepositoryProvider.future);
  final record = await repo.get(linkRecord);
  return record?.hasWebsocketSessionId ?? false;
});

Future<void> deleteLectureSnapshotForLinkRecord(String linkRecord) async {
  final override = deleteLectureSnapshotForLinkRecordOverride;
  if (override != null) {
    await override(linkRecord);
    return;
  }
  final db = await openLectureSnapshotDatabase();
  await LectureSnapshotRepository(db).delete(linkRecord);
}
