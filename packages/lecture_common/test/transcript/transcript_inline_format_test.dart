import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

String _plainText(List<InlineSpan> spans) {
  return TextSpan(children: spans).toPlainText();
}

TranscriptBucket _bucketWithSpeakers({
  required List<({String cid, String text, bool show, String name})> rows,
}) {
  final segments = <TranscriptSegment>[];
  final labels = <String, SpeakerLabelState>{};

  for (final row in rows) {
    segments.add(TranscriptSegment(text: row.text, textCompoundId: row.cid));
    labels[row.cid] = SpeakerLabelState(show: row.show, speakerName: row.name);
  }

  return TranscriptBucket(
    paragraphs: [TranscriptParagraph(segments: segments)],
    speakerLabelByCompoundId: labels,
  );
}

void main() {
  const bodyStyle = TextStyle(fontSize: 16);
  const labelStyle = TextStyle(fontSize: 14);

  test('defaults: single newline before mid-paragraph speaker', () {
    final bucket = _bucketWithSpeakers(
      rows: [
        (cid: 'a', text: 'Hello', show: true, name: 'Speaker 1'),
        (cid: 'b', text: 'World', show: true, name: 'Speaker 2'),
      ],
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 0,
      ),
    );

    expect(text, 'Speaker 1\nHello\nSpeaker 2\nWorld');
  });

  test('viewer: blank line before mid-paragraph speaker and strips hash', () {
    final bucket = _bucketWithSpeakers(
      rows: [
        (cid: 'a', text: 'Hello', show: true, name: 'Speaker #1'),
        (cid: 'b', text: 'World', show: true, name: 'Speaker #2'),
      ],
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 0,
        viewerSpeakerLayout: true,
      ),
    );

    expect(text, 'Speaker 1:\nHello\n\nSpeaker 2:\nWorld');
  });

  test('viewer: leading blank when paragraph starts with speaker and index > 0', () {
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Only', textCompoundId: 'a'),
          ],
        ),
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Next', textCompoundId: 'b'),
          ],
        ),
      ],
      speakerLabelByCompoundId: {
        'b': const SpeakerLabelState(show: true, speakerName: 'Speaker #2'),
      },
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs[1],
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 1,
        viewerSpeakerLayout: true,
      ),
    );

    expect(text, '\nSpeaker 2:\nNext');
  });

  test('viewer: no leading blank on first paragraph index 0', () {
    final bucket = _bucketWithSpeakers(
      rows: [
        (cid: 'a', text: 'Hi', show: true, name: 'Speaker #1'),
      ],
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 0,
        viewerSpeakerLayout: true,
      ),
    );

    expect(text, 'Speaker 1:\nHi');
  });

  test('does not insert space before punctuation segments', () {
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(
              text: 'shopping on your laptop',
              textCompoundId: 'a',
            ),
            TranscriptSegment(text: ', which is', textCompoundId: 'b'),
            TranscriptSegment(text: ' , you know', textCompoundId: 'c'),
          ],
        ),
      ],
      speakerLabelByCompoundId: const {},
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
      ),
    );

    expect(text, 'shopping on your laptop, which is, you know');
  });
}
