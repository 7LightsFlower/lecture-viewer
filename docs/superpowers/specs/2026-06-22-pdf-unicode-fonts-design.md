# PDF Unicode Font Support — Share Export

**Date:** 2026-06-22  
**Feature:** lecture_viewer_v3 — Fix tofu rendering in PDF export for all supported languages

---

## Goal

PDF export via Share sheet must render all characters correctly for **every language** the lecture system supports (24 languages). No network dependency for fonts. No fallback to Helvetica.

---

## Supported Languages (24)

| Language | Code | Font coverage |
|---|---|---|
| Arabic | ar | `NotoSansArabic` |
| Bangla | bn | `NotoSansBengali` |
| Chinese | zh | `NotoSansSC` |
| Chinese (Traditional) | zh_tw | `NotoSansTC` |
| Danish | da | `NotoSans` (Latin) |
| Dutch | nl | `NotoSans` (Latin) |
| English | en | `NotoSans` (Latin) |
| Filipino | tl | `NotoSans` (Latin) |
| French | fr | `NotoSans` (Latin) |
| German | de | `NotoSans` (Latin) |
| Greek | el | `NotoSans` (Greek) |
| Hindi | hi | `NotoSansDevanagari` |
| Italian | it | `NotoSans` (Latin) |
| Japanese | ja | `NotoSansJP` |
| Korean | ko | `NotoSansKR` |
| Persian | fa | `NotoSansArabic` (Arabic script) |
| Portuguese | pt | `NotoSans` (Latin) |
| Russian | ru | `NotoSans` (Cyrillic) |
| Spanish | es | `NotoSans` (Latin) |
| Tamil | ta | `NotoSansTamil` |
| Thai | th | `NotoSansThai` |
| Turkish | tr | `NotoSans` (Latin) |
| Ukrainian | uk | `NotoSans` (Cyrillic) |
| Vietnamese | vi | `NotoSans` (Latin + diacritics) |

---

## Problem

`pdf_generator.dart` embeds `NotoSans-Regular.ttf` and `NotoSans-Bold.ttf` (~556 KB each). These are **Noto Sans Latin** — they cover Latin, Greek, Cyrillic, and Vietnamese diacritics but **not CJK, Arabic, Bengali, Tamil, etc.** Missing glyphs render as tofu (rectangles with X).

Original share PDF spec (2026-06-12) explicitly excluded CJK. This spec supersedes that font decision.

---

## Product Decision

| Decision | Choice |
|---|---|
| Approach | **C1** — bundle local fonts with `fontFallback` chain |
| Base fonts | Keep existing `NotoSans-Regular.ttf` + `NotoSans-Bold.ttf` |
| Fallback fonts | Regular only: JP, SC, TC, KR, Arabic, Thai, Devanagari, Bengali, Tamil |
| Bold CJK headings | Accept regular-weight CJK in `<h2>`/`<h3>` (Latin bold still works for Latin text) |
| App size increase | ~66–71 MB |
| Offline | Required — fonts bundled, no Google Fonts API |
| Scope | `pdf_generator.dart`, `pubspec.yaml`, font assets, tests only |

---

## Font Bundle

Add to `assets/fonts/` (SIL Open Font License — free to bundle):

| Asset file | Script / languages | Size (approx.) |
|---|---|---|
| `NotoSansJP-Regular.ttf` | Japanese | ~16 MB |
| `NotoSansSC-Regular.ttf` | Chinese Simplified | ~16 MB |
| `NotoSansTC-Regular.ttf` | Chinese Traditional | ~16 MB |
| `NotoSansKR-Regular.ttf` | Korean | ~16 MB |
| `NotoSansArabic-Regular.ttf` | Arabic, Persian | ~1.5 MB |
| `NotoSansThai-Regular.ttf` | Thai | ~200 KB |
| `NotoSansDevanagari-Regular.ttf` | Hindi | ~200 KB |
| `NotoSansBengali-Regular.ttf` | Bangla | ~400 KB |
| `NotoSansTamil-Regular.ttf` | Tamil | ~400 KB |

