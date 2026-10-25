import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        width: 400,
        child: child,
      ),
    ),
  );
}

TextSpan? _findTextSpan(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text) return span;
    for (final child in span.children ?? const <InlineSpan>[]) {
      final found = _findTextSpan(child, text);
      if (found != null) return found;
    }
  }
  return null;
}

TranscriptBucket _bucketWithParagraphAndPartial({
  required String finalized,
  required String partial,
}) {
  return TranscriptBucket(
    paragraphs: [
      TranscriptParagraph(
        segments: [
          TranscriptSegment(text: finalized, textCompoundId: 'mt:1|t1'),
        ],
      ),
    ],
    partialText: partial,
    speakerLabelByCompoundId: const {},
  );
}

void main() {
  testWidgets('partial is inlined on last paragraph', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptView(
          textScaler: TextScaler.noScaling,
          activeBucket: _bucketWithParagraphAndPartial(
            finalized: 'Hello',
            partial: 'world',
          ),
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(RichText), findsOneWidget);
    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(rich.text.toPlainText(), 'Hello world');
  });

  testWidgets('partial only bucket renders single list item', (
    WidgetTester tester,
  ) async {
    const bucket = TranscriptBucket(
      paragraphs: <TranscriptParagraph>[],
      partialText: 'listening',
      speakerLabelByCompoundId: <String, SpeakerLabelState>{},
    );

    await tester.pumpWidget(
      _wrap(
        const TranslationResultTranscriptView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(RichText), findsOneWidget);
    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(rich.text.toPlainText(), 'listening');
  });

  testWidgets('partial appears only on last list item', (
    WidgetTester tester,
  ) async {
    final bucket = TranscriptBucket(
      paragraphs: [
        const TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'First.', textCompoundId: 'mt:1|t1'),
          ],
        ),
        const TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Second', textCompoundId: 'mt:1|t2'),
          ],
        ),
      ],
      partialText: 'tail',
      speakerLabelByCompoundId: const {},
    );

    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(richTexts.length, 2);
    expect(richTexts.first.text.toPlainText(), 'First.');
    expect(richTexts.last.text.toPlainText(), 'Second tail');
  });

  testWidgets('partial text uses light gray color', (WidgetTester tester) async {
    const bucket = TranscriptBucket(
      paragraphs: <TranscriptParagraph>[],
      partialText: 'listening',
      speakerLabelByCompoundId: <String, SpeakerLabelState>{},
    );

    await tester.pumpWidget(
      _wrap(
        const TranslationResultTranscriptView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final partialSpan = _findTextSpan(rich.text, 'listening');
    expect(partialSpan, isNotNull);
    expect(partialSpan!.style?.color, Colors.grey.shade500);
  });

  testWidgets('viewer speaker display adds blank line between speakers', (
    WidgetTester tester,
  ) async {
    const bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Hello', textCompoundId: 'a'),
            TranscriptSegment(text: 'World', textCompoundId: 'b'),
          ],
        ),
      ],
      speakerLabelByCompoundId: {
        'a': SpeakerLabelState(show: true, speakerName: 'Speaker #1'),
        'b': SpeakerLabelState(show: true, speakerName: 'Speaker #2'),
      },
    );

    await tester.pumpWidget(
      _wrap(
        const TranslationResultTranscriptView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
          viewerSpeakerLayout: true,
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(
      rich.text.toPlainText(),
      'Speaker 1:\nHello\n\nSpeaker 2:\nWorld',
    );
  });

  testWidgets('viewer speaker label is two typography steps above body', (
    WidgetTester tester,
  ) async {
    const bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Hello', textCompoundId: 'a'),
          ],
        ),
      ],
      speakerLabelByCompoundId: {
        'a': SpeakerLabelState(show: true, speakerName: 'Speaker 1'),
      },
    );

    late double bodyFontSize;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            bodyFontSize =
                Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
            return Scaffold(
              body: SizedBox(
                height: 400,
                width: 400,
                child: const TranslationResultTranscriptView(
                  textScaler: TextScaler.noScaling,
                  activeBucket: bucket,
                  viewerSpeakerLayout: true,
                ),
              ),
            );
          },
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final speakerSpan = _findTextSpan(rich.text, 'Speaker 1:');
    final bodySpan = _findTextSpan(rich.text, 'Hello');
    expect(speakerSpan, isNotNull);
    expect(bodySpan, isNotNull);
    expect(speakerSpan!.style?.fontSize, bodyFontSize + 4);
    expect(bodySpan!.style?.fontSize, bodyFontSize);
  });
}
