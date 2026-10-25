# Saved Lectures (Bookmarks) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bookmark lectures on session exit (name + `link_record`), show them on home with always-visible checkboxes and bulk delete, and re-join via the existing join dialog — per `docs/superpowers/specs/2026-05-18-saved-lectures-design.md`.

**Architecture:** `lib/core/saved_lectures/` holds `SavedLecture` model, `SharedPreferences` repository, and Riverpod notifier. `lecture_session` intercepts pop with `PopScope` and save dialogs. `home` renders the list and selection UI. `LectureSessionScreen` gains a required `linkRecord` parameter threaded from `showJoinSessionDialog`.

**Tech stack:** Flutter 3.10+, `flutter_riverpod`, `shared_preferences`, `uuid` (new), existing `lecture_app_link.dart` helpers.

---

## File map

| Path | Responsibility |
|------|----------------|
| `pubspec.yaml` | Add `uuid` dependency |
| `lib/core/saved_lectures/saved_lecture.dart` | Model + JSON |
| `lib/core/saved_lectures/saved_lectures_repository.dart` | Prefs CRUD, dedupe, sort |
| `lib/core/saved_lectures/saved_lectures_provider.dart` | Riverpod notifier |
| `lib/features/lecture_session/presentation/join_session_dialog.dart` | Pass `linkRecord` to screen |
| `lib/features/lecture_session/presentation/save_lecture_on_exit.dart` | Exit + name dialogs |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | `PopScope`, `linkRecord` |
| `lib/features/home/presentation/saved_lectures_list.dart` | List, checkboxes, delete bar |
| `lib/features/home/presentation/home_screen.dart` | Empty vs list |
| `test/core/saved_lectures/saved_lectures_repository_test.dart` | Repository unit tests |
| `test/core/saved_lectures/saved_lectures_provider_test.dart` | Notifier unit tests |
| `test/features/home/home_screen_test.dart` | Update smoke + list case |

---

### Task 1: Add `uuid` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1:** Add under `dependencies:`:

```yaml
  uuid: ^4.5.1
```

- [ ] **Step 2:** Run `flutter pub get` (exit 0).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add uuid for saved lecture ids"
```

---

### Task 2: `SavedLecture` model

**Files:**
- Create: `lib/core/saved_lectures/saved_lecture.dart`
- Create: `test/core/saved_lectures/saved_lecture_test.dart`

- [ ] **Step 1: Write failing JSON round-trip test**

```dart
// test/core/saved_lectures/saved_lecture_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';

void main() {
  test('toJson/fromJson round-trip', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
    );
    final restored = SavedLecture.fromJson(lecture.toJson());
    expect(restored, lecture);
  });
}
```

- [ ] **Step 2:** Run `flutter test test/core/saved_lectures/saved_lecture_test.dart` — expect FAIL (class not defined).

- [ ] **Step 3: Implement model**

```dart
// lib/core/saved_lectures/saved_lecture.dart
class SavedLecture {
  const SavedLecture({
    required this.id,
    required this.displayName,
    required this.linkRecord,
    required this.sessionId,
    required this.savedAt,
  });

  final String id;
  final String displayName;
  final String linkRecord;
  final String sessionId;
  final String savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'linkRecord': linkRecord,
        'sessionId': sessionId,
        'savedAt': savedAt,
      };

  factory SavedLecture.fromJson(Map<String, dynamic> json) {
    return SavedLecture(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      linkRecord: json['linkRecord'] as String,
      sessionId: json['sessionId'] as String,
      savedAt: json['savedAt'] as String,
    );
  }
}
```

- [ ] **Step 4:** Run test — expect PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/saved_lectures/saved_lecture.dart test/core/saved_lectures/saved_lecture_test.dart
git commit -m "feat: add SavedLecture model with JSON serialization"
```

---

### Task 3: `SavedLecturesRepository` (TDD)

