import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('SessionTranscriptState round-trips through JSON', () {
    final original = SessionTranscriptState(
      buckets: {
        'English': TranscriptBucket(
          paragraphs: [
            TranscriptParagraph(
              segments: [
                TranscriptSegment(text: 'Hi', textCompoundId: 'c1'),
              ],
            ),
          ],
          speakerLabelByCompoundId: const {},
        ),
      },
    );
    final decoded = SessionTranscriptState.fromJson(original.toJson());
    expect(
      decoded.buckets['English']!.paragraphs.single.segments.single.text,
      'Hi',
    );
  });
}
