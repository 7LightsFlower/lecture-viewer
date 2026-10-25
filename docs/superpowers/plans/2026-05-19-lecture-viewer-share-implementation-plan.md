# Lecture Viewer Share + Offline Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add transcript share (2way-style, no audio/summary), sqflite latest-session snapshots per `linkRecord`, offline read-only viewer, and home **View last session result** — per `docs/superpowers/specs/2026-05-19-lecture-viewer-share-design.md`.

**Architecture:** `lib/core/lecture_snapshot/` owns sqflite upsert/get/delete keyed by `linkRecord`. `lib/features/lecture_session/domain/share/` ports 2way text export. `lecture_share_sheet.dart` is shared by live and offline screens. `LectureSessionNotifier` debounces snapshot writes; live re-join deletes snapshot before session screen mounts.

**Tech stack:** Flutter 3.10+, `flutter_riverpod`, `lecture_common`, `share_plus ^13.1.0`, `sqflite ^2.4.2`, `path` / `path_provider`, `sqflite_common_ffi` (tests).

**Spec:** `docs/superpowers/specs/2026-05-19-lecture-viewer-share-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `pubspec.yaml` | `share_plus`, `sqflite`, `path`, `path_provider`; dev `sqflite_common_ffi` |
| `lib/core/lecture_snapshot/lecture_snapshot_database.dart` | Schema + `openLectureSnapshotDatabase()` |
| `lib/core/lecture_snapshot/lecture_snapshot_record.dart` | Row model + nested JSON |
| `lib/core/lecture_snapshot/lecture_snapshot_repository.dart` | `upsert`, `get`, `delete`, `exists` |
| `lib/core/lecture_snapshot/lecture_snapshot_provider.dart` | Riverpod `FutureProvider` + `deleteLectureSnapshotForLinkRecord` |
| `lib/features/lecture_session/domain/transcript/computed_sender_info.dart` | Add `toJson` / `fromJson` |
| `lib/features/lecture_session/domain/share/transcript_share_text.dart` | Plain-text formatter |
| `lib/features/lecture_session/domain/share/meeting_share_filename.dart` | `Meeting_YYYY_MM_DD_*.txt` names |
| `lib/features/lecture_session/domain/share/share_export_worker.dart` | Isolate file writer |
| `lib/features/lecture_session/domain/share/lecture_share_input.dart` | Bundle for share sheet |
| `lib/features/lecture_session/presentation/lecture_share_sheet.dart` | Bottom sheet UI |
| `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart` | Offline read-only viewer |
| `lib/features/lecture_session/presentation/lecture_session_scope.dart` | `LectureSessionScope` family key |
| `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart` | Debounced snapshot persist |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | AppBar share + scope key |
| `lib/features/lecture_session/presentation/lecture_session_controls.dart` | Use `LectureSessionScope` |
| `lib/features/lecture_session/presentation/join_session_dialog.dart` | Delete snapshot before push |
| `lib/features/home/presentation/saved_lectures_list.dart` | **View last session result** button |
| `lib/core/providers/core_providers.dart` | Optional: export snapshot provider import site |

---

### Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1:** Add under `dependencies:`:

```yaml
  share_plus: ^13.1.0
  sqflite: ^2.4.2
  path: ^1.9.1
  path_provider: ^2.1.5
```

- [ ] **Step 2:** Add under `dev_dependencies:`:

```yaml
  sqflite_common_ffi: ^2.3.6
```

- [ ] **Step 3:** Run `cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter pub get` — exit 0.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add share_plus and sqflite for lecture snapshot share"
```

---

### Task 2: `ComputedSenderInfo` JSON

**Files:**
- Modify: `lib/features/lecture_session/domain/transcript/computed_sender_info.dart`
- Create: `test/features/lecture_session/computed_sender_info_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/features/lecture_session/computed_sender_info_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/computed_sender_info.dart';

void main() {
  test('toJson/fromJson round-trip', () {
    const info = ComputedSenderInfo(
      language: 'English',
      type: 'mt',
      percent: 0,
      langCode: 'en',
    );
    expect(ComputedSenderInfo.fromJson(info.toJson()), info);
  });
}
```

- [ ] **Step 2:** Run `flutter test test/features/lecture_session/computed_sender_info_test.dart` — FAIL.

- [ ] **Step 3: Add to model**

