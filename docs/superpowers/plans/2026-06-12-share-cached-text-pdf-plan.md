# Share via Cached Text API — PDF Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace local-transcript `.txt` share export with API-fetched HTML → PDF per selected language, on Home, Snapshot, and Live session entry points.

**Architecture:** User selects languages in `LectureShareSheet`. For each selection, parallel `GET /get_cached_text/{sessionId}?window={lang}` → `htmlToPdfBytes` → write temp PDF → `share_plus`. All-or-nothing: any failure aborts the whole share. No local transcript fallback. Minimal diff: add fields/files; keep existing `transcript_share_text.dart` and `ShareTextFileJob`.

**Tech Stack:** Flutter/Dart, `html ^0.15.6`, `pdf ^3.12.0`, `http ^1.2.2`, `share_plus`, `path_provider`

**Spec:** `docs/superpowers/specs/2026-06-12-share-cached-text-pdf-design.md`

---

## File Map

| Action | File |
|--------|------|
| Modify | `pubspec.yaml` |
| Modify | `lib/features/lecture_session/domain/share/lecture_share_input.dart` |
| Create | `lib/features/lecture_session/domain/share/cached_text_fetcher.dart` |
| Create | `lib/features/lecture_session/domain/share/pdf_generator.dart` |
| Modify | `lib/features/lecture_session/domain/share/share_export_worker.dart` |
| Modify | `lib/features/lecture_session/domain/share/meeting_share_filename.dart` |
| Modify | `lib/features/lecture_session/presentation/lecture_share_sheet.dart` |
| Modify | `lib/features/lecture_session/presentation/lecture_share_from_snapshot.dart` |
| Modify | `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart` |
| Modify | `lib/features/lecture_session/presentation/lecture_session_screen.dart` |
| Create | `test/features/lecture_session/domain/share/cached_text_fetcher_test.dart` |
| Create | `test/features/lecture_session/domain/share/pdf_generator_test.dart` |
| Create | `test/features/lecture_session/domain/share/meeting_share_filename_test.dart` |
| Modify | `test/features/lecture_session/lecture_share_sheet_test.dart` |

**Do not delete:** `transcript_share_text.dart`, `ShareTextFileJob`, `writeShareTextFilesIsolate`

---

## Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages under `dependencies:` (after `http: ^1.2.2`)**

```yaml
  html: ^0.15.6
  pdf: ^3.12.0
```

- [ ] **Step 2: Run pub get**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
flutter pub get
```

Expected: resolves without errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add html and pdf packages for share PDF export"
```

---

## Task 2: Extend `LectureShareInput` (additive)

Keep existing `transcript`, `computedSenders`, and helper methods. Add `sessionId` + `httpsOrigin`.

**Files:**
- Modify: `lib/features/lecture_session/domain/share/lecture_share_input.dart`

- [ ] **Step 1: Add two required fields to constructor and class**

```dart
class LectureShareInput {
  const LectureShareInput({
    required this.subject,
    required this.activeLanguages,
    required this.computedSenders,
    required this.transcript,
    required this.sessionId,
    required this.httpsOrigin,
  });

  final String subject;
  final List<String> activeLanguages;
  final Map<String, ComputedSenderInfo> computedSenders;
  final SessionTranscriptState transcript;
  final String sessionId;

  /// e.g. "https://lecture-translator.kit.edu"
  final String httpsOrigin;

  // keep languagesWithShareableContent() and bucketFor() unchanged
}
```

- [ ] **Step 2: Verify analyze (expect errors at call sites until Task 8)**

```bash
flutter analyze lib/features/lecture_session/domain/share/lecture_share_input.dart
```

Expected: no errors in this file.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/domain/share/lecture_share_input.dart
git commit -m "feat: add sessionId and httpsOrigin to LectureShareInput"
```

---

## Task 3: `cached_text_fetcher.dart`

**Files:**
- Create: `lib/features/lecture_session/domain/share/cached_text_fetcher.dart`
- Create: `test/features/lecture_session/domain/share/cached_text_fetcher_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/lecture_session/domain/share/cached_text_fetcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/cached_text_fetcher.dart';

