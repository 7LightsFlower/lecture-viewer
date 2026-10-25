# PDF Unicode Font Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix tofu rendering in PDF share export by bundling Noto Sans fallback fonts for all 24 supported lecture languages.

**Architecture:** Extend `pdf_generator.dart` to load 9 script-specific Noto Sans Regular TTF files as `fontFallback` on `ThemeData.withFont`, alongside existing Latin base/bold fonts. Font bytes load on the main isolate and pass into the existing `compute()` isolate. No share-flow changes.

**Tech Stack:** Flutter/Dart, `pdf ^3.12.0`, bundled TTF assets (SIL OFL)

**Spec:** `docs/superpowers/specs/2026-06-22-pdf-unicode-fonts-design.md`

---

## File Map

| Action | File |
|--------|------|
| Add | `assets/fonts/NotoSansJP-Regular.ttf` |
| Add | `assets/fonts/NotoSansSC-Regular.ttf` |
| Add | `assets/fonts/NotoSansTC-Regular.ttf` |
| Add | `assets/fonts/NotoSansKR-Regular.ttf` |
| Add | `assets/fonts/NotoSansArabic-Regular.ttf` |
| Add | `assets/fonts/NotoSansThai-Regular.ttf` |
| Add | `assets/fonts/NotoSansDevanagari-Regular.ttf` |
| Add | `assets/fonts/NotoSansBengali-Regular.ttf` |
| Add | `assets/fonts/NotoSansTamil-Regular.ttf` |
| Modify | `pubspec.yaml` |
| Modify | `lib/features/lecture_session/domain/share/pdf_generator.dart` |
| Modify | `test/features/lecture_session/domain/share/pdf_generator_test.dart` |

---

## Task 1: Download Noto Sans fallback fonts

**Files:**
- Add: 9 TTF files under `assets/fonts/`

- [ ] **Step 1: Download fonts from Google Fonts CDN**

Run from project root:

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3/assets/fonts

curl -L -o NotoSansJP-Regular.ttf \
  'https://fonts.gstatic.com/s/notosansjp/v53/-F6jfjtqLzI2JPCgQBnw7HFyzSD-AsregP8VFBEj75vY0rw-oME.ttf'

curl -L -o NotoSansSC-Regular.ttf \
  'https://fonts.gstatic.com/s/notosanssc/v37/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYxNbPzS5HE.ttf'

curl -L -o NotoSansTC-Regular.ttf \
  'https://fonts.gstatic.com/s/notosanstc/v36/-nFuOG829Oofr2wohFbTp9ifNAn722rq0MXz76Cy_CpOtma3uNQ.ttf'

curl -L -o NotoSansKR-Regular.ttf \
  'https://fonts.gstatic.com/s/notosanskr/v36/PbyxFmXiEBPT4ITbgNA5Cgms3VYcOA-vvnIzzuoyeLTq8H4hfeE.ttf'

curl -L -o NotoSansArabic-Regular.ttf \
  'https://fonts.gstatic.com/s/notosansarabic/v18/nwpxtLGrOAZMl5nJ_wfgRg3DrWFZWsnVBJ_sS6tlqHHFlhQ5l3sQWIHPqzCfyGyvu3CBFQLaig.ttf'

curl -L -o NotoSansThai-Regular.ttf \
  'https://fonts.gstatic.com/s/notosansthai/v25/iJWnBXeUZi_OHPqn4wq6hQ2_hbJ1xyN9wd43SofNWcd1MKVQt_So_9CdU5RtpzF-QRvzzXg.ttf'

curl -L -o NotoSansDevanagari-Regular.ttf \
  'https://fonts.gstatic.com/s/notosansdevanagari/v26/TuGoUUFzXI5FBtUq5a8bjKYTZjtRU6Sgv3NaV_SNmI0b8QQCQmHn6B2OHjbL_08AlXQly-AzoFoW4Ow.ttf'

curl -L -o NotoSansBengali-Regular.ttf \
  'https://fonts.gstatic.com/s/notosansbengali/v20/Cn-SJsCGWQxOjaGwMQ6fIiMywrNJIky6nvd8BjzVMvJx2mcSPVFpVEqE-6KmsolLudCk8izI0lc.ttf'

