# Saved Lecture Default Name & Home Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-generate locale-friendly date names when saving a lecture on session exit, and let users rename saved lectures from the home list via an edit icon.

**Architecture:** A pure `defaultSavedLectureDisplayName` helper in `lib/core/saved_lectures/format/` handles date formatting and `(2)` suffix collision. `SavedLecturesRepository` / notifier gain `updateDisplayName`. Exit flow drops the name dialog; home list adds edit + rename dialog.

**Tech stack:** Flutter 3.10+, `flutter_riverpod`, `shared_preferences`, `intl` (already in `pubspec.yaml`).

**Spec:** `docs/superpowers/specs/2026-05-20-saved-lecture-default-name-rename-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/core/saved_lectures/format/default_saved_lecture_display_name.dart` | Locale date default + suffix |
| `lib/core/saved_lectures/saved_lecture.dart` | `copyWith(displayName:)` |
| `lib/core/saved_lectures/saved_lectures_repository.dart` | `updateDisplayName` |
| `lib/core/saved_lectures/saved_lectures_provider.dart` | Auto-name in `add`, `updateDisplayName` |
| `lib/features/lecture_session/presentation/save_lecture_on_exit.dart` | Remove name dialog; generate name on Save |
| `lib/features/home/presentation/saved_lectures_list.dart` | Edit icon + rename dialog |
| `test/core/saved_lectures/default_saved_lecture_display_name_test.dart` | Helper unit tests |
| `test/core/saved_lectures/saved_lectures_repository_test.dart` | `updateDisplayName` tests |
| `test/core/saved_lectures/saved_lectures_provider_test.dart` | Notifier rename tests |
| `test/features/home/saved_lectures_list_rename_test.dart` | Edit + rename widget test |

---

### Task 1: Default display name helper

**Files:**
- Create: `lib/core/saved_lectures/format/default_saved_lecture_display_name.dart`
- Create: `test/core/saved_lectures/default_saved_lecture_display_name_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/core/saved_lectures/default_saved_lecture_display_name_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/format/default_saved_lecture_display_name.dart';

void main() {
  const locale = Locale('en', 'US');
  final now = DateTime(2026, 5, 20, 14, 30);

  test('first save of day returns localized date only', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const [],
        now: now,
      ),
      'May 20, 2026',
    );
  });

  test('second save same day appends (2)', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const ['May 20, 2026'],
        now: now,
      ),
      'May 20, 2026 (2)',
    );
  });

  test('third save uses (3) when (2) exists', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const ['May 20, 2026', 'May 20, 2026 (2)'],
        now: now,
      ),
      'May 20, 2026 (3)',
    );
  });

  test('ignores unrelated display names', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const ['Other lecture', 'May 19, 2026'],
        now: now,
      ),
      'May 20, 2026',
    );
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/saved_lectures/default_saved_lecture_display_name_test.dart
```

Expected: compile error — function not defined.

- [ ] **Step 3: Implement helper**

```dart
// lib/core/saved_lectures/format/default_saved_lecture_display_name.dart
import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// Default bookmark title: localized calendar date, with `(2)` suffix on collision.
String defaultSavedLectureDisplayName({
  required Locale locale,
  required Iterable<String> existingDisplayNames,
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final base = DateFormat.yMMMd(locale.toString()).format(when);
  final escaped = RegExp.escape(base);
  final suffixPattern = RegExp('^$escaped \\((\\d+)\\)\$');

  var maxSuffix = 0;
  for (final name in existingDisplayNames) {
    if (name == base) {
      maxSuffix = maxSuffix < 1 ? 1 : maxSuffix;
      continue;
    }
    final match = suffixPattern.firstMatch(name);
    if (match != null) {
      final n = int.parse(match.group(1)!);
      if (n > maxSuffix) maxSuffix = n;
    }
  }

  if (maxSuffix == 0) return base;
  return '$base (${maxSuffix + 1})';
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/saved_lectures/default_saved_lecture_display_name_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/saved_lectures/format/default_saved_lecture_display_name.dart \
  test/core/saved_lectures/default_saved_lecture_display_name_test.dart
git commit -m "feat: default saved lecture display name from locale date"
```

---

### Task 2: Repository `updateDisplayName`

**Files:**
- Modify: `lib/core/saved_lectures/saved_lecture.dart`
- Modify: `lib/core/saved_lectures/saved_lectures_repository.dart`
- Modify: `test/core/saved_lectures/saved_lectures_repository_test.dart`

- [ ] **Step 1: Extend `SavedLecture.copyWith`**

In `lib/core/saved_lectures/saved_lecture.dart`, change `copyWith` to:

```dart
  SavedLecture copyWith({
    String? displayName,
    String? lastJoinedAt,
  }) {
    return SavedLecture(
      id: id,
      displayName: displayName ?? this.displayName,
      linkRecord: linkRecord,
      sessionId: sessionId,
      savedAt: savedAt,
      lastJoinedAt: lastJoinedAt ?? this.lastJoinedAt,
    );
  }
```

- [ ] **Step 2: Write failing repository tests**

Append to `test/core/saved_lectures/saved_lectures_repository_test.dart`:

```dart
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
```

- [ ] **Step 3: Run tests — expect FAIL on new tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/saved_lectures/saved_lectures_repository_test.dart
```

- [ ] **Step 4: Implement `updateDisplayName`**

Add to `lib/core/saved_lectures/saved_lectures_repository.dart` before `_persist`:

```dart
  Future<bool> updateDisplayName(String id, String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return false;

    final existing = load();
    if (!existing.any((e) => e.id == id)) return false;

    final next = existing
        .map((lecture) =>
            lecture.id == id ? lecture.copyWith(displayName: trimmed) : lecture)
        .toList();
    return _persist(next);
  }
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/saved_lectures/saved_lectures_repository_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/saved_lectures/saved_lecture.dart \
  lib/core/saved_lectures/saved_lectures_repository.dart \
  test/core/saved_lectures/saved_lectures_repository_test.dart
git commit -m "feat: update saved lecture display name in repository"
```

---

### Task 3: Notifier auto-name and `updateDisplayName`

**Files:**
- Modify: `lib/core/saved_lectures/saved_lectures_provider.dart`
- Modify: `test/core/saved_lectures/saved_lectures_provider_test.dart`

- [ ] **Step 1: Update `add` signature and auto-name**

In `lib/core/saved_lectures/saved_lectures_provider.dart`:

- Import `dart:ui` and `default_saved_lecture_display_name.dart`.
- Change `add` to:

```dart
  Future<bool> add({
    String? displayName,
    required String linkRecord,
    required String sessionId,
    Locale? locale,
    DateTime? now,
  }) async {
    final trimmedName = displayName?.trim() ?? '';
    final resolvedName = trimmedName.isEmpty
        ? defaultSavedLectureDisplayName(
            locale: locale ?? const Locale('en', 'US'),
            existingDisplayNames: state.map((e) => e.displayName),
            now: now,
          )
        : trimmedName;

    final nowIso = (now ?? DateTime.now()).toUtc().toIso8601String();
    final lecture = SavedLecture(
      id: const Uuid().v4(),
      displayName: resolvedName,
      linkRecord: linkRecord.trim(),
      sessionId: sessionId,
      savedAt: nowIso,
      lastJoinedAt: nowIso,
    );

    final ok = await _repository.add(lecture);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }

  Future<bool> updateDisplayName(String id, String displayName) async {
    final ok = await _repository.updateDisplayName(id, displayName);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }
```

- [ ] **Step 2: Add provider tests**

Append to `test/core/saved_lectures/saved_lectures_provider_test.dart` (follow existing `ProviderContainer` + mock prefs setup in that file):

```dart
  test('add without displayName uses default date name', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(savedLecturesProvider.notifier);
    final ok = await notifier.add(
      linkRecord: 'host/mobile/session/a',
      sessionId: 'a',
      locale: const Locale('en', 'US'),
      now: DateTime(2026, 5, 20),
    );
    expect(ok, isTrue);
    expect(
      container.read(savedLecturesProvider).single.displayName,
      'May 20, 2026',
    );
  });

  test('updateDisplayName updates state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(savedLecturesProvider.notifier);
    await notifier.add(
      displayName: 'Original',
      linkRecord: 'host/mobile/session/a',
      sessionId: 'a',
    );
    expect(
      await notifier.updateDisplayName(
        container.read(savedLecturesProvider).single.id,
        'Renamed',
      ),
      isTrue,
    );
    expect(
      container.read(savedLecturesProvider).single.displayName,
      'Renamed',
    );
  });
```

- [ ] **Step 3: Run provider tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/saved_lectures/saved_lectures_provider_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/saved_lectures/saved_lectures_provider.dart \
  test/core/saved_lectures/saved_lectures_provider_test.dart
git commit -m "feat: auto-name on add and updateDisplayName on notifier"
```

---

### Task 4: Session exit — remove name dialog

**Files:**
- Modify: `lib/features/lecture_session/presentation/save_lecture_on_exit.dart`

- [ ] **Step 1: Replace Save branch**

After user chooses Save, replace name-dialog block with:

```dart
  final locale = Localizations.localeOf(context);
  final existingNames =
      ref.read(savedLecturesProvider).map((e) => e.displayName);
  final generated = defaultSavedLectureDisplayName(
    locale: locale,
    existingDisplayNames: existingNames,
  );

  final ok = await ref.read(savedLecturesProvider.notifier).add(
        displayName: generated,
        linkRecord: linkRecord,
        sessionId: sessionId,
      );
```