void main() {
  test('returns body on 200', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://example.com/get_cached_text/abc123?window=German',
      );
      return http.Response('<h2>Title</h2>', 200);
    });

    final result = await fetchCachedText(
      httpsOrigin: 'https://example.com',
      sessionId: 'abc123',
      language: 'German',
      client: client,
    );

    expect(result, '<h2>Title</h2>');
  });

  test('encodes window query parameter', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['window'], 'Español');
      return http.Response('<p>ok</p>', 200);
    });

    await fetchCachedText(
      httpsOrigin: 'https://example.com',
      sessionId: 's1',
      language: 'Español',
      client: client,
    );
  });

  test('throws on non-200', () async {
    final client = MockClient((_) async => http.Response('error', 404));

    expect(
      () => fetchCachedText(
        httpsOrigin: 'https://example.com',
        sessionId: 'abc123',
        language: 'German',
        client: client,
      ),
      throwsException,
    );
  });

  test('throws on empty body', () async {
    final client = MockClient((_) async => http.Response('  ', 200));

    expect(
      () => fetchCachedText(
        httpsOrigin: 'https://example.com',
        sessionId: 'abc123',
        language: 'German',
        client: client,
      ),
      throwsException,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/lecture_session/domain/share/cached_text_fetcher_test.dart
```

Expected: compilation error (file not found).

- [ ] **Step 3: Create `cached_text_fetcher.dart`**

```dart
import 'package:http/http.dart' as http;

Future<String> fetchCachedText({
  required String httpsOrigin,
  required String sessionId,
  required String language,
  http.Client? client,
}) async {
  final uri = Uri.parse(httpsOrigin).replace(
    path: '/get_cached_text/$sessionId',
    queryParameters: {'window': language},
  );
  final c = client ?? http.Client();
  final response = await c
      .get(uri)
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw Exception('fetchCachedText: HTTP ${response.statusCode}');
  }
  if (response.body.trim().isEmpty) {
    throw Exception('fetchCachedText: empty response');
  }
  return response.body;
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/features/lecture_session/domain/share/cached_text_fetcher_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/share/cached_text_fetcher.dart \
        test/features/lecture_session/domain/share/cached_text_fetcher_test.dart
git commit -m "feat: add cached_text_fetcher for share API call"
```

---

## Task 4: `pdf_generator.dart`

**Files:**
- Create: `lib/features/lecture_session/domain/share/pdf_generator.dart`
- Create: `test/features/lecture_session/domain/share/pdf_generator_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/lecture_session/domain/share/pdf_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/pdf_generator.dart';

void main() {
  test('produces non-empty PDF bytes from HTML', () async {
    const html = '''
      <h2>Chapter 1</h2>
      <h3>Summary:</h3>
      <ul><li>First bullet</li><li>Second bullet</li></ul>
      <h3>Full content:</h3>
      <p>Some paragraph text here.</p>
    ''';

    final bytes = await htmlToPdfBytes(html);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles empty HTML without throwing', () async {
    final bytes = await htmlToPdfBytes('');
    expect(bytes, isNotEmpty);
  });

  test('handles plain text nodes', () async {
    final bytes = await htmlToPdfBytes('Hello world');
    expect(bytes, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/lecture_session/domain/share/pdf_generator_test.dart
```

Expected: compilation error.

- [ ] **Step 3: Create `pdf_generator.dart`**

```dart
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> htmlToPdfBytes(String htmlContent) async {
  final document = html_parser.parse(htmlContent);
  final body = document.body;
  final widgets = body != null ? _nodeToWidgets(body.nodes) : <pw.Widget>[];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(56.7),
      build: (_) => widgets.isEmpty ? [pw.Text('')] : widgets,
    ),
  );
  return doc.save();
}

List<pw.Widget> _nodeToWidgets(dom.NodeList nodes) {
  final result = <pw.Widget>[];
  for (final node in nodes) {
    final widget = _nodeToWidget(node);
    if (widget != null) result.add(widget);
  }
  return result;
}

pw.Widget? _nodeToWidget(dom.Node node) {
  if (node is dom.Text) {
    final text = node.text.trim();
    if (text.isEmpty) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text, style: _bodyStyle()),
    );
  }

  if (node is dom.Element) {
    switch (node.localName) {
      case 'h2':
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.Text(
            node.text.trim(),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        );
      case 'h3':
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            node.text.trim(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        );
      case 'ul':
      case 'ol':
        final items = node.children
            .where((e) => e.localName == 'li')
            .map(
              (li) => pw.Padding(
                padding: const pw.EdgeInsets.only(left: 16, bottom: 4),
                child: pw.RichText(
                  text: pw.TextSpan(
                    text: '\u2022  ',
                    style: _bodyStyle(),
                    children: [
                      pw.TextSpan(text: li.text.trim(), style: _bodyStyle()),
                    ],
                  ),
                ),
              ),
            )
            .toList();
        if (items.isEmpty) return null;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items,
        );
      case 'p':
        final spans = _inlineSpans(node.nodes);
        if (spans.isEmpty) return null;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.RichText(
            text: pw.TextSpan(children: spans, style: _bodyStyle()),
          ),
        );
      case 'br':
        return pw.SizedBox(height: 4);
      default:
        final children = _nodeToWidgets(node.nodes);
        if (children.isEmpty) return null;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        );
    }
  }
  return null;
}

