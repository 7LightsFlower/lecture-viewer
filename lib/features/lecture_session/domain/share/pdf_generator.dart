import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _kSharePdfFallbackAssets = [
  'assets/fonts/NotoSansSymbols-Regular.ttf',
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

typedef _PdfRenderRequest = ({
  String html,
  Uint8List regular,
  Uint8List bold,
  List<Uint8List> fallbacks,
});

typedef _SharePdfFontBytes = ({
  Uint8List regular,
  Uint8List bold,
  List<Uint8List> fallbacks,
});

Future<Uint8List> htmlToPdfBytes(String htmlContent) async {
  try {
    final fonts = await _loadSharePdfFontBytes();
    return await compute(
      _renderPdfInIsolate,
      (
        html: htmlContent,
        regular: fonts.regular,
        bold: fonts.bold,
        fallbacks: fonts.fallbacks,
      ),
    );
  } catch (e) {
    throw PdfGenerationException(e);
  }
}

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
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(56.7),
      build: (_) =>
          widgets.isEmpty ? [pw.Text('', style: ctx.body())] : widgets,
    ),
  );
  return doc.save();
}

class PdfGenerationException implements Exception {
  PdfGenerationException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'PdfGenerationException: $cause';
}

class _SharePdfFonts {
  const _SharePdfFonts({
    required this.regular,
    required this.bold,
  });

  final pw.Font regular;
  final pw.Font bold;
}

Future<_SharePdfFontBytes>? _fontBytesFuture;

Future<_SharePdfFontBytes> _loadSharePdfFontBytes() async {
  if (_fontBytesFuture != null) return _fontBytesFuture!;
  final future = _fetchSharePdfFontBytes();
  _fontBytesFuture = future;
  try {
    return await future;
  } catch (_) {
    _fontBytesFuture = null;
    rethrow;
  }
}

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

class _PdfRenderContext {
  const _PdfRenderContext(this.fonts);

  final _SharePdfFonts fonts;

  pw.TextStyle body({double fontSize = 12}) =>
      pw.TextStyle(fontSize: fontSize);

  pw.TextStyle bold({double fontSize = 12}) => pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
      );
}

List<pw.Widget> _nodeToWidgets(dom.NodeList nodes, _PdfRenderContext ctx) {
  final result = <pw.Widget>[];
  for (final node in nodes) {
    result.addAll(_nodeToWidget(node, ctx));
  }
  return result;
}

List<pw.Widget> _nodeToWidget(dom.Node node, _PdfRenderContext ctx) {
  if (node is dom.Text) {
    final text = _collapseWhitespace(node.text);
    if (text.isEmpty) return const [];
    return [
      pw.Text(text, style: ctx.body(), overflow: pw.TextOverflow.span),
      pw.SizedBox(height: 6),
    ];
  }

  if (node is dom.Element) {
    switch (node.localName) {
      case 'h2':
        return [
          pw.SizedBox(height: 12),
          pw.Text(
            node.text.trim(),
            style: ctx.bold(fontSize: 18),
            overflow: pw.TextOverflow.span,
          ),
          pw.SizedBox(height: 6),
        ];
      case 'h3':
        return [
          pw.SizedBox(height: 10),
          pw.Text(
            node.text.trim(),
            style: ctx.bold(fontSize: 14),
            overflow: pw.TextOverflow.span,
          ),
          pw.SizedBox(height: 4),
        ];
      case 'ul':
      case 'ol':
        final items = <pw.Widget>[];
        for (final li in node.children.where((e) => e.localName == 'li')) {
          items.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, bottom: 4),
              child: pw.RichText(
                overflow: pw.TextOverflow.span,
                text: pw.TextSpan(
                  text: '\u2022  ',
                  style: ctx.body(),
                  children: _inlineSpans(li.nodes, ctx),
                ),
              ),
            ),
          );
        }
        return items;
      case 'p':
        return _richTextFromInlineNodes(node.nodes, ctx, spacing: 8);
      case 'b':
      case 'strong':
      case 'i':
      case 'u':
        return _richTextFromInlineNodes(
          node.nodes,
          ctx,
          style: _applyInlineTag(node.localName, ctx.body()),
        );
      case 'br':
        return [pw.SizedBox(height: 4)];
      default:
        return _nodeToWidgets(node.nodes, ctx);
    }
  }
  return const [];
}

bool _isInlineTag(String? tag) =>
    tag == 'b' || tag == 'strong' || tag == 'i' || tag == 'u';

pw.TextStyle _applyInlineTag(String? tag, pw.TextStyle base) {
  return switch (tag) {
    'b' || 'strong' => base.copyWith(fontWeight: pw.FontWeight.bold),
    'i' => base.copyWith(fontStyle: pw.FontStyle.italic),
    'u' => base.copyWith(decoration: pw.TextDecoration.underline),
    _ => base,
  };
}

List<pw.Widget> _richTextFromInlineNodes(
  dom.NodeList nodes,
  _PdfRenderContext ctx, {
  pw.TextStyle? style,
  double spacing = 6,
}) {
  final spans = _inlineSpans(nodes, ctx, style: style);
  if (spans.isEmpty) return const [];
  return [
    pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(children: spans, style: ctx.body()),
    ),
    pw.SizedBox(height: spacing),
  ];
}

List<pw.TextSpan> _inlineSpans(
  dom.NodeList nodes,
  _PdfRenderContext ctx, {
  pw.TextStyle? style,
}) {
  final baseStyle = style ?? ctx.body();
  final spans = <pw.TextSpan>[];
  for (final node in nodes) {
    if (node is dom.Text) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.trim().isNotEmpty) {
        spans.add(pw.TextSpan(text: text, style: baseStyle));
      }
    } else if (node is dom.Element) {
      final tag = node.localName;
      if (_isInlineTag(tag)) {
        spans.addAll(
          _inlineSpans(
            node.nodes,
            ctx,
            style: _applyInlineTag(tag, baseStyle),
          ),
        );
      } else {
        spans.addAll(_inlineSpans(node.nodes, ctx, style: baseStyle));
      }
    }
  }
  return spans;
}

/// Collapses runs of whitespace (incl. newlines) to a single space, matching
/// how HTML renders text. Source HTML breaks lines mid-sentence; without this
/// the PDF would show choppy one-phrase-per-line text instead of wrapping.
String _collapseWhitespace(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Clears cached fonts — for tests only.
void clearSharePdfFontsCacheForTest() {
  _fontBytesFuture = null;
}