- Add import:

```dart
import 'package:lecture_viewer_v3/core/saved_lectures/format/default_saved_lecture_display_name.dart';
```

- [ ] **Step 2: Delete dead code**

Remove `_showSaveNameDialog`, `_SaveNameDialog`, and `_SaveNameDialogState` (entire classes at bottom of file).

- [ ] **Step 3: Analyze**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/save_lecture_on_exit.dart
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/save_lecture_on_exit.dart
git commit -m "feat: auto-generate saved lecture name on session exit"
```

---

### Task 5: Home list rename UI

**Files:**
- Modify: `lib/features/home/presentation/saved_lectures_list.dart`
- Create: `test/features/home/saved_lectures_list_rename_test.dart`

- [ ] **Step 1: Write failing widget test**

```dart
// test/features/home/saved_lectures_list_rename_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/features/home/presentation/saved_lectures_list.dart';

class _RenameTestNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [
        SavedLecture(
          id: 'id-1',
          displayName: 'My lecture',
          linkRecord: 'host/mobile/session/foo',
          sessionId: 'foo',
          savedAt: '2026-05-20T12:00:00.000Z',
          lastJoinedAt: '2026-05-20T12:00:00.000Z',
        ),
      ];

  @override
  Future<bool> updateDisplayName(String id, String displayName) async {
    state = [
      SavedLecture(
        id: 'id-1',
        displayName: displayName,
        linkRecord: 'host/mobile/session/foo',
        sessionId: 'foo',
        savedAt: '2026-05-20T12:00:00.000Z',
        lastJoinedAt: '2026-05-20T12:00:00.000Z',
      ),
    ];
    return true;
  }
}

void main() {
  testWidgets('edit icon opens rename dialog and updates title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(_RenameTestNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: SavedLecturesList())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename lecture'));
    await tester.pumpAndSettle();

    expect(find.text('Rename lecture'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Renamed title');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed title'), findsOneWidget);
    expect(find.text('My lecture'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/home/saved_lectures_list_rename_test.dart
```

- [ ] **Step 3: Implement edit + rename in `saved_lectures_list.dart`**

In `_SavedLectureListTile`:

1. Add `onRename` callback parameter (or handle rename inside stateful parent — simplest: add method on `_SavedLecturesListState`):

```dart
  Future<void> _renameLecture(SavedLecture lecture) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameLectureDialog(initialName: lecture.displayName),
    );
    if (newName == null || !mounted) return;
    final ok = await ref
        .read(savedLecturesProvider.notifier)
        .updateDisplayName(lecture.id, newName);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename lecture')),
      );
    }
  }
```

2. Pass `onRename: () => _renameLecture(lecture)` to `_SavedLectureListTile`.

3. Replace `trailing: snapshotExists.when(...)` with:

```dart
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename lecture',
            onPressed: onRename,
          ),
          ...snapshotExists.when(
            data: (exists) {
              if (!exists) return <Widget>[];
              return [
                IconButton(
                  icon: const Icon(Icons.article_outlined),
                  tooltip: 'View last session result',
                  onPressed: () => _openLastSessionResult(context),
                ),
              ];
            },
            loading: () => const <Widget>[],
            error: (_, __) => const <Widget>[],
          ),
        ],
      ),
```

4. Add dialog widget at bottom of file (mirror removed save-name dialog):

```dart
class _RenameLectureDialog extends StatefulWidget {
  const _RenameLectureDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameLectureDialog> createState() => _RenameLectureDialogState();
}

class _RenameLectureDialogState extends State<_RenameLectureDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename lecture'),
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
          onPressed:
              _canSave ? () => Navigator.of(context).pop(_controller.text.trim()) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run widget test — expect PASS**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/home/saved_lectures_list_rename_test.dart
```

- [ ] **Step 5: Run full saved-lectures + home test suite**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/saved_lectures/ test/features/home/
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/saved_lectures_list.dart \
  test/features/home/saved_lectures_list_rename_test.dart
git commit -m "feat: rename saved lectures from home list edit icon"
```

---

## Manual verification

- [ ] Join session → back → **Save** → no name dialog → home shows `May 20, 2026` (or locale equivalent)
- [ ] Save second lecture same day → title shows `(2)`
- [ ] Tap edit → rename → list title updates
- [ ] Edit does not join; row tap still opens join flow
- [ ] Snapshot button still appears only when snapshot exists

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Locale date default | Task 1, 3, 4 |
| `(2)` suffix collision | Task 1 |
| Keep Save lecture? dialog | Task 4 (unchanged dialog) |
| Remove name dialog on exit | Task 4 |
| `updateDisplayName` persistence | Task 2, 3 |
| Edit icon + rename dialog | Task 5 |
| No rename uniqueness check | Task 2 (no dedupe in update) |