List<pw.TextSpan> _inlineSpans(dom.NodeList nodes) {
  final spans = <pw.TextSpan>[];
  for (final node in nodes) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        spans.add(pw.TextSpan(text: text, style: _bodyStyle()));
      }
    } else if (node is dom.Element) {
      final isBold = node.localName == 'b' || node.localName == 'strong';
      final childSpans = _inlineSpans(node.nodes);
      if (isBold) {
        for (final s in childSpans) {
          spans.add(
            pw.TextSpan(
              text: s.text,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          );
        }
      } else {
        spans.addAll(childSpans);
      }
    }
  }
  return spans;
}

pw.TextStyle _bodyStyle() => const pw.TextStyle(fontSize: 12);
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/features/lecture_session/domain/share/pdf_generator_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/share/pdf_generator.dart \
        test/features/lecture_session/domain/share/pdf_generator_test.dart
git commit -m "feat: add pdf_generator HTML to PDF conversion"
```

---

## Task 5: Add PDF writer to `share_export_worker.dart` (additive)

Keep existing `ShareTextFileJob` / `writeShareTextFilesIsolate`. Append PDF types.

**Files:**
- Modify: `lib/features/lecture_session/domain/share/share_export_worker.dart`

- [ ] **Step 1: Append PDF classes and isolate function**

Add after existing code (keep all existing imports and text code):

```dart
import 'dart:typed_data';

class SharePdfFileJob {
  const SharePdfFileJob({
    required this.path,
    required this.pdfBytes,
  });

  final String path;
  final Uint8List pdfBytes;
}

class SharePdfWriteResult {
  const SharePdfWriteResult({
    required this.writtenPaths,
    required this.filesWritten,
  });

  final List<String> writtenPaths;
  final int filesWritten;
}

SharePdfWriteResult writeSharePdfFilesIsolate(List<SharePdfFileJob> jobs) {
  final writtenPaths = <String>[];
  for (final job in jobs) {
    File(job.path).writeAsBytesSync(job.pdfBytes, flush: true);
    writtenPaths.add(job.path);
  }
  return SharePdfWriteResult(
    writtenPaths: writtenPaths,
    filesWritten: writtenPaths.length,
  );
}
```

Move `import 'dart:typed_data';` to top of file with other imports.

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/features/lecture_session/domain/share/share_export_worker.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/domain/share/share_export_worker.dart
git commit -m "feat: add SharePdfFileJob isolate writer"
```

---

## Task 6: PDF filename helper

**Files:**
- Modify: `lib/features/lecture_session/domain/share/meeting_share_filename.dart`
- Create: `test/features/lecture_session/domain/share/meeting_share_filename_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/meeting_share_filename.dart';

void main() {
  test('meetingSharePdfFileNameForLanguage produces .pdf extension', () {
    final name = meetingSharePdfFileNameForLanguage(
      DateTime(2026, 6, 12),
      'German',
    );
    expect(name, 'Meeting_2026_06_12_German.pdf');
  });

  test('sanitizes special characters in language name', () {
    final name = meetingSharePdfFileNameForLanguage(
      DateTime(2026, 6, 1),
      'Español (ES)',
    );
    expect(name, startsWith('Meeting_2026_06_01_'));
    expect(name, endsWith('.pdf'));
    expect(name, isNot(contains('(')));
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test test/features/lecture_session/domain/share/meeting_share_filename_test.dart
```

- [ ] **Step 3: Append to `meeting_share_filename.dart`**

```dart
String meetingSharePdfFileNameForLanguage(
  DateTime date,
  String languageDisplayName,
) {
  return '${meetingShareBaseName(date)}_${meetingShareLanguageSuffix(languageDisplayName)}.pdf';
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test test/features/lecture_session/domain/share/meeting_share_filename_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/share/meeting_share_filename.dart \
        test/features/lecture_session/domain/share/meeting_share_filename_test.dart
git commit -m "feat: add meetingSharePdfFileNameForLanguage"
```

---

## Task 7: Update `lecture_share_sheet.dart`

