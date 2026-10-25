import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/pdf_generator.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearSharePdfFontsCacheForTest);

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

  test('handles Vietnamese diacritics', () async {
    final bytes = await htmlToPdfBytes('<p>Tiếng Việt có dấu</p>');
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('symbol fallback font covers musical note characters', () async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansSymbols-Regular.ttf',
    );
    final font = TtfParser(fontData);

    expect(font.charToGlyphIndexMap, contains(0x266A));
  });

  test('uses the symbol fallback font for musical note characters', () async {
    final bytes = await htmlToPdfBytes('<p>♪ Music ♪</p>');
    final pdf = latin1.decode(bytes, allowInvalid: true);

    expect(pdf, contains('NotoSansSymbols'));
    expect(pdf, isNot(contains('NotoSansJP')));
  });

  test('paginates long content wrapped in a container without overflowing',
      () async {
    final paragraphs = List.generate(
      80,
      (i) => '<p>Paragraph $i with enough text to fill the page.</p>',
    ).join();
    final html = '<div>$paragraphs</div>';

    final bytes = await htmlToPdfBytes(html);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles bare text with newlines between phrases', () async {
    const html = '''
      <h3>Full content:</h3>
      <br><u>Unknown:</u>
      Schönen guten Abend.
      Hallo.
      Ich darf gleich meine Mitdisputantinnen und Disputanten auf die Bühne
      bitten.
    ''';

    final bytes = await htmlToPdfBytes(html);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('spans a single paragraph taller than one page across pages', () async {
    final longParagraph = List.generate(
      400,
      (i) => 'sentence number $i in a very long transcript paragraph.',
    ).join(' ');
    final html = '<p>$longParagraph</p>';

    final bytes = await htmlToPdfBytes(html);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

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
}
