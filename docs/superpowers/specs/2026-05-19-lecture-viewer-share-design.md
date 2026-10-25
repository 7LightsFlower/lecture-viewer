# Lecture viewer share + offline snapshot — Design Spec

**Date:** 2026-05-19  
**Project:** `lecture_viewer_v3`  
**Status:** Approved in brainstorming

## Goal

Add a **share** feature to the lecture viewer, aligned with `app_2way_v3` session share (transcript export via OS share sheet) but **without audio or summarization**. Persist the **latest** in-session transcript per bookmarked lecture in **sqflite** so users can **view** and **share** offline results from the home list; clear that snapshot when they **re-join live**.

## References

- **2way share (transcript + audio + summary):** `app_2way_v3/docs/superpowers/specs/2026-05-15-translation-session-share-design.md`, `session_share_sheet.dart`
- **2way sqflite history:** `app_2way_v3/lib/features/session_history_list/data/session_history_database.dart`
- **Viewer bookmarks:** `docs/superpowers/specs/2026-05-18-saved-lectures-design.md` (link-only prefs; this spec adds transcript snapshot separately)
- **Transcript model / UI:** `lecture_common` (`SessionTranscriptState`, `TranslationResultTranscriptView`, `transcript_display_format.dart`)
- **Viewer routing:** `lecture_bucket_key.dart`, `lecture_transcript_router.dart`

## Brainstorming decisions

| Topic | Decision |
|-------|----------|
| Parity with 2way | Share bottom sheet, multi-language export, `.txt` files via `share_plus` |
| Audio | **Not available** — no recording toggle, no WAV export |
| Summarization | **Out of scope for v1** |
| Files per language | **One `.txt` per selected language** |
| Module selection | **Per language** — dropdown on each checked language row |
| Offline data | **Latest snapshot only**, keyed by `linkRecord` |
| Storage | **sqflite** (same stack as 2way: `sqflite`, `path_provider`) |
| Snapshot lifetime | **Deleted** when user successfully **re-joins** that lecture live |
| Home UX | **View last session result** on saved row when snapshot exists |
| Offline screen | **Read-only** transcript viewer: language + module pickers, share in AppBar; no WebSocket, TTS, or live controls |
| Architecture | **Dedicated snapshot DB** (`lib/core/lecture_snapshot/`), not prefs |

### Approaches considered

| Approach | Verdict |
|----------|---------|
| **A. Dedicated snapshot DB** (one row per `linkRecord`) | **Chosen** |
| B. Embed transcript in SharedPreferences `SavedLecture` | Rejected — large blobs, wrong store |
| C. Full multi-row history like 2way | Rejected — contradicts “latest only” |

## Goals and non-goals

**Goals**

- AppBar **Share** on live `LectureSessionScreen` and offline `LectureSnapshotScreen`.
- Bottom sheet: include transcript (default on), multi-select languages, **per-language module** dropdown, export via `share_plus`.
- Debounced **upsert** of full session transcript state to sqflite during live viewing.
- Home list button **View last session result** when a snapshot exists.
- Clear snapshot on live re-join.

**Non-goals**

- Session audio / WAV sharing.
- LT2SRV summarization `.md` files.
- TTS playback from snapshot.
- Multiple historical versions per lecture.
- Changing bookmark persistence (still `shared_preferences` for `SavedLecture`).

## Data model

### Snapshot row (`lecture_snapshots`)

Primary key: **`link_record`** (same value as `SavedLecture.linkRecord`).

| Column | Type | Notes |
|--------|------|-------|
| `link_record` | `TEXT PK` | Dedupe key |
| `session_id` | `TEXT` | `meetingNameFromLinkRecord(linkRecord)` at write time |
| `updated_at_utc` | `TEXT` | ISO-8601 UTC |
| `transcript_json` | `TEXT` | `SessionTranscriptState.toJson()` — all `language\|rawSender` buckets |
| `computed_senders_json` | `TEXT` | JSON map of `ComputedSenderInfo` (add `toJson` / `fromJson` on viewer model) |
| `active_languages_json` | `TEXT` | JSON array of language display names |
| `selected_language` | `TEXT` | Last live UI selection |
| `selected_raw_sender` | `TEXT` | Last live UI selection |

