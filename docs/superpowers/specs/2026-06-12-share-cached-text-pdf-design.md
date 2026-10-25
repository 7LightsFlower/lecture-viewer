# Share via Cached Text API — PDF Export

**Date:** 2026-06-12  
**Feature:** lecture_viewer_v3 — Share redesign (Home, Snapshot, Live session)

---

## Goal

Replace the current share export (local transcript → plain `.txt`) with:

1. `GET /get_cached_text/{sessionId}?window={languageDisplayName}` per selected language.
2. Convert HTML response → formatted `.pdf` (headings, bold, bullets, paragraphs).
3. Share PDF files via `share_plus`.

Applies to all three entry points: **Home** (saved lectures), **Snapshot screen**, **Live session** (new share button).

---

## Product Decisions

| Decision | Choice |
|---|---|
| Entry points | Home + Snapshot + Live session |
| Export format | PDF only |
| API failure | Show error, **no** fallback to local transcript |
| Multi-language | **All-or-nothing** — any language fails → abort entire share |
| Font | Helvetica (Latin/European); CJK/Arabic out of scope |
| Code change scope | **Minimal** — add fields/files, do not remove existing transcript code |

---

## API

```
GET {httpsOrigin}/get_cached_text/{sessionId}?window={languageDisplayName}
```

| Param | Source |
|---|---|
| `httpsOrigin` | `Uri.parse(resolveSessionUrl(linkRecord)).origin` |
| `sessionId` | WebSocket session id (stored in `LectureSnapshotRecord` or live `LectureSessionScope`) |
| `window` | Display name from `activeLanguages` as-is (e.g. `English`, `German`, `Transcript`) |

- Timeout: 30 seconds per request.
- Expect: HTTP 200 + non-empty HTML body.
- Parallel fetch via `Future.wait` for all selected languages.

Example response:

```html
<h2>Chapter 1: Title</h2>
<h3>Summary:</h3>
<ul><li>bullet text</li></ul>
<h3>Full content:</h3>
<p>paragraph text...</p>
```

---

## Architecture

```
Entry points (Home / Snapshot / Live session)
    → LectureShareInput (+ sessionId, httpsOrigin)
    → LectureShareSheet (language checkboxes)
    → cached_text_fetcher (parallel HTTP)
    → pdf_generator (HTML → Uint8List)
    → share_export_worker (write temp PDF files)
    → share_plus
```

### `LectureShareInput` — additive change only

Add two required fields; **keep** existing `transcript` and `computedSenders` so call sites need minimal edits:

```dart
final String sessionId;
final String httpsOrigin;  // e.g. "https://lecture-translator.kit.edu"
```

Share sheet no longer reads local transcript for export.

### Call sites

| Entry | `sessionId` | `httpsOrigin` |
|---|---|---|
| Home (`lecture_share_from_snapshot.dart`) | `record.sessionId` | from `linkRecord` |
| Snapshot (`lecture_snapshot_screen.dart`) | `record.sessionId` | from `record.linkRecord` |
| Live session (`lecture_session_screen.dart`) | `scope.sessionId` | from `scope.linkRecord` |

Live session: add `IconButton(Icons.share_outlined)` to AppBar (not wired today).

### Language selection UI

- All `activeLanguages` are selectable (no local-bucket gating).
- Remove `"No transcript is available"` subtitle and `_languageSelectable` bucket checks.
- `window` query param = checkbox label (display name).

---

## PDF Formatting

Pure Dart: `package:html` parse DOM → `package:pdf` `pw.Document`.

| HTML element | PDF styling |
|---|---|
| `<h2>` | Bold 18pt, space above/below |
| `<h3>` | Bold 14pt, space above/below |
| `<li>` | `•  text`, indented, 12pt |
| `<p>`, text node | 12pt, paragraph spacing after |
| `<br>` | line break within paragraph |
| `<b>`, `<strong>` | bold inline via `pw.TextSpan` |