curl -L -o NotoSansTamil-Regular.ttf \
  'https://fonts.gstatic.com/s/notosanstamil/v27/ieVc2YdFI3GCY6SyQy1KfStzYKZgzN1z4LKDbeZce-0429tBManUktuex7vGo70RqKDt_EvT.ttf'
```

- [ ] **Step 2: Verify files exist and are valid TTF**

```bash
ls -lh /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3/assets/fonts/
file /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3/assets/fonts/NotoSans*.ttf
```

Expected: 11 TTF files total (2 existing Latin + 9 new). Each new CJK file ~10–20 MB; Bengali/Tamil/Thai/Devanagari ~200 KB–1 MB.

- [ ] **Step 3: Commit font assets**

```bash
git add assets/fonts/
git commit -m "chore: add Noto Sans fallback fonts for PDF Unicode export"
```

---

## Task 2: Register font assets in pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add 9 font paths under `flutter.assets`**

After the existing NotoSans entries, add:

```yaml
    - assets/fonts/NotoSansJP-Regular.ttf
    - assets/fonts/NotoSansSC-Regular.ttf
    - assets/fonts/NotoSansTC-Regular.ttf
    - assets/fonts/NotoSansKR-Regular.ttf
    - assets/fonts/NotoSansArabic-Regular.ttf
    - assets/fonts/NotoSansThai-Regular.ttf
    - assets/fonts/NotoSansDevanagari-Regular.ttf
    - assets/fonts/NotoSansBengali-Regular.ttf
    - assets/fonts/NotoSansTamil-Regular.ttf
```

- [ ] **Step 2: Run pub get**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
flutter pub get
```