**Files:**
- Create: `lib/core/saved_lectures/saved_lectures_repository.dart`
- Create: `test/core/saved_lectures/saved_lectures_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

```dart
// test/core/saved_lectures/saved_lectures_repository_test.dart
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
  }) {
    return SavedLecture(
      id: id,
      displayName: 'Name $id',
      linkRecord: linkRecord,
      sessionId: linkRecord.split('/').last,
      savedAt: savedAt,
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

  test('add persists and load returns newest first', () async {
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
}
```

- [ ] **Step 2:** Run `flutter test test/core/saved_lectures/saved_lectures_repository_test.dart` — expect FAIL.

- [ ] **Step 3: Implement repository**

```dart
// lib/core/saved_lectures/saved_lectures_repository.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'saved_lecture.dart';

const String kSavedLecturesPrefsKey = 'saved_lectures_v1';

class SavedLecturesRepository {
  SavedLecturesRepository(this._prefs);

  final SharedPreferences _prefs;

  List<SavedLecture> load() {
    final raw = _prefs.getString(kSavedLecturesPrefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final lectures = decoded
        .whereType<Map>()
        .map((e) => SavedLecture.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    lectures.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return lectures;
  }

  bool containsLinkRecord(String linkRecord) {
    final normalized = linkRecord.trim();
    return load().any((e) => e.linkRecord.trim() == normalized);
  }

  Future<bool> add(SavedLecture lecture) async {
    final normalized = lecture.linkRecord.trim();
    final existing = load();
    if (existing.any((e) => e.linkRecord.trim() == normalized)) {
      return false;
    }
    final next = [lecture, ...existing];
    return _persist(next);
  }

  Future<void> removeByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final next = load().where((e) => !ids.contains(e.id)).toList();
    await _persist(next);
  }

  Future<bool> _persist(List<SavedLecture> lectures) async {
    final encoded = jsonEncode(lectures.map((e) => e.toJson()).toList());
    return _prefs.setString(kSavedLecturesPrefsKey, encoded);
  }
}
```

- [ ] **Step 4:** Run repository tests — expect PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/saved_lectures/saved_lectures_repository.dart test/core/saved_lectures/saved_lectures_repository_test.dart
git commit -m "feat: persist saved lectures in SharedPreferences"
```

---

### Task 4: `SavedLecturesNotifier` (Riverpod)

**Files:**
- Create: `lib/core/saved_lectures/saved_lectures_provider.dart`
- Create: `test/core/saved_lectures/saved_lectures_provider_test.dart`

- [ ] **Step 1: Write failing provider test**

```dart
// test/core/saved_lectures/saved_lectures_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';

void main() {
  test('add updates provider state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    const linkRecord = 'host/mobile/session/foo-lecture';
    final ok = await container.read(savedLecturesProvider.notifier).add(
          displayName: 'My lecture',
          linkRecord: linkRecord,
          sessionId: 'foo-lecture',
        );
    expect(ok, isTrue);

    final list = container.read(savedLecturesProvider);
    expect(list, hasLength(1));
    expect(list.first.displayName, 'My lecture');
    expect(list.first.linkRecord, linkRecord);
  });
}
```

- [ ] **Step 2:** Run test — expect FAIL.

- [ ] **Step 3: Implement provider**

```dart
// lib/core/saved_lectures/saved_lectures_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_repository.dart';

final savedLecturesProvider =
    NotifierProvider<SavedLecturesNotifier, List<SavedLecture>>(
  SavedLecturesNotifier.new,
);

class SavedLecturesNotifier extends Notifier<List<SavedLecture>> {
  late final SavedLecturesRepository _repository;

  @override
  List<SavedLecture> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    _repository = SavedLecturesRepository(prefs);
    return _repository.load();
  }

  bool containsLinkRecord(String linkRecord) {
    return _repository.containsLinkRecord(linkRecord);
  }

  Future<bool> add({
    required String displayName,
    required String linkRecord,
    required String sessionId,
  }) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) return false;

    final lecture = SavedLecture(
      id: const Uuid().v4(),
      displayName: trimmedName,
      linkRecord: linkRecord.trim(),
      sessionId: sessionId,
      savedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final ok = await _repository.add(lecture);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }

  Future<void> removeByIds(Set<String> ids) async {
    await _repository.removeByIds(ids);
    state = _repository.load();
  }
}
```

- [ ] **Step 4:** Run provider test — expect PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/saved_lectures/saved_lectures_provider.dart test/core/saved_lectures/saved_lectures_provider_test.dart
git commit -m "feat: add savedLecturesProvider for bookmark CRUD"
```

---

### Task 5: Pass `linkRecord` into session screen

**Files:**
- Modify: `lib/features/lecture_session/presentation/join_session_dialog.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

- [ ] **Step 1: Update join dialog signature and push**

```dart
// lib/features/lecture_session/presentation/join_session_dialog.dart
Future<void> showJoinSessionDialog(
  BuildContext context, {
  required String meetingName,
  required String linkRecord,
}) async {
  // ... dialog unchanged ...
  if (join != true || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => LectureSessionScreen(
        sessionId: meetingName,
        linkRecord: linkRecord,
      ),
    ),
  );
}
```

- [ ] **Step 2: Add `linkRecord` to `LectureSessionScreen`**

```dart
class LectureSessionScreen extends StatelessWidget {
  const LectureSessionScreen({
    required this.sessionId,
    required this.linkRecord,
    super.key,
  });

  final String sessionId;
  final String linkRecord;
  // build() unchanged for now — PopScope added in Task 6
}
```

- [ ] **Step 3: Update `open_lecture_session.dart` call site**

```dart
// lib/core/util/open_lecture_session.dart — inside openLectureSessionFromLinkRecord
await showJoinSessionDialog(
  context,
  meetingName: meetingName,
  linkRecord: linkRecord,
);
```

- [ ] **Step 4:** Run `flutter analyze lib/` — no errors on `showJoinSessionDialog` call sites.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/presentation/join_session_dialog.dart \
  lib/features/lecture_session/presentation/lecture_session_screen.dart \
  lib/core/util/open_lecture_session.dart
git commit -m "feat: pass linkRecord into LectureSessionScreen"
```

---

### Task 6: Exit bookmark dialogs + `PopScope`

**Files:**
- Create: `lib/features/lecture_session/presentation/save_lecture_on_exit.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

- [ ] **Step 1: Create exit dialog helpers**

```dart
// lib/features/lecture_session/presentation/save_lecture_on_exit.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';

enum _SavePromptResult { dontSave, save, cancel }

/// Returns true if the session route should pop.
Future<bool> handleLectureSessionExit(
  BuildContext context,
  WidgetRef ref, {
  required String linkRecord,
  required String sessionId,
}) async {
  if (ref.read(savedLecturesProvider.notifier).containsLinkRecord(linkRecord)) {
    return true;
  }

  final prompt = await showDialog<_SavePromptResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save lecture?'),
      content: const Text('Save this lecture to your home screen?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_SavePromptResult.dontSave),
          child: const Text("Don't save"),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_SavePromptResult.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_SavePromptResult.save),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (prompt == null || prompt == _SavePromptResult.cancel) {
    return false;
  }
  if (prompt == _SavePromptResult.dontSave) {
    return true;
  }

  final name = await _showSaveNameDialog(context);
  if (name == null) return false;

  final ok = await ref.read(savedLecturesProvider.notifier).add(
        displayName: name,
        linkRecord: linkRecord,
        sessionId: sessionId,
      );
  if (!context.mounted) return false;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save lecture')),
    );
    return false;
  }
  return true;
}

Future<String?> _showSaveNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _SaveNameDialog(),
  );
}

class _SaveNameDialog extends StatefulWidget {
  const _SaveNameDialog();

  @override
  State<_SaveNameDialog> createState() => _SaveNameDialogState();
}

class _SaveNameDialogState extends State<_SaveNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this lecture'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Lecture name',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Convert `LectureSessionScreen` to `ConsumerWidget` with `PopScope`**

```dart
// lib/features/lecture_session/presentation/lecture_session_screen.dart
import 'save_lecture_on_exit.dart';

class LectureSessionScreen extends ConsumerWidget {
  const LectureSessionScreen({
    required this.sessionId,
    required this.linkRecord,
    super.key,
  });

  final String sessionId;
  final String linkRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await handleLectureSessionExit(
          context,
          ref,
          linkRecord: linkRecord,
          sessionId: sessionId,
        );
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(sessionId)),
        body: Column(
          // ... existing children unchanged ...
        ),
      ),
    );
  }
}
```

- [ ] **Step 3:** Run `flutter analyze lib/features/lecture_session/` — no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/save_lecture_on_exit.dart \
  lib/features/lecture_session/presentation/lecture_session_screen.dart
git commit -m "feat: prompt to save lecture on session exit"
```

