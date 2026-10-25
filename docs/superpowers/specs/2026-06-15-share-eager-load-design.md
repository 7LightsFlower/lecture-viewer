# Share Sheet — Eager Load per Language

**Date:** 2026-06-15  
**Feature:** lecture_viewer_v3 — Share flow refinement

---

## Goal

When the user selects a language in the share sheet, fetch HTML and generate PDF immediately. The bottom **Share** button only opens the native share sheet with pre-built PDFs.

---

## Product Decisions

| Decision | Choice |
|---|---|
| Load trigger | Checkbox tick → fetch + PDF immediately |
| Success row text | `Ready to share` |
| Loading row text | `Loading data...` |
| Failure row text | `Unexpected error, please retry!` (on row, no snackbar) |
| Failure checkbox | Auto-uncheck |
| Retry | User ticks the language again |
| Uncheck while loading | Cancel HTTP request, reset row |
| Share button enable | ≥1 language checked **and** `ready` |
| Share click | Share all `ready` languages only (skip in-flight) |
| Select all | Tick all immediately; downloads queued |
| Select all concurrency | `kShareSelectAllFetchConcurrency = 2` (adjustable constant) |
| Clear all | Cancel all in-flight downloads, reset all rows |
| Code scope | Minimal diff — logic stays in `lecture_share_sheet.dart` |

---

## Per-Language State

| Status | Checkbox | Subtitle |
|---|---|---|
| `idle` | unchecked | — |
| `loading` | checked | `Loading data...` |
| `ready` | checked | `Ready to share` |
| `failed` | unchecked | `Unexpected error, please retry!` |

---

## Flow

### Single language tick

1. `idle` or `failed` → tick → `loading` → fetch + PDF
2. Success → `ready`, cache `Uint8List` PDF bytes
3. Failure → `failed`, uncheck, show error subtitle
4. Uncheck while `loading` → cancel client, `idle`
5. Uncheck while `ready` → discard PDF, `idle`

### Select all

1. Tick every language immediately (`loading` for non-ready)
2. Queue downloads; at most `kShareSelectAllFetchConcurrency` in flight
3. Each language succeeds or fails independently

### Share

1. Enabled when any language is `ready`
2. Write cached PDF bytes to temp files → `share_plus` → close sheet
3. No re-fetch on share click

---

## Constants

```dart
// cached_text_fetcher.dart
const kShareSelectAllFetchConcurrency = 2;
```

---

## File Changes

| Action | File |
|---|---|
| Modify | `cached_text_fetcher.dart` — add concurrency constant |
| Modify | `lecture_share_sheet.dart` — eager load, cancel, batch select all |
| Modify | `lecture_share_sheet_test.dart` — status subtitle tests (optional) |

No new files. No commit requested.

---

## Cancel Implementation

- Per-language load token incremented on cancel/retry; stale async results ignored
- Dedicated `http.Client` per load; `client.close()` on cancel
- `dispose()` cancels all active clients

---

## Out of Scope

- Snackbar on fetch failure
- Caching API responses across sheet open/close
- Changing entry points or `LectureShareInput`
