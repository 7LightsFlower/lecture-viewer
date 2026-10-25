# Saved Lecture Default Name & Home Rename — Design Spec

**Date:** 2026-05-20  
**Project:** `lecture_viewer_v3`  
**Status:** Approved in brainstorming  
**Supersedes (partial):** `2026-05-18-saved-lectures-design.md` — default save name and rename UX only

## Goal

When leaving a lecture session, do not prompt for an event name; auto-save with a locale-friendly date default. On the home saved-lectures list, let users rename bookmarks via an edit control.

## Decisions (brainstorming)

| Topic | Decision |
|-------|----------|
| Default name format | **Localized date:** `DateFormat.yMMMd(locale)` → e.g. `May 20, 2026` (device locale) |
| Same-day duplicates | **Auto suffix:** first `May 20, 2026`; then `May 20, 2026 (2)`, `(3)`, … |
| Save prompt on exit | **Unchanged:** “Save lecture?” (Don’t save / Cancel / Save) |
| Name dialog on exit | **Removed** — Save persists immediately with generated name |
| Rename entry point | **Edit icon** on list row trailing (does not join session) |
| Rename validation | Trimmed name required; empty → Save disabled |
| Duplicate names on rename | **Allowed** — no uniqueness check when user renames |
| Default-name helper location | **`lib/core/saved_lectures/format/`** — testable, shared with notifier |
| Architecture | Notifier + repository `updateDisplayName`; dialog in `saved_lectures_list.dart` |

## Exit save flow

**File:** `lib/features/lecture_session/presentation/save_lecture_on_exit.dart`

1. If `linkRecord` already bookmarked → pop immediately (unchanged).
2. Show “Save lecture?” dialog (unchanged).
3. On **Save**:
   - Read `Localizations.localeOf(context)`.
   - Call `defaultSavedLectureDisplayName(locale:, existingNames: current displayNames from notifier)`.
   - `notifier.add(displayName: generated, linkRecord:, sessionId:)`.
   - On success → pop; on failure → snackbar, stay on session (unchanged).
4. Remove `_SaveNameDialog` and `_showSaveNameDialog`.

## Default display name helper

**New file:** `lib/core/saved_lectures/format/default_saved_lecture_display_name.dart`

```dart
String defaultSavedLectureDisplayName({
  required Locale locale,
  required Iterable<String> existingDisplayNames,
  DateTime? now,
});
```

**Algorithm:**

1. `base = DateFormat.yMMMd(locale.toString()).format(now ?? DateTime.now())` (local calendar date).
2. Collect `existingDisplayNames` where value equals `base` or matches `RegExp(r'^' + escaped(base) + r' \((\d+)\)$')`.
3. If none → return `base`.
4. Else return `base + ' (' + (maxSuffix + 1) + ')'` where `maxSuffix` is 1 for exact `base` match only, or max parsed N from `(N)` suffixes.

**Tests:** `test/core/saved_lectures/default_saved_lecture_display_name_test.dart`

- First of day → `May 20, 2026` (fixed locale `en_US`, fixed `now`).
- With existing `May 20, 2026` → `May 20, 2026 (2)`.
- With `(2)` present → `(3)`.

## Core persistence changes

**`saved_lecture.dart`**

- Extend `copyWith` to accept optional `displayName`.

**`saved_lectures_repository.dart`**

- `Future<bool> updateDisplayName(String id, String displayName)` — trim, reject empty, map by `id`, `_persist`.

**`saved_lectures_provider.dart`**

- `add`: if `displayName` omitted or empty after trim, generate via helper from `state` display names; else use provided trimmed name (keeps explicit override for tests).
- `Future<bool> updateDisplayName(String id, String displayName)` — reload state on success.

## Home list rename

**File:** `lib/features/home/presentation/saved_lectures_list.dart`

**Trailing layout** (`_SavedLectureListTile`):

```text
Row(mainAxisSize: min)
  IconButton(edit)     → _showRenameDialog
  IconButton(snapshot) → unchanged, only if snapshot exists
```

**Rename dialog** (private widget or local function, same pattern as removed save-name dialog):

- Title: `Rename lecture`
- `TextField` initial value = current `displayName`, autofocus, select-all optional
- Cancel / Save (disabled when trimmed empty)
- On Save: `notifier.updateDisplayName(lecture.id, trimmed)`; snackbar on failure

**Interactions unchanged:**

- Checkbox → selection only
- Row `onTap` → join via `openLectureSessionFromLinkRecord` with `lecture.displayName`
- Snapshot button → `LectureSnapshotScreen` (unchanged)

## File layout

```text
lib/core/saved_lectures/format/
  default_saved_lecture_display_name.dart   # new

lib/core/saved_lectures/
  saved_lecture.dart                        # copyWith(displayName)
  saved_lectures_repository.dart            # updateDisplayName
  saved_lectures_provider.dart              # auto-name in add; updateDisplayName

lib/features/lecture_session/presentation/
  save_lecture_on_exit.dart                 # remove name dialog

lib/features/home/presentation/
  saved_lectures_list.dart                  # edit + rename dialog

test/core/saved_lectures/
  default_saved_lecture_display_name_test.dart

test/features/home/
  saved_lectures_list_test.dart             # optional: rename updates title
```

## Out of scope

- Removing or changing the “Save lecture?” confirmation dialog
- Auto-save without user confirmation
- Migrating or renaming existing saved lectures in storage
- Uniqueness enforcement on manual rename
- Changes to join dialog, QR flow, or `link_record` dedupe rules

## Verification (manual)

- [ ] Exit session → Save → no name dialog → home shows localized date title
- [ ] Save two lectures same day → second shows `(2)` suffix
- [ ] Tap edit on home → rename → title updates; re-join shows new name in join dialog
- [ ] Edit icon does not trigger join; row tap still joins