`LectureSnapshotRecord` — immutable Dart type assembled from a row.

**Semantics:** `upsert` always replaces the single row for a `linkRecord` (“latest session data only”).

### Bookmarks (unchanged)

`SavedLecture` in SharedPreferences remains **link-only**. Snapshot rows are independent; deleting a bookmark does not require deleting a snapshot (optional cleanup on bookmark delete is out of scope unless needed for consistency).

## Core module (`lib/core/lecture_snapshot/`)

| File | Responsibility |
|------|----------------|
| `lecture_snapshot_database.dart` | `openLectureSnapshotDatabase()`, schema v1, test hooks |
| `lecture_snapshot_record.dart` | Record + JSON helpers for nested fields |
| `lecture_snapshot_repository.dart` | `upsert`, `get`, `delete`, `exists` |
| `lecture_snapshot_provider.dart` | `FutureProvider<LectureSnapshotRepository>` |

**DB file:** `lecture_snapshots.db` under app documents (mirror 2way `session_history.db` placement).

## Live session — persistence lifecycle

```text
Transcript / sender / language change (LectureSessionNotifier)
  → debounce 200ms (same as 2way)
  → LectureSnapshotRepository.upsert(linkRecord, LectureSessionState fields)
```

- Requires `linkRecord` on `LectureSessionScreen` (already passed for exit bookmark flow).
- Failures: **best-effort** — swallow errors; do not block live UI.

**Delete snapshot**

- When live join **succeeds** for a `linkRecord` (`openLectureSessionFromLinkRecord` or equivalent success path): `delete(linkRecord)` **before** navigating to `LectureSessionScreen`.
- User starts fresh; home **View last session result** hides until a new snapshot is written.

## UI

### Live session (`LectureSessionScreen`)

- AppBar `actions`: `IconButton(Icons.share_outlined)` → `showLectureShareSheet(context, shareInput)`.
- `shareInput` includes: `displayName` or `sessionId` (subject), `activeLanguages`, `computedSenders`, `transcript`, default selections.

### Offline viewer (`LectureSnapshotScreen`)

**Route args:** `linkRecord`, `displayName`.

**Load:** `get(linkRecord)`; if null → SnackBar “No saved result”, pop.

**Layout:**

- AppBar: title = `displayName`; **Share** + back.
- Language dropdown + module dropdown (reuse `moduleOptionsForLanguage`, `moduleDisplayLabel`, `activeBucketKeyForSelection`).
- Body: `TranslationResultTranscriptView` with `textScale` from `appSettingsProvider`.
- **No** `LectureSessionControls` TTS/WS, no error/retry banner, no `PopScope` save dialog.

**State:** Local state seeded from `LectureSnapshotRecord` (StatefulWidget or small notifier); selection changes only affect display + share defaults, not DB until next live session.

### Home list (`SavedLecturesList`)

- Per row: if `exists(linkRecord)` → show **View last session result** (`TextButton` or trailing; separate from row `onTap`).
- **View last session result** → `Navigator.push` → `LectureSnapshotScreen`.
- Row tap → existing live join flow (unchanged).

## Share sheet (`showLectureShareSheet`)

**Dependency:** `share_plus: ^13.1.0` (match 2way).

**UI:** `showModalBottomSheet`, drag handle, title **Share**.

| Control | Behavior |
|---------|----------|
| Include transcript | Default **on**; only export type in v1 |
| Language rows | `CheckboxListTile` per language with any shareable bucket |
| Module | When language checked → `DropdownButton` of modules with content for that language |
| Module default | Saved `selected_raw_sender` for that language if still valid; else first `moduleOptionsForLanguage` entry |
| Select all / Clear all | Same UX as 2way share sheet |
| Share | Build temp files → `SharePlus.instance.share` → delete temps |

