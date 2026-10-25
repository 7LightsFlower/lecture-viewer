# Saved Lectures (Bookmarks) — Design Spec

**Date:** 2026-05-18  
**Project:** `lecture_viewer_v3`  
**Status:** Approved in brainstorming

## Goal

Let users bookmark live lecture sessions when leaving the session screen, show saved lectures on the home screen, and manage them with always-visible checkboxes and bulk delete. Saved items store only enough data to re-join the live session (no transcript snapshot).

## Decisions (brainstorming)

| Topic | Decision |
|-------|----------|
| What is saved | **Link only:** `displayName`, `linkRecord`, `sessionId`, metadata — no transcript |
| When to prompt | **Every exit** (back / system back) unless this `linkRecord` is already bookmarked |
| Re-open from home | **Same as QR:** `openLectureSessionFromLinkRecord` → join dialog → session screen |
| Multi-select / delete | **Always-visible checkboxes**; “Delete selected (N)” when ≥1 checked; confirm dialog |
| Default save name | **Empty field;** Save disabled until user enters a non-empty trimmed name |
| Architecture | **Approach 1:** `lib/core/saved_lectures/` for model + prefs repository + Riverpod; UI in `home` and `lecture_session` features |
| Meeting list in home spec | Supersedes “meeting list out of scope” from `2026-05-18-home-settings-design.md` for saved bookmarks only |

## Data model

`SavedLecture` (immutable, JSON-serializable):

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | UUID v4, stable row identity |
| `displayName` | `String` | User-entered; trimmed; required on save |
| `linkRecord` | `String` | Full `link_record` value; **dedupe key** |
| `sessionId` | `String` | `meetingNameFromLinkRecord(linkRecord)` |
| `savedAt` | `String` | ISO-8601 UTC; list sorted newest first |

**Persistence:** `shared_preferences`, key `saved_lectures_v1`, value = JSON array of objects.

**Dedupe:** At most one bookmark per `linkRecord`. Repository rejects duplicate adds; exit flow skips prompt if `linkRecord` already exists.

## Core module (`lib/core/saved_lectures/`)

| File | Responsibility |
|------|----------------|
| `saved_lecture.dart` | Model + `toJson` / `fromJson` |
| `saved_lectures_repository.dart` | Load/save list; `add`, `removeByIds`, `containsLinkRecord`, `all` sorted by `savedAt` desc |
| `saved_lectures_provider.dart` | `NotifierProvider` watching prefs; methods used by home + session |

Uses existing `sharedPreferencesProvider` from `lib/core/providers/core_providers.dart`.

## Session navigation change

Today `LectureSessionScreen` only receives `sessionId`. Bookmarking requires `linkRecord` on exit.

**Update** `showJoinSessionDialog` / `Navigator.push` to pass both:

```dart
LectureSessionScreen(
  sessionId: meetingName,
  linkRecord: linkRecord,
)
```

All entry paths that reach the session screen must supply `linkRecord` (QR, Branch, debug join test, home list re-open after join dialog).

## Exit bookmark flow (`lecture_session` feature)

Wrap `LectureSessionScreen` in `PopScope(canPop: false)`.

On pop intent (AppBar back, system back):

1. If `repository.containsLinkRecord(linkRecord)` → `Navigator.pop` immediately.
2. Else show `AlertDialog`:
   - Title: “Save lecture?”
   - Actions: **Don’t save** (pop), **Cancel** (dismiss, stay on session).
   - **Save** opens name step (same dialog with `TextField` or follow-up dialog):
     - Empty default; **Save** disabled until trimmed name is non-empty.
     - On confirm: `notifier.add(SavedLecture(...))` → pop on success.
     - On persist error: snackbar, remain on session.

Extract dialog helpers to `lib/features/lecture_session/presentation/save_lecture_on_exit.dart` (or similar) to keep screen lean.

## Home screen (`home` feature)

**Empty vs list**

- `savedLectures` empty → existing `HomeEmptyBody` (unchanged scan UX).
- Non-empty → `ListView` of saved rows; QR remains in app bar leading.

**Row layout**

- Leading: `Checkbox` (always visible).
- Title: `displayName`.
- Subtitle (optional): `sessionId` or formatted `savedAt`.
- Tap **row** (not checkbox): `openLectureSessionFromLinkRecord(context, linkRecord)`.
- Tap **checkbox**: toggle selection only; no navigation.

**Bulk delete**

- When selection non-empty: show **Delete selected (N)** (bottom bar or app bar).
- Tap → confirm `AlertDialog` → `removeByIds` → clear selection.
- When selection empty: hide delete action.

**State:** Local `Set<String>` of selected `id`s in `HomeScreen` stateful widget or small `StateProvider` scoped to home — not persisted.

## File layout (new / changed)

```text
lib/core/saved_lectures/
  saved_lecture.dart
  saved_lectures_repository.dart
  saved_lectures_provider.dart

lib/features/home/presentation/
  home_screen.dart              # conditional list vs empty
  saved_lectures_list.dart    # list + selection + delete bar
  home_empty_body.dart          # unchanged

lib/features/lecture_session/presentation/
  lecture_session_screen.dart   # PopScope + linkRecord param
  join_session_dialog.dart        # pass linkRecord to screen
  save_lecture_on_exit.dart       # exit dialogs

lib/core/util/open_lecture_session.dart  # unchanged API; home uses linkRecord

test/core/saved_lectures/
  saved_lectures_repository_test.dart
```

## Error handling

| Case | Behavior |
|------|----------|
| Duplicate `linkRecord` on add | No-op or false from repository; should not occur from UI if exit prompt skipped |
| Prefs read/write failure | Snackbar; stay on session when saving; home shows last loaded list or empty |
| Invalid `linkRecord` on re-open | Existing `openLectureSessionFromLinkRecord` returns false; snackbar |

## Testing

**Unit**

- Repository: round-trip JSON, sort order, dedupe, `removeByIds`, `containsLinkRecord`.
- Provider: add/remove updates list exposed to UI.

**Manual**

1. Join session → back → save with name → appears on home (newest first).
2. Back again from same session → no save prompt.
3. Tap saved row → join dialog → live session.
4. Select two checkboxes → delete → confirm → removed from list.
5. Empty list → empty home body returns.

## Out of scope (v1)

- Transcript snapshot or offline replay
- Rename / edit bookmark
- Search, folders, or sync across devices
- Skip join dialog for saved items
- sqlite / hive migration

## Related specs

- `2026-05-18-home-settings-design.md` — home shell; meeting list deferred there, implemented here as bookmarks only
- `2026-05-18-lecture-session-view-design.md` — in-app session view; this spec adds exit save + `linkRecord` on screen