Replace `_shareSelected` with API+PDF path. Simplify language list (all `activeLanguages` selectable). All-or-nothing error handling.

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_share_sheet.dart`

- [ ] **Step 1: Update imports**

Replace:
```dart
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/transcript_share_text.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';
```

With:
```dart
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/cached_text_fetcher.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/pdf_generator.dart';
```

Keep existing imports for `lecture_share_input`, `meeting_share_filename`, `share_export_worker`, `share_plus`, etc.

- [ ] **Step 2: Remove `_languageSelectable` method entirely**

- [ ] **Step 3: Replace `_shareSelected` and add helper**

```dart
  Future<void> _shareSelected() async {
    if (_sharing) return;

    if (_selectedLanguages.isEmpty) {
      _showSnack('Select at least one language');
      return;
    }

    setState(() => _sharing = true);
    final tempPathsToDelete = <String>[];

    try {
      final now = DateTime.now();
      final dir = await getTemporaryDirectory();
      final languages = widget.input.activeLanguages
          .where(_selectedLanguages.contains)
          .toList();

      final jobs = await Future.wait([
        for (final lang in languages)
          _buildPdfJob(
            dirPath: dir.path,
            language: lang,
            now: now,
          ),
      ]);

      for (final job in jobs) {
        tempPathsToDelete.add(job.path);
      }

      final writeResult = await compute(writeSharePdfFilesIsolate, jobs);
      if (!mounted) return;

      if (writeResult.filesWritten == 0) {
        _showSnack('Could not create PDF');
        return;
      }

      final files = writeResult.writtenPaths.map(XFile.new).toList();
      await SharePlus.instance.share(
        ShareParams(files: files, subject: widget.input.subject),
      );

      if (mounted) Navigator.of(context).pop();
    } on Exception catch (_) {
      if (!mounted) return;
      _showSnack('Could not fetch transcript');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open share sheet');
    } finally {
      for (final p in tempPathsToDelete) {
        try {
          final f = File(p);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<SharePdfFileJob> _buildPdfJob({
    required String dirPath,
    required String language,
    required DateTime now,
  }) async {
    final html = await fetchCachedText(
      httpsOrigin: widget.input.httpsOrigin,
      sessionId: widget.input.sessionId,
      language: language,
    );
    Uint8List pdfBytes;
    try {
      pdfBytes = await htmlToPdfBytes(html);
    } catch (_) {
      throw Exception('pdf generation failed');
    }
    final name = meetingSharePdfFileNameForLanguage(now, language);
    return SharePdfFileJob(path: '$dirPath/$name', pdfBytes: pdfBytes);
  }
```

Add `import 'dart:typed_data';` at top.

- [ ] **Step 4: Simplify `build` — language list**

Replace `selectableLanguages` / `_languageSelectable` usage with `widget.input.activeLanguages`:

```dart
  @override
  Widget build(BuildContext context) {
    final languages = widget.input.activeLanguages;

    return Scaffold(
      // ... header unchanged ...
              if (languages.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _sharing
                        ? null
                        : () {
                            setState(() {
                              if (_selectedLanguages.length ==
                                  languages.length) {
                                _selectedLanguages.clear();
                              } else {
                                _selectedLanguages
                                  ..clear()
                                  ..addAll(languages);
                              }
                            });
                          },
                    child: Text(
                      _selectedLanguages.length == languages.length
                          ? 'Clear all'
                          : 'Select all',
                    ),
                  ),
                ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final language in languages)
                      CheckboxListTile(
                        title: Text(language),
                        value: _selectedLanguages.contains(language),
                        enabled: !_sharing,
                        onChanged: _sharing
                            ? null
                            : (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedLanguages.add(language);
                                  } else {
                                    _selectedLanguages.remove(language);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ),
      // ... Share button unchanged ...
    );
  }
```

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/features/lecture_session/presentation/lecture_share_sheet.dart
```

Expected: no errors (call sites fixed in Task 8).

- [ ] **Step 6: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_share_sheet.dart
git commit -m "feat: share via get_cached_text API, export as PDF"
```

---

## Task 8: Wire call sites (Home, Snapshot, Live session)

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_share_from_snapshot.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

Use `resolveSessionUrl` for `httpsOrigin` (handles bare host link records).

- [ ] **Step 1: Update `lecture_share_from_snapshot.dart`**

Add import:
```dart
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
```

Update `LectureShareInput`:
```dart
      input: LectureShareInput(
        subject: displayName,
        activeLanguages: record.activeLanguages,
        computedSenders: record.computedSenders,
        transcript: record.transcript,
        sessionId: record.sessionId,
        httpsOrigin: Uri.parse(resolveSessionUrl(linkRecord)).origin,
      ),
```

- [ ] **Step 2: Update `lecture_snapshot_screen.dart`**

Add import if missing:
```dart
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
```

Update `_onShare()` `LectureShareInput`:
```dart
      input: LectureShareInput(
        subject: widget.displayName,
        activeLanguages: record.activeLanguages,
        computedSenders: record.computedSenders,
        transcript: record.transcript,
        sessionId: record.sessionId,
        httpsOrigin: Uri.parse(resolveSessionUrl(record.linkRecord)).origin,
      ),
```

- [ ] **Step 3: Add share button to `lecture_session_screen.dart`**

Add imports:
```dart
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/lecture_share_input.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_sheet.dart';
```

Add method to `_LectureSessionScreenState`:
```dart
  void _onShare() {
    final state = ref.read(lectureSessionProvider(scope));
    showLectureShareSheet(
      context: context,
      input: LectureShareInput(
        subject: sessionNameFromLinkRecord(linkRecord) ?? state.sessionId,
        activeLanguages: state.activeLanguages,
        computedSenders: state.computedSenders,
        transcript: state.transcript,
        sessionId: state.sessionId,
        httpsOrigin: Uri.parse(resolveSessionUrl(linkRecord)).origin,
      ),
    );
  }
```

Add to AppBar `actions` (before TTS button):
```dart
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _onShare,
            ),
```

- [ ] **Step 4: Full analyze**

```bash
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_share_from_snapshot.dart \
        lib/features/lecture_session/presentation/lecture_snapshot_screen.dart \
        lib/features/lecture_session/presentation/lecture_session_screen.dart
git commit -m "feat: wire share PDF export at all entry points"
```

---

## Task 9: Update widget tests

**Files:**
- Modify: `test/features/lecture_session/lecture_share_sheet_test.dart`

- [ ] **Step 1: Add `sessionId` and `httpsOrigin` to both test fixtures**

```dart
      sessionId: 'test-session',
      httpsOrigin: 'https://example.com',
```

Add after `transcript:` in both `LectureShareInput` constructors.

- [ ] **Step 2: Remove test `'language without normal content shows unavailable subtitle'`**

Delete the entire second `testWidgets` block (lines 73–127). API-based share no longer gates languages by local bucket content.

- [ ] **Step 3: Add test — all active languages are enabled**

```dart
  testWidgets('all active languages are selectable', (tester) async {
    final input = LectureShareInput(
      subject: 'Test lecture',
      activeLanguages: const ['English', 'Transcript'],
      computedSenders: const {},
      transcript: const SessionTranscriptState.empty(),
      sessionId: 'test-session',
      httpsOrigin: 'https://example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () => showLectureShareSheet(
                  context: context,
                  input: input,
                ),
                child: const Text('Open share'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('No transcript is available'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/features/lecture_session/lecture_share_sheet_test.dart \
             test/features/lecture_session/domain/share/
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add test/features/lecture_session/lecture_share_sheet_test.dart
git commit -m "test: update share sheet tests for API PDF share"
```

---

## Task 10: Final verification

- [ ] **Step 1: Run full test suite for lecture_session**

```bash
flutter test test/features/lecture_session/
```

Expected: All PASS.

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/
```

Expected: zero errors.

- [ ] **Step 3: Manual smoke test checklist**

- Home saved lecture → Share → select language → PDF shared
- Snapshot screen → Share → same flow
- Live session → Share button in AppBar → same flow
- Airplane mode → Share → snackbar `Could not fetch transcript`, no crash
- Select 2 languages, one API fails → no share sheet opens (all-or-nothing)

- [ ] **Step 4: Commit (if any fixups)**

```bash
git add -A
git commit -m "fix: address share PDF export review feedback"
```

Only if fixups were needed.

---

## Self-Review Checklist (spec coverage)

| Spec requirement | Task |
|---|---|
| API `get_cached_text` with `window` param | Task 3 |
| HTML → PDF formatting | Task 4 |
| PDF file naming | Task 6 |
| All-or-nothing error handling | Task 7 |
| No local fallback | Task 7 |
| Home + Snapshot + Live entry points | Task 8 |
| Keep `transcript_share_text.dart` | Not deleted |
| Keep `LectureShareInput` transcript fields | Task 2 |
| Helvetica / no Unicode fonts | Task 4 (default pdf fonts) |
| Widget + unit tests | Tasks 3–6, 9 |
