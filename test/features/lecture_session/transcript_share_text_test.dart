import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/transcript_share_text.dart';

void main() {
  test('empty bucket formats to empty string', () {
    expect(formatTranscriptBucketForShare(TranscriptBucket.initial()), '');
    expect(bucketHasShareableContent(TranscriptBucket.initial()), isFalse);
  });

  test('partial only is shareable', () {
    final bucket = TranscriptBucket(
      paragraphs: const [],
      partialText: 'listening',
      speakerLabelByCompoundId: const {},
    );
    expect(bucketHasShareableContent(bucket), isTrue);
    expect(formatTranscriptBucketForShare(bucket), 'listening');
  });

  test('speaker label on own line before text', () {
    const cid = 'mt:1|t1';
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Hello', textCompoundId: cid),
          ],
        ),
      ],
      speakerLabelByCompoundId: {
        cid: SpeakerLabelState(show: true, speakerName: 'Alice'),
      },
    );
    expect(formatTranscriptBucketForShare(bucket), 'Alice\nHello');
  });

  test('two paragraphs separated by blank line', () {
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'One', textCompoundId: 'a'),
          ],
        ),
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Two', textCompoundId: 'b'),
          ],
        ),
      ],
      speakerLabelByCompoundId: const {},
    );
    expect(formatTranscriptBucketForShare(bucket), 'One\n\nTwo');
  });

  test('segments in same paragraph get space when needed', () {
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Hello', textCompoundId: 'a'),
            TranscriptSegment(text: 'world', textCompoundId: 'b'),
          ],
        ),
      ],
      speakerLabelByCompoundId: const {},
    );
    expect(formatTranscriptBucketForShare(bucket), 'Hello world');
  });

  test('partial appends with gap after finalized text', () {
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Done.', textCompoundId: 'a'),
          ],
        ),
      ],
      partialText: 'more',
      speakerLabelByCompoundId: const {},
    );
    expect(formatTranscriptBucketForShare(bucket), 'Done.\n more');
  });
}
