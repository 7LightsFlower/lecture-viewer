import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

TranscriptTextEvent ev({
  required String text,
  required bool isFinal,
  required bool isEndParagraph,
  String rawSender = 'mt:1',
  String textId = 't1',
  String speaker = 'English',
  String speakerName = 'A',
  bool showSpeaker = false,
}) {
  return TranscriptTextEvent(
    text: text,
    isFinal: isFinal,
    textId: textId,
    sender: speaker,
    rawSender: rawSender,
    isEndParagraph: isEndParagraph,
    senderDetail: TranscriptSenderDetail(
      speakerName: speakerName,
      isShowSpeakerName: showSpeaker,
    ),
  );
}

void main() {
  test('partial replaces previous partial', () {
    var b = TranscriptBucket.initial();
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'hel', isFinal: false, isEndParagraph: false),
    );
    expect(b.partialText, 'hel');
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'hello', isFinal: false, isEndParagraph: false),
    );
    expect(b.partialText, 'hello');
  });

  test('final clears partial and appends segment', () {
    var b = TranscriptBucket.initial();
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'hello', isFinal: true, isEndParagraph: false),
    );
    expect(b.partialText, isNull);
    expect(b.paragraphs, hasLength(1));
    expect(b.paragraphs.single.segments.single.text, 'hello');
  });

  test('isEndParagraph closes paragraph and starts new', () {
    var b = TranscriptBucket.initial();
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'a', isFinal: true, isEndParagraph: true, textId: 't1'),
    );
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'b', isFinal: true, isEndParagraph: false, textId: 't2'),
    );
    expect(b.paragraphs, hasLength(2));
    expect(b.paragraphs[0].segments.single.text, 'a');
    expect(b.paragraphs[1].segments.single.text, 'b');
  });

  test('repeat final for same compound id updates speaker only', () {
    var b = TranscriptBucket.initial();
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'first', isFinal: true, isEndParagraph: false, textId: 't1'),
    );
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'revised', isFinal: true, isEndParagraph: false, textId: 't1'),
    );
    expect(b.paragraphs, hasLength(1));
    expect(b.paragraphs.single.segments, hasLength(1));
    expect(b.paragraphs.single.segments.single.text, 'first');
  });

  test('paragraph-end update splits after an existing final segment', () {
    var b = TranscriptBucket.initial();
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'Before', isFinal: true, isEndParagraph: false, textId: 't0'),
    );
    for (final id in ['t1', 't2', 't3']) {
      b = applyTranscriptTextEvent(
        b,
        ev(text: '♪', isFinal: true, isEndParagraph: false, textId: id),
      );
    }

    b = applyTranscriptTextEvent(
      b,
      ev(text: 'Before', isFinal: true, isEndParagraph: true, textId: 't0'),
    );
    b = applyTranscriptTextEvent(
      b,
      ev(text: '♪', isFinal: true, isEndParagraph: true, textId: 't3'),
    );
    b = applyTranscriptTextEvent(
      b,
      ev(text: 'After', isFinal: true, isEndParagraph: false, textId: 't4'),
    );

    expect(b.paragraphs, hasLength(3));
    expect(b.paragraphs[0].segments.single.text, 'Before');
    expect(b.paragraphs[1].segments.map((s) => s.text), ['♪', '♪', '♪']);
    expect(b.paragraphs[2].segments.single.text, 'After');
  });

  test('speaker toggle false clears show after true', () {
    var b = TranscriptBucket.initial();
    const id = 't1';
    b = applyTranscriptTextEvent(
      b,
      ev(
        text: 'x',
        isFinal: true,
        isEndParagraph: true,
        textId: id,
        showSpeaker: true,
        speakerName: 'Ann',
      ),
    );
    final cid = translationTextCompoundId(rawSender: 'mt:1', textId: id);
    expect(b.speakerLabelByCompoundId[cid]?.show, isTrue);
    b = applyTranscriptTextEvent(
      b,
      ev(
        text: 'x2',
        isFinal: true,
        isEndParagraph: true,
        textId: id,
        showSpeaker: false,
        speakerName: 'Ann',
      ),
    );
    expect(b.speakerLabelByCompoundId[cid]?.show, isFalse);
  });
}