- Font: Helvetica (built-in).
- Page: A4, 2cm margins.
- No CSS, tables, or images.

---

## Share Flow (`_shareSelected`)

1. Validate at least one language selected.
2. `setState(_sharing = true)`.
3. `Future.wait` — fetch + convert each selected language to PDF bytes.
4. **Any** fetch/convert/write failure → snackbar error, **do not** open share sheet.
5. All succeed → `compute(writeSharePdfFilesIsolate, jobs)` → write temp files.
6. `SharePlus.instance.share(files: [...])` → close sheet.
7. `finally`: delete temp files, `_sharing = false`.

### Error messages

| Situation | Snackbar |
|---|---|
| No language selected | `Select at least one language` |
| HTTP ≠ 200 / timeout / empty body | `Could not fetch transcript` |
| PDF generation failure | `Could not create PDF` |
| File write / share failure | `Could not open share sheet` |

No partial share. No local fallback.

### File naming

```dart
String meetingSharePdfFileNameForLanguage(DateTime date, String languageDisplayName);
// → Meeting_2026_06_12_English.pdf
```

Same sanitization as existing `meetingShareTextFileNameForLanguage`, `.pdf` extension.

---

## File Changes (minimal diff)

| Action | File |
|---|---|
| Modify | `pubspec.yaml` — add `html`, `pdf` |
| Modify | `lecture_share_input.dart` — add `sessionId`, `httpsOrigin` |
| **Create** | `cached_text_fetcher.dart` |
| **Create** | `pdf_generator.dart` |
| Modify | `share_export_worker.dart` — add `SharePdfFileJob` + isolate writer |
| Modify | `meeting_share_filename.dart` — add PDF filename helper |
| Modify | `lecture_share_sheet.dart` — API+PDF path in `_shareSelected` |
| Modify | `lecture_share_from_snapshot.dart` — pass new fields |
| Modify | `lecture_snapshot_screen.dart` — pass new fields |
| Modify | `lecture_session_screen.dart` — add share button + pass new fields |

**Do not delete:** `transcript_share_text.dart`, `ShareTextFileJob`, existing text isolate code.

---

## Implementation Detail

### `cached_text_fetcher.dart`

```dart
Future<String> fetchCachedText({
  required String httpsOrigin,
  required String sessionId,
  required String language,
}) async {
  final uri = Uri.parse(httpsOrigin).replace(
    path: '/get_cached_text/$sessionId',
    queryParameters: {'window': language},
  );
  final response = await http.get(uri).timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }
  if (response.body.trim().isEmpty) {
    throw Exception('Empty response');
  }
  return response.body;
}
```

### `pdf_generator.dart`

```dart
Future<Uint8List> htmlToPdfBytes(String html) async {
  final doc = pw.Document();
  final widgets = _htmlToWidgets(html);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(56.7), // ~2cm
    build: (_) => widgets,
  ));
  return doc.save();
}
```

PDF generation on main isolate (before `compute`); isolate only writes bytes to disk.

### `share_export_worker.dart` — additive

```dart
class SharePdfFileJob {
  final String path;
  final Uint8List pdfBytes;
}

SharePdfWriteResult writeSharePdfFilesIsolate(List<SharePdfFileJob> jobs) { ... }
```

---

## Testing

| Test file | Coverage |
|---|---|
| `cached_text_fetcher_test.dart` | URI construction, `window` encoding |
| `pdf_generator_test.dart` | Sample HTML → non-empty PDF bytes |
| `meeting_share_filename_test.dart` | `.pdf` extension |
| `lecture_share_sheet_test.dart` | Update fixtures with `sessionId`/`httpsOrigin`; remove unavailable-subtitle test |

No HTTP mocking in widget tests.

---

## Out of Scope

- Fallback to local transcript (`.txt` or plain PDF).
- Partial share when one language fails.
- Unicode font embedding (CJK, Arabic).
- Deleting `transcript_share_text.dart` or text export code.
- Caching API responses.
- Server-side PDF conversion.