**Source:** [Google Fonts — Noto Sans](https://fonts.google.com/noto) (download Regular weight for each family).

Keep existing:
- `NotoSans-Regular.ttf`
- `NotoSans-Bold.ttf`

**Total new size:** ~66–71 MB.

---

## Architecture

No change to share flow. Only the font loading and PDF theme inside `pdf_generator.dart`.

```
htmlToPdfBytes(html)
  → _loadSharePdfFontBytes()          // main isolate: load 11 TTF files from assets
  → compute(_renderPdfInIsolate, ...)  // pass bytes to isolate
  → pw.ThemeData.withFont(
       base: notoSansRegular,
       bold: notoSansBold,
       fontFallback: [jp, sc, tc, kr, arabic, devanagari, bengali, tamil, thai],
     )
  → HTML DOM → pw.Widget tree → PDF bytes
```

The `pdf` package selects the first font in the fallback chain that contains each rune. Latin/Greek/Cyrillic text uses the base font; other scripts use the matching fallback.

Existing isolate pattern is preserved: fonts loaded on main isolate, bytes serialized into `compute()`.

---

## Code Changes

| Action | File |
|---|---|
| Modify | `lib/features/lecture_session/domain/share/pdf_generator.dart` |
| Modify | `pubspec.yaml` — register 9 new font assets |
| Add | 9 font files under `assets/fonts/` |
| Modify | `test/features/lecture_session/domain/share/pdf_generator_test.dart` |

### `pdf_generator.dart` changes

1. Extend font load record to include `fallbacks: List<Uint8List>`.
2. Load all 9 fallback TTF files in `_fetchSharePdfFontBytes()`.
3. In `_renderPdfInIsolate`, create `pw.Font.ttf()` for each fallback.
4. Pass `fontFallback` to `pw.ThemeData.withFont(...)`.
5. `_PdfRenderContext.body()` / `.bold()` unchanged — styles inherit `fontFallback` from document theme.

### `pubspec.yaml`

Add under `flutter.assets`:

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

---

## Error Handling

| Situation | Behavior |
|---|---|
| Font asset missing or corrupt | `PdfGenerationException` → share sheet snackbar `"Could not create PDF"` (existing flow) |
| Character not in any bundled font | Debug log from `pdf` package; rare with Noto coverage |
| RAM during PDF generation | ~71 MB font bytes peak in isolate — acceptable |

No silent fallback to Helvetica.

---

## Testing

Add to `pdf_generator_test.dart`:

| Test | HTML input | Assert |
|---|---|---|
| Japanese | `<p>こんにちは世界</p>` | Non-empty bytes, starts with `%PDF` |
| Chinese Simplified | `<p>你好世界</p>` | Non-empty bytes, starts with `%PDF` |
| Arabic | `<p>مرحبا</p>` | Non-empty bytes, starts with `%PDF` |
| Bangla | `<p>বাংলা</p>` | Non-empty bytes, starts with `%PDF` |
| Tamil | `<p>தமிழ்</p>` | Non-empty bytes, starts with `%PDF` |
| Mixed heading | `<h2>Chapter 1: 第一章</h2>` | Non-empty bytes, starts with `%PDF` |

Keep existing tests (Vietnamese, German, pagination, etc.).

Run: `flutter test test/features/lecture_session/domain/share/pdf_generator_test.dart`

---

## Out of Scope

- Bold CJK fonts for headings (C2 — doubles app size)
- Font subsetting to reduce size
- Google Fonts API / runtime download (option D)
- Git LFS configuration (team decision)
- Changes to share sheet, API fetcher, or filename helpers
- Deleting or modifying `2026-06-12-share-cached-text-pdf-design.md` (historical record)

---

## Supersedes

Font row in `2026-06-12-share-cached-text-pdf-design.md`:

> Font | Helvetica (Latin/European); CJK/Arabic out of scope

Replaced by bundled Noto Sans with full script fallbacks for all 24 supported languages.