---

### Task 7: Home screen list + bulk delete

**Files:**
- Create: `lib/features/home/presentation/saved_lectures_list.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`

- [ ] **Step 1: Create `SavedLecturesList` widget**

```dart
// lib/features/home/presentation/saved_lectures_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';

class SavedLecturesList extends ConsumerStatefulWidget {
  const SavedLecturesList({super.key});

  @override
  ConsumerState<SavedLecturesList> createState() => _SavedLecturesListState();
}

class _SavedLecturesListState extends ConsumerState<SavedLecturesList> {
  final Set<String> _selectedIds = {};

  Future<void> _confirmDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved lectures?'),
        content: Text('Delete $count saved lecture${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(savedLecturesProvider.notifier).removeByIds(_selectedIds);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
  }

  void _toggleSelection(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _openLecture(SavedLecture lecture) async {
    final ok = await openLectureSessionFromLinkRecord(
      context,
      lecture.linkRecord,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lectures = ref.watch(savedLecturesProvider);
    final hasSelection = _selectedIds.isNotEmpty;

    return Column(
      children: [
        if (hasSelection)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('${_selectedIds.length} selected'),
                  const Spacer(),
                  TextButton(
                    onPressed: _confirmDelete,
                    child: Text('Delete selected (${_selectedIds.length})'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: lectures.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              final selected = _selectedIds.contains(lecture.id);
              return ListTile(
                leading: Checkbox(
                  value: selected,
                  onChanged: (v) => _toggleSelection(lecture.id, v),
                ),
                title: Text(lecture.displayName),
                subtitle: Text(lecture.sessionId),
                onTap: () => _openLecture(lecture),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Update `HomeScreen` to `ConsumerWidget` with conditional body**

```dart
// lib/features/home/presentation/home_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'saved_lectures_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // ... _openScanner, _joinTestSession unchanged ...

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedLecturesProvider);
    return Scaffold(
      appBar: AppBar(/* unchanged */),
      body: saved.isEmpty
          ? HomeEmptyBody(/* unchanged */)
          : const SavedLecturesList(),
    );
  }
}
```

- [ ] **Step 3:** Run `flutter analyze lib/features/home/` — no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/saved_lectures_list.dart \
  lib/features/home/presentation/home_screen.dart
git commit -m "feat: show saved lectures on home with bulk delete"
```

