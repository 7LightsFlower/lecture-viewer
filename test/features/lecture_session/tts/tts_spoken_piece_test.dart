import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_spoken_piece.dart';

TranscriptSegment _seg(String sender, String textId, String text) =>
    TranscriptSegment(
      text: text,
      textCompoundId: translationTextCompoundId(
        rawSender: sender,
        textId: textId,
      ),
    );

TranscriptBucket _bucket(List<List<TranscriptSegment>> paragraphs) =>
    TranscriptBucket(
      paragraphs: [
        for (final p in paragraphs) TranscriptParagraph(segments: p),
      ],
      speakerLabelByCompoundId: const {},
    );

String _id(String sender, String textId) =>
    translationTextCompoundId(rawSender: sender, textId: textId);

void main() {
  test('tts:N reads mt:N', () {
    expect(textSenderForTts('tts:3_de'), 'mt:3_de');
    expect(textSenderForTts('mt:1'), 'mt:1');
  });

  test('fromEvent needs text or ids', () {
    expect(
      TtsSpokenPiece.fromEvent(
        const TtsPcmEvent(url: 'u', rawSender: 'tts:1'),
      ),
      isNull,
    );
    final p = TtsSpokenPiece.fromEvent(
      const TtsPcmEvent(
        url: 'u',
        rawSender: 'tts:1',
        text: 'Hallo',
        maxMessageId: 7,
      ),
    )!;
    expect(p.textSender, 'mt:1');
    expect(p.minId, 7);
    expect(p.speaksMessageId(7), isTrue);
    expect(p.speaksMessageId(8), isFalse);
  });

  test('matches the segments whose words are spoken', () {
    final bucket = _bucket([
      [
        _seg('mt:1', '0001', ' Guten Morgen zusammen.'),
        _seg('mt:1', '0002', ' Heute geht es um Physik.'),
      ],
      [_seg('mt:1', '0003', ' Wir beginnen mit Mechanik.')],
    ]);
    const piece = TtsSpokenPiece(
      key: 'k',
      textSender: 'mt:1',
      text: 'Heute geht es um Physik.',
      minId: 2,
      maxId: 2,
    );
    expect(spokenSegmentIds(bucket, piece), {_id('mt:1', '0002')});
  });

  test('ids pick the right place when words repeat', () {
    final bucket = _bucket([
      [_seg('mt:1', '0001', ' Vielen Dank.')],
      [_seg('mt:1', '0002', ' Etwas anderes ganz Neues.')],
      [_seg('mt:1', '0003', ' Vielen Dank.')],
    ]);
    const piece = TtsSpokenPiece(
      key: 'k',
      textSender: 'mt:1',
      text: 'Vielen Dank.',
      minId: 1,
      maxId: 1,
    );
    expect(spokenSegmentIds(bucket, piece), {_id('mt:1', '0001')});
  });

  test('a piece spanning several segments highlights all of them', () {
    final bucket = _bucket([
      [
        _seg('mt:1', '0004_0', ' Erster Satz.'),
        _seg('mt:1', '0004_1', 'Zweiter Satz.'),
        _seg('mt:1', '0005', ' Anderes Thema.'),
      ],
    ]);
    const piece = TtsSpokenPiece(
      key: 'k',
      textSender: 'mt:1',
      text: 'Erster Satz. Zweiter Satz.',
      minId: 4,
      maxId: 4,
    );
    expect(
      spokenSegmentIds(bucket, piece),
      {_id('mt:1', '0004_0'), _id('mt:1', '0004_1')},
    );
  });

  test('works on another module of the language by text alone', () {
    final bucket = _bucket([
      [
        _seg('postproduction:50_de', '0001', ' Etwas davor.'),
        _seg('postproduction:50_de', '0002', ' Heute geht es um Physik.'),
      ],
    ]);
    const piece = TtsSpokenPiece(
      key: 'k',
      textSender: 'mt:1',
      text: 'Heute geht es um Physik.',
      minId: 2,
      maxId: 2,
    );
    expect(
      spokenSegmentIds(bucket, piece),
      {_id('postproduction:50_de', '0002')},
    );
  });

  test('no text: falls back to the ids', () {
    final bucket = _bucket([
      [_seg('mt:1', '0001', ' A.'), _seg('mt:1', '0002', ' B.')],
    ]);
    const piece = TtsSpokenPiece(
      key: 'k',
      textSender: 'mt:1',
      text: '',
      minId: 2,
      maxId: 2,
    );
    expect(spokenSegmentIds(bucket, piece), {_id('mt:1', '0002')});
  });
}