**Disabled row:** subtitle **No transcript yet** when no module has shareable content.

**Validation**

- At least one language selected.
- Include transcript on → at least one selected language+module has content.
- On failure: SnackBar; do not crash session.

### Export pipeline (`lib/features/lecture_session/domain/share/`)

Port from 2way with `lecture_common` types:

| Symbol | Role |
|--------|------|
| `bucketHasShareableContent` | Same rules as 2way / `transcriptBucketHasDisplayableContent` |
| `formatTranscriptBucketForShare` | Plain text mirroring `TranslationResultTranscriptView` / `transcript_display_format.dart` |
| `meeting_share_filename.dart` | `Meeting_YYYY_MM_DD_<Language>.txt` naming (copy or thin re-export) |
| `share_export_worker.dart` | `compute(writeShareTextFilesIsolate, jobs)` |

```dart
await SharePlus.instance.share(
  ShareParams(
    files: xFiles,
    subject: displayName,
  ),
);
```

**Live and offline** use the same sheet; input shape is shared (`LectureShareInput` or equivalent bundling transcript + senders + languages + subject).

## Error handling

| Situation | Behavior |
|-----------|----------|
| Snapshot DB write fails (live) | Swallow; live UI unaffected |
| Snapshot missing when opening offline | SnackBar “No saved result”; do not push screen |
| `share_plus` / export fails | SnackBar “Could not open share sheet” |
| No content for selection | Disable row or SnackBar on Share tap |
| Temp files | Delete after share completes (2way pattern) |

## File layout

```text
lib/core/lecture_snapshot/
  lecture_snapshot_database.dart
  lecture_snapshot_record.dart
  lecture_snapshot_repository.dart
  lecture_snapshot_provider.dart

lib/features/lecture_session/
  domain/share/
    transcript_share_text.dart
    meeting_share_filename.dart
    share_export_worker.dart
  presentation/
    lecture_share_sheet.dart
    lecture_snapshot_screen.dart

lib/features/lecture_session/presentation/
  lecture_session_screen.dart          # AppBar share
  providers/lecture_session_notifier.dart  # debounced upsert

lib/features/home/presentation/
  saved_lectures_list.dart             # View last session result

lib/core/util/open_lecture_session.dart  # delete snapshot on join success

test/core/lecture_snapshot/
  lecture_snapshot_repository_test.dart
test/features/lecture_session/
  transcript_share_text_test.dart
  lecture_share_sheet_test.dart
test/features/home/
  saved_lectures_list_snapshot_button_test.dart
```

**pubspec.yaml:** add `share_plus`, `sqflite`, `path`; dev: `sqflite_common_ffi` for tests.

## Testing

**Unit**

- `LectureSnapshotRepository`: upsert overwrites, get round-trip, delete, exists (in-memory DB).
- `formatTranscriptBucketForShare`: paragraphs, speaker labels, partial tail (mirror 2way tests).
- `ComputedSenderInfo` JSON round-trip.

**Widget**

- Live session AppBar shows share icon.
- Share sheet: checking a language shows module dropdown.
- Home: **View last session result** visible iff `exists(linkRecord)`.

**Manual**

1. Join live lecture → transcript accumulates → leave → snapshot exists → home shows **View last session result**.
2. Open offline viewer → switch language/module → transcript updates → Share → `.txt` per language in OS sheet.
3. Re-join same lecture from home → snapshot cleared → button hidden until new data written.
4. Live session Share during viewing works without opening offline screen.

## Related spec updates

- `2026-05-18-saved-lectures-design.md` **Out of scope** item “Transcript snapshot or offline replay” is **superseded** by this spec for viewer v1 snapshot + offline view. Bookmark storage remains prefs-only.

## Implementation note

After this spec is approved, use the **writing-plans** skill to produce `docs/superpowers/plans/2026-05-19-lecture-viewer-share-implementation-plan.md`.