---

### Task 8: Update home widget tests

**Files:**
- Modify: `test/features/home/home_screen_test.dart`

- [ ] **Step 1: Override `savedLecturesProvider` in existing test** (empty list — behavior unchanged)

```dart
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';

// inside ProviderScope overrides:
savedLecturesProvider.overrideWith(() => _EmptySavedLecturesNotifier()),

// at bottom of file:
class _EmptySavedLecturesNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [];
}
```

(Add `import` for `SavedLecture` if needed, or return `[]` without subclassing by using a simpler override:)

```dart
savedLecturesProvider.overrideWith(() => _FakeSavedLecturesNotifier()),

class _FakeSavedLecturesNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [];
}
```

- [ ] **Step 2: Add test for non-empty list**

```dart
testWidgets('home shows saved lectures when list non-empty', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  const lecture = SavedLecture(
    id: '1',
    displayName: 'Saved one',
    linkRecord: 'host/mobile/session/foo',
    sessionId: 'foo',
    savedAt: '2026-05-18T12:00:00.000Z',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        savedLecturesProvider.overrideWith(() => _OneSavedLectureNotifier()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Saved one'), findsOneWidget);
  expect(find.text('Scan a lecture QR code'), findsNothing);
});

class _OneSavedLectureNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [
        SavedLecture(
          id: '1',
          displayName: 'Saved one',
          linkRecord: 'host/mobile/session/foo',
          sessionId: 'foo',
          savedAt: '2026-05-18T12:00:00.000Z',
        ),
      ];
}
```

- [ ] **Step 3:** Run `flutter test test/features/home/home_screen_test.dart` — expect PASS.

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/features/home/home_screen_test.dart
git commit -m "test: cover home saved lectures list"
```

---

## Manual verification checklist

- [ ] Join session (QR or test) → back → **Save** → enter name → home shows item (newest first).
- [ ] Re-enter same session → back → **no** save prompt.
- [ ] Tap saved row (not checkbox) → join dialog → session opens.
- [ ] Check two rows → **Delete selected (2)** → confirm → list updates; empty list shows `HomeEmptyBody`.
- [ ] **Don't save** on exit pops without adding.
- [ ] **Cancel** on first dialog stays on session.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Link-only bookmark fields | Task 2–4 |
| Dedupe by `linkRecord` | Task 3, 6 |
| Exit prompt unless saved | Task 6 |
| Empty name, Save disabled | Task 6 `_SaveNameDialog` |
| `linkRecord` on session screen | Task 5–6 |
| Home list + checkboxes | Task 7 |
| Bulk delete + confirm | Task 7 |
| Re-open via join dialog | Task 7 (`openLectureSessionFromLinkRecord`) |
| Newest first sort | Task 3 repository |
| Unit tests | Tasks 2–4, 8 |