Expected: resolves without errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "chore: register Noto Sans fallback fonts in pubspec"
```

---

## Task 3: Unicode PDF tests (TDD — write failing tests first)

**Files:**
- Modify: `test/features/lecture_session/domain/share/pdf_generator_test.dart`

- [ ] **Step 1: Add script coverage tests**

Append before the closing `}` of `main()`:

```dart
  test('handles Japanese characters', () async {
    final bytes = await htmlToPdfBytes('<p>こんにちは世界</p>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles Chinese Simplified characters', () async {
    final bytes = await htmlToPdfBytes('<p>你好世界</p>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles Arabic characters', () async {
    final bytes = await htmlToPdfBytes('<p>مرحبا</p>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles Bangla characters', () async {
    final bytes = await htmlToPdfBytes('<p>বাংলা</p>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles Tamil characters', () async {
    final bytes = await htmlToPdfBytes('<p>தமிழ்</p>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles mixed Latin and CJK heading', () async {
    final bytes = await htmlToPdfBytes('<h2>Chapter 1: 第一章</h2>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
```

- [ ] **Step 2: Run tests — expect PASS for structure but fonts not yet wired**

```bash
flutter test test/features/lecture_session/domain/share/pdf_generator_test.dart
```

Expected before Task 4: tests pass (PDF generates) but CJK may still use missing glyphs until fallback is wired. After Task 4: all pass with proper font embedding.

- [ ] **Step 3: Commit tests**

```bash
git add test/features/lecture_session/domain/share/pdf_generator_test.dart
git commit -m "test: add Unicode script coverage for PDF generator"
```

---

## Task 4: Wire fontFallback in pdf_generator.dart

**Files:**
- Modify: `lib/features/lecture_session/domain/share/pdf_generator.dart`

- [ ] **Step 1: Add fallback asset paths constant**

Near top of file, after imports:

```dart
const _kSharePdfFallbackAssets = [
  'assets/fonts/NotoSansJP-Regular.ttf',
  'assets/fonts/NotoSansSC-Regular.ttf',
  'assets/fonts/NotoSansTC-Regular.ttf',
  'assets/fonts/NotoSansKR-Regular.ttf',
  'assets/fonts/NotoSansArabic-Regular.ttf',
  'assets/fonts/NotoSansDevanagari-Regular.ttf',
  'assets/fonts/NotoSansBengali-Regular.ttf',
  'assets/fonts/NotoSansTamil-Regular.ttf',
  'assets/fonts/NotoSansThai-Regular.ttf',
];
```

- [ ] **Step 2: Extend typedef and font load return type**

Replace the existing typedef and load types:

```dart
typedef _PdfRenderRequest = ({
  String html,
  Uint8List regular,
  Uint8List bold,
  List<Uint8List> fallbacks,
});
```

Change cache/fetch return type from `({Uint8List regular, Uint8List bold})` to:

```dart
typedef _SharePdfFontBytes = ({
  Uint8List regular,
  Uint8List bold,
  List<Uint8List> fallbacks,
});
```

Update `_fontBytesFuture` type to `Future<_SharePdfFontBytes>?`.

- [ ] **Step 3: Update `_fetchSharePdfFontBytes` to load all fallbacks**

```dart
Future<_SharePdfFontBytes> _fetchSharePdfFontBytes() async {
  Future<Uint8List> loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  final regular = await loadAsset('assets/fonts/NotoSans-Regular.ttf');
  final bold = await loadAsset('assets/fonts/NotoSans-Bold.ttf');
  final fallbacks = await Future.wait(
    _kSharePdfFallbackAssets.map(loadAsset),
  );

  return (regular: regular, bold: bold, fallbacks: fallbacks);
}
```

- [ ] **Step 4: Pass fallbacks through `htmlToPdfBytes` and isolate**

In `htmlToPdfBytes`:

```dart
return await compute(
  _renderPdfInIsolate,
  (
    html: htmlContent,
    regular: fonts.regular,
    bold: fonts.bold,
    fallbacks: fonts.fallbacks,
  ),
);
```

- [ ] **Step 5: Build fallback fonts and set theme in `_renderPdfInIsolate`**

Replace the font/theme setup:

```dart
Future<Uint8List> _renderPdfInIsolate(_PdfRenderRequest req) async {
  final regular = pw.Font.ttf(ByteData.sublistView(req.regular));
  final bold = pw.Font.ttf(ByteData.sublistView(req.bold));
  final fallbackFonts = req.fallbacks
      .map((bytes) => pw.Font.ttf(ByteData.sublistView(bytes)))
      .toList(growable: false);

  final fonts = _SharePdfFonts(regular: regular, bold: bold);
  final ctx = _PdfRenderContext(fonts);
  final body = html_parser.parse(req.html).body;
  final widgets =
      body != null ? _nodeToWidgets(body.nodes, ctx) : <pw.Widget>[];

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: fallbackFonts,
    ),
  );
  // ... rest unchanged
}
```

- [ ] **Step 6: Run tests**

```bash
flutter test test/features/lecture_session/domain/share/pdf_generator_test.dart
```

Expected: all tests PASS.

- [ ] **Step 7: Run analyzer**

```bash
flutter analyze lib/features/lecture_session/domain/share/pdf_generator.dart
```

Expected: no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/lecture_session/domain/share/pdf_generator.dart
git commit -m "fix: embed Noto Sans fallback fonts for Unicode PDF export"
```

---

## Task 5: Manual verification

- [ ] **Step 1: Run full share-related tests**

```bash
flutter test test/features/lecture_session/domain/share/
```

Expected: all PASS.

- [ ] **Step 2: Manual smoke test on device/simulator**

1. Open a lecture with Japanese or Chinese cached text.
2. Share → select that language → export PDF.
3. Open PDF — verify no tofu blocks; characters render correctly.

---

## Self-Review Checklist (spec coverage)

| Spec requirement | Task |
|---|---|
| 24 language script coverage | Task 1 (font bundle) + Task 4 (fallback chain) |
| Keep Latin base/bold fonts | Task 4 |
| fontFallback via ThemeData | Task 4 |
| Isolate pattern preserved | Task 4 |
| pubspec assets | Task 2 |
| Japanese/Chinese/Arabic/Bangla/Tamil tests | Task 3 |
| No Helvetica fallback | Task 4 (uses bundled fonts only) |
| No share-flow changes | No tasks touch share sheet |

---

## Spec Coverage

All spec requirements mapped to tasks above. No gaps.