```dart
  Map<String, dynamic> toJson() => {
        'language': language,
        'type': type,
        'percent': percent,
        if (langCode != null) 'langCode': langCode,
      };

  factory ComputedSenderInfo.fromJson(Map<String, dynamic> json) {
    return ComputedSenderInfo(
      language: json['language'] as String,
      type: json['type'] as String,
      percent: json['percent'] as int,
      langCode: json['langCode'] as String?,
    );
  }
```

- [ ] **Step 4:** Run test — PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/transcript/computed_sender_info.dart test/features/lecture_session/computed_sender_info_test.dart
git commit -m "feat: add JSON serialization for ComputedSenderInfo"
```

---

### Task 3: Snapshot database + record

**Files:**
- Create: `lib/core/lecture_snapshot/lecture_snapshot_database.dart`
- Create: `lib/core/lecture_snapshot/lecture_snapshot_record.dart`

- [ ] **Step 1: Database** (mirror `app_2way_v3/.../session_history_database.dart` pattern)

```dart
// lib/core/lecture_snapshot/lecture_snapshot_database.dart
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

Future<Database> openLectureSnapshotDatabase({bool inMemory = false}) async {
  final path = inMemory
      ? inMemoryDatabasePath
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
```

- [ ] **Step 2: Record**

```dart
// lib/core/lecture_snapshot/lecture_snapshot_record.dart
import 'dart:convert';

import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/computed_sender_info.dart';

class LectureSnapshotRecord {
  const LectureSnapshotRecord({
    required this.linkRecord,
    required this.sessionId,
    required this.updatedAtUtc,
    required this.transcript,
    required this.computedSenders,
    required this.activeLanguages,
    required this.selectedLanguage,
    required this.selectedRawSender,
  });

  final String linkRecord;
  final String sessionId;
  final DateTime updatedAtUtc;
  final SessionTranscriptState transcript;
  final Map<String, ComputedSenderInfo> computedSenders;
  final List<String> activeLanguages;
  final String selectedLanguage;
  final String selectedRawSender;

  Map<String, dynamic> toRow() => {
        'link_record': linkRecord,
        'session_id': sessionId,
        'updated_at_utc': updatedAtUtc.toUtc().toIso8601String(),
        'transcript_json': jsonEncode(transcript.toJson()),
        'computed_senders_json': jsonEncode(
          computedSenders.map((k, v) => MapEntry(k, v.toJson())),
        ),
        'active_languages_json': jsonEncode(activeLanguages),
        'selected_language': selectedLanguage,
        'selected_raw_sender': selectedRawSender,
      };

  static LectureSnapshotRecord fromRow(Map<String, Object?> row) {
    final sendersRaw =
        jsonDecode(row['computed_senders_json']! as String) as Map<String, dynamic>;
    final senders = <String, ComputedSenderInfo>{};
    for (final e in sendersRaw.entries) {
      senders[e.key] = ComputedSenderInfo.fromJson(
        Map<String, dynamic>.from(e.value as Map),
      );
    }
    final langs =
        (jsonDecode(row['active_languages_json']! as String) as List)
            .map((e) => e.toString())
            .toList();
    return LectureSnapshotRecord(
      linkRecord: row['link_record']! as String,
      sessionId: row['session_id']! as String,
      updatedAtUtc: DateTime.parse(row['updated_at_utc']! as String),
      transcript: SessionTranscriptState.fromJson(
        jsonDecode(row['transcript_json']! as String) as Map<String, dynamic>,
      ),
      computedSenders: senders,
      activeLanguages: langs,
      selectedLanguage: row['selected_language']! as String,
      selectedRawSender: row['selected_raw_sender']! as String,
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/lecture_snapshot/lecture_snapshot_database.dart lib/core/lecture_snapshot/lecture_snapshot_record.dart
git commit -m "feat: add lecture snapshot database schema and record model"
```

---

### Task 4: `LectureSnapshotRepository` (TDD)

**Files:**
- Create: `lib/core/lecture_snapshot/lecture_snapshot_repository.dart`
- Create: `test/core/lecture_snapshot/lecture_snapshot_repository_test.dart`

- [ ] **Step 1: Test setup** (top of test file)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_database.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_record.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_repository.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/computed_sender_info.dart';
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
```

- [ ] **Step 2: Write failing tests**

```dart
  test('upsert then get round-trip', () async {
    final db = await openLectureSnapshotDatabase(inMemory: true);
    final repo = LectureSnapshotRepository(db);
    final a = sample('link-a');
    await repo.upsert(a);
    final loaded = await repo.get('link-a');
    expect(loaded?.transcript.buckets.length, 1);
    expect(loaded?.selectedLanguage, 'English');
  });

  test('upsert overwrites same link_record', () async {
    final db = await openLectureSnapshotDatabase(inMemory: true);
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
    final db = await openLectureSnapshotDatabase(inMemory: true);
    final repo = LectureSnapshotRepository(db);
    expect(await repo.exists('link-a'), isFalse);
    await repo.upsert(sample('link-a'));
    expect(await repo.exists('link-a'), isTrue);
    await repo.delete('link-a');
    expect(await repo.exists('link-a'), isFalse);
    expect(await repo.get('link-a'), isNull);
  });
}
```

- [ ] **Step 3:** Run test — FAIL.

- [ ] **Step 4: Implement repository**

```dart
// lib/core/lecture_snapshot/lecture_snapshot_repository.dart
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
```

- [ ] **Step 5:** Run `flutter test test/core/lecture_snapshot/lecture_snapshot_repository_test.dart` — PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/lecture_snapshot/lecture_snapshot_repository.dart test/core/lecture_snapshot/lecture_snapshot_repository_test.dart
git commit -m "feat: add LectureSnapshotRepository with upsert and delete"
```

---

### Task 5: Snapshot Riverpod provider + delete helper

**Files:**
- Create: `lib/core/lecture_snapshot/lecture_snapshot_provider.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lecture_snapshot_database.dart';
import 'lecture_snapshot_repository.dart';

final lectureSnapshotRepositoryProvider =
    FutureProvider<LectureSnapshotRepository>((ref) async {
  final db = await openLectureSnapshotDatabase();
  return LectureSnapshotRepository(db);
});

final lectureSnapshotExistsProvider =
    FutureProvider.family<bool, String>((ref, linkRecord) async {
  final repo = await ref.watch(lectureSnapshotRepositoryProvider.future);
  return repo.exists(linkRecord);
});

Future<void> deleteLectureSnapshotForLinkRecord(String linkRecord) async {
  final db = await openLectureSnapshotDatabase();
  await LectureSnapshotRepository(db).delete(linkRecord);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/lecture_snapshot/lecture_snapshot_provider.dart
git commit -m "feat: add Riverpod providers for lecture snapshots"
```

---

### Task 6: Transcript share formatter (TDD)

**Files:**
- Create: `lib/features/lecture_session/domain/share/transcript_share_text.dart`
- Create: `test/features/lecture_session/transcript_share_text_test.dart`

Port logic from `app_2way_v3/lib/features/translation_session/domain/share/transcript_share_text.dart` but import:

- `package:lecture_common/lecture_common.dart` for `TranscriptBucket`, `TranscriptParagraph`, `TranscriptSegment`
- `package:lecture_common/transcript/domain/transcript_display_format.dart` for `partialWithGap`, `needsInsertedSpaceBetween`, `lastFinalizedSegmentTextFromBucket`

Copy tests from `app_2way_v3/test/features/translation_session/domain/share/transcript_share_text_test.dart` adjusting imports (`SpeakerLabelState` from `lecture_common`).

- [ ] **Step 1:** Create test file with at least: empty bucket, partial only, speaker label, two paragraphs, segment spacing.

- [ ] **Step 2:** Run test — FAIL.

- [ ] **Step 3:** Implement `bucketHasShareableContent`, `formatTranscriptBucketForShare`, private `_formatParagraph` (identical structure to 2way).

- [ ] **Step 4:** Run `flutter test test/features/lecture_session/transcript_share_text_test.dart` — PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/share/transcript_share_text.dart test/features/lecture_session/transcript_share_text_test.dart
git commit -m "feat: add transcript plain-text formatter for share export"
```

---

### Task 7: Share filename + export worker

**Files:**
- Create: `lib/features/lecture_session/domain/share/meeting_share_filename.dart`
- Create: `lib/features/lecture_session/domain/share/share_export_worker.dart`

- [ ] **Step 1:** Copy `meeting_share_filename.dart` from 2way (only `meetingShareTextFileNameForLanguage` + helpers; omit audio/summary names).

- [ ] **Step 2:** Copy `share_export_worker.dart` from 2way; change imports to viewer `transcript_share_text.dart` and `lecture_common` `TranscriptBucket`.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/domain/share/meeting_share_filename.dart lib/features/lecture_session/domain/share/share_export_worker.dart
git commit -m "feat: add share export worker and meeting filename helpers"
```

---

### Task 8: `LectureShareInput` + share sheet

**Files:**
- Create: `lib/features/lecture_session/domain/share/lecture_share_input.dart`
- Create: `lib/features/lecture_session/presentation/lecture_share_sheet.dart`
- Create: `test/features/lecture_session/lecture_share_sheet_test.dart`

- [ ] **Step 1: Input model**

```dart
// lib/features/lecture_session/domain/share/lecture_share_input.dart
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/computed_sender_info.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_bucket_key.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';

class LectureShareInput {
  const LectureShareInput({
    required this.subject,
    required this.activeLanguages,
    required this.computedSenders,
    required this.transcript,
    this.defaultLanguage,
    this.defaultRawSenderByLanguage = const {},
  });

  final String subject;
  final List<String> activeLanguages;
  final Map<String, ComputedSenderInfo> computedSenders;
  final SessionTranscriptState transcript;
  final String? defaultLanguage;
  final Map<String, String> defaultRawSenderByLanguage;

  List<String> languagesWithShareableContent() {
    return activeLanguages.where((lang) {
      final options = moduleOptionsForLanguage(
        selectedLanguage: lang,
        computedSenders: computedSenders,
        buckets: transcript.buckets,
      );
      return options.isNotEmpty;
    }).toList();
  }

  TranscriptBucket? bucketFor({
    required String language,
    required String rawSender,
  }) {
    final key = lectureBucketKey(
      languageDisplayName: language,
      rawSender: rawSender,
    );
    return transcript.buckets[key];
  }
}
```

- [ ] **Step 2: Share sheet** — port `_SessionShareSheet` from 2way `session_share_sheet.dart` with these edits:

  - Remove `_includeAudio`, `_includeSummarization`, summary API, `lt2srvSessionId`.
  - Keep `_includeTranscript` (only toggle), `_selectedLanguageKeys`, `_sharing`.
  - For each **checked** language, render a `DropdownButton<String>` of `moduleOptionsForLanguage` entries (`value: rawSender`, `child: Text(label)`).
  - State: `Map<String, String> _rawSenderByLanguage` — initialize in `initState` from `defaultRawSenderByLanguage`, else `defaultRawSenderForLanguage` for that language.
  - On Share: for each selected language, resolve `rawSender` from map, `bucket = input.bucketFor(...)`, skip if `!bucketHasShareableContent(bucket)`.
  - Build `ShareTextFileJob(path: ..., transcriptBucketJson: bucket.toJson())` per language; `compute(writeShareTextFilesIsolate, jobs)`; `SharePlus.instance.share(ShareParams(files: ..., subject: input.subject))`; delete temp files in `finally`.

  Entry point:

```dart
Future<void> showLectureShareSheet({
  required BuildContext context,
  required LectureShareInput input,
}) { ... }
```

- [ ] **Step 3: Widget test** — pump sheet with a `LectureShareInput` that has one language + two modules; check language then expect one `DropdownButton`; expect no “Include recording” text.

```dart
testWidgets('checked language shows module dropdown, no audio toggle', (tester) async {
  // ProviderScope + MaterialApp + showLectureShareSheet with fixture input
  await tester.tap(find.text('English'));
  await tester.pumpAndSettle();
  expect(find.byType(DropdownButton<String>), findsOneWidget);
  expect(find.text('Include recording'), findsNothing);
});
```

- [ ] **Step 4:** Run `flutter test test/features/lecture_session/lecture_share_sheet_test.dart` — PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/share/lecture_share_input.dart lib/features/lecture_session/presentation/lecture_share_sheet.dart test/features/lecture_session/lecture_share_sheet_test.dart
git commit -m "feat: add lecture share sheet with per-language module picker"
```

---

### Task 9: `LectureSessionScope` + wire live share

**Files:**
- Create: `lib/features/lecture_session/presentation/lecture_session_scope.dart`
- Modify: `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_controls.dart`
- Create: `test/features/lecture_session/lecture_session_share_button_test.dart`

- [ ] **Step 1: Scope typedef**

```dart
// lib/features/lecture_session/presentation/lecture_session_scope.dart
typedef LectureSessionScope = ({String sessionId, String linkRecord});

LectureSessionScope lectureSessionScope({
  required String sessionId,
  required String linkRecord,
}) => (sessionId: sessionId, linkRecord: linkRecord);
```

- [ ] **Step 2:** Change provider family type from `String` to `LectureSessionScope` in `lecture_session_notifier.dart`:

```dart
final lectureSessionProvider = NotifierProvider.autoDispose
    .family<LectureSessionNotifier, LectureSessionState, LectureSessionScope>(
  LectureSessionNotifier.new,
);

class LectureSessionNotifier extends AutoDisposeFamilyNotifier<
    LectureSessionState, LectureSessionScope> {
  @override
  LectureSessionState build(LectureSessionScope scope) {
    ref.onDispose(_dispose);
    Future.microtask(() => _connect(scope.sessionId));
    return LectureSessionState(sessionId: scope.sessionId);
  }
```

- [ ] **Step 3:** Update `lecture_session_screen.dart` and `lecture_session_controls.dart` to take `LectureSessionScope scope` and use `lectureSessionProvider(scope)`.

- [ ] **Step 4:** In `LectureSessionScreen` AppBar add:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.share_outlined),
    tooltip: 'Share',
    onPressed: () {
      final s = ref.read(lectureSessionProvider(scope));
      showLectureShareSheet(
        context: context,
        input: LectureShareInput(
          subject: scope.sessionId,
          activeLanguages: s.activeLanguages,
          computedSenders: s.computedSenders,
          transcript: s.transcript,
          defaultLanguage: s.selectedLanguage,
          defaultRawSenderByLanguage: {
            if (s.selectedLanguage.isNotEmpty && s.selectedRawSender.isNotEmpty)
              s.selectedLanguage: s.selectedRawSender,
          },
        ),
      );
    },
  ),
],
```

Pass `scope: lectureSessionScope(sessionId: sessionId, linkRecord: linkRecord)` to children.

- [ ] **Step 5: Widget test** — pump `LectureSessionScreen` with overrides (mock notifier state with `hasReceivedInfo: true`); expect `find.byIcon(Icons.share_outlined)`.

- [ ] **Step 6:** Fix any compile errors in tests that referenced `lectureSessionProvider('id')`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_session_scope.dart lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart lib/features/lecture_session/presentation/lecture_session_screen.dart lib/features/lecture_session/presentation/lecture_session_controls.dart test/features/lecture_session/lecture_session_share_button_test.dart
git commit -m "feat: add share button on live lecture session screen"
```

---

### Task 10: Debounced snapshot persist in notifier

**Files:**
- Modify: `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`

- [ ] **Step 1:** Add fields:

```dart
Timer? _snapshotDebounce;
```

- [ ] **Step 2:** Add method:

```dart
void _scheduleSnapshotPersist(LectureSessionScope scope) {
  _snapshotDebounce?.cancel();
  _snapshotDebounce = Timer(const Duration(milliseconds: 200), () {
    unawaited(_flushSnapshotPersist(scope));
  });
}

Future<void> _flushSnapshotPersist(LectureSessionScope scope) async {
  if (scope.linkRecord.isEmpty) return;
  try {
    final repo = await ref.read(lectureSnapshotRepositoryProvider.future);
    await repo.upsert(
      LectureSnapshotRecord(
        linkRecord: scope.linkRecord,
        sessionId: scope.sessionId,
        updatedAtUtc: DateTime.now().toUtc(),
        transcript: state.transcript,
        computedSenders: state.computedSenders,
        activeLanguages: state.activeLanguages,
        selectedLanguage: state.selectedLanguage,
        selectedRawSender: state.selectedRawSender,
      ),
    );
  } on Object {
    // best-effort
  }
}
```

- [ ] **Step 3:** Call `_scheduleSnapshotPersist(scope)` at end of:

  - `_applyTexts`
  - `setLanguage` / `_applyLanguageChange` (after state update)
  - `setModule`
  - Handler that updates `computedSenders` / `activeLanguages` from WS info (find `hasReceivedInfo` / sender map updates)

- [ ] **Step 4:** Cancel timer in `_dispose`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart
git commit -m "feat: debounce lecture transcript snapshot to sqflite"
```

---

### Task 11: Delete snapshot on live re-join

**Files:**
- Modify: `lib/features/lecture_session/presentation/join_session_dialog.dart`

- [ ] **Step 1:** Import `deleteLectureSnapshotForLinkRecord`.

- [ ] **Step 2:** After `join == true` and `context.mounted`, **before** `Navigator.push`:

```dart
await deleteLectureSnapshotForLinkRecord(linkRecord);
```

- [ ] **Step 3:** Update `join_session_dialog` / `LectureSessionScreen` push to pass scope:

```dart
builder: (_) => LectureSessionScreen(
  scope: lectureSessionScope(
    sessionId: meetingName,
    linkRecord: linkRecord,
  ),
),
```

Adjust `LectureSessionScreen` constructor to take `LectureSessionScope scope` instead of separate `sessionId` + `linkRecord` (or keep both fields derived from scope).

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/join_session_dialog.dart lib/features/lecture_session/presentation/lecture_session_screen.dart
git commit -m "feat: clear lecture snapshot when re-joining live session"
```

---

### Task 12: Offline `LectureSnapshotScreen`

**Files:**
- Create: `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart`

- [ ] **Step 1:** `ConsumerStatefulWidget` with `linkRecord`, `displayName`.

- [ ] **Step 2:** `initState` → load `ref.read(lectureSnapshotRepositoryProvider.future).then(repo.get)`; if null → SnackBar + pop.

- [ ] **Step 3:** Local state: `selectedLanguage`, `selectedRawSender`, copies of transcript/senders/languages from record.

- [ ] **Step 4:** UI:

  - AppBar: `title: Text(displayName)`, share `IconButton` → `showLectureShareSheet` with `LectureShareInput` from loaded data.
  - Row of two `DropdownButton`s (language list = `activeLanguages`, module = `moduleOptionsForLanguage`).
  - `Expanded` → `TranslationResultTranscriptView(activeBucket: ..., textScale: ref.watch(appSettingsProvider.select((s) => s.textScale)))`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_snapshot_screen.dart
git commit -m "feat: add offline lecture snapshot viewer screen"
```

---

### Task 13: Home list — View last session result

**Files:**
- Modify: `lib/features/home/presentation/saved_lectures_list.dart`
- Create: `test/features/home/saved_lectures_list_snapshot_button_test.dart`

- [ ] **Step 1:** Wrap each row in `Consumer` or use `ref.watch(lectureSnapshotExistsProvider(lecture.linkRecord))` — when `AsyncData(true)`, show:

```dart
TextButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LectureSnapshotScreen(
          linkRecord: lecture.linkRecord,
          displayName: lecture.displayName,
        ),
      ),
    );
  },
  child: const Text('View last session result'),
),
```

Use `subtitle` Column or `trailing` so row `onTap` still calls `_openLecture` only on title area, **or** set `onTap: null` and use explicit buttons: **Join** (row) + **View last session result** — simplest: keep `onTap` for join; put `View last session result` as second line in `subtitle` with `GestureDetector` that stops propagation (Flutter `ListTile` doesn't propagate — use separate `TextButton` in subtitle with its own `onPressed`).

- [ ] **Step 2: Widget test** — override `lectureSnapshotExistsProvider` to return true/false; expect button present/absent.

- [ ] **Step 3:** Run `flutter test test/features/home/saved_lectures_list_snapshot_button_test.dart` — PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/saved_lectures_list.dart test/features/home/saved_lectures_list_snapshot_button_test.dart
git commit -m "feat: add View last session result on saved lecture rows"
```

---

### Task 14: Full test pass + manual checklist

- [ ] **Step 1:** Run `flutter test` — all PASS.

- [ ] **Step 2:** Run `dart analyze lib test` — no errors.

- [ ] **Step 3: Manual verification**

  1. Join live lecture → wait for transcript → Share → OS sheet with `.txt`.
  2. Leave session → home shows **View last session result** → offline viewer + Share works.
  3. Re-join same lecture → button hidden until new transcript written.
  4. Per-language module dropdown exports correct bucket text.

- [ ] **Step 4: Commit** (if any fixups)

```bash
git add -A
git commit -m "chore: fix lecture share snapshot integration issues"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Share on live screen | 9 |
| Share on offline screen | 12 |
| No audio / no summary | 8 |
| Per-language module picker | 8 |
| sqflite latest snapshot | 3–5, 10 |
| Delete on re-join | 11 |
| View last session result | 13 |
| Read-only offline viewer | 12 |
| share_plus export | 1, 7–8 |
| Error handling (best-effort DB, snackbars) | 10, 12, 8 |
