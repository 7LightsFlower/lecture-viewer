import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_transcript_pane.dart';

void main() {
  test('lectureTranscriptEmptyMessage for live session includes mode label', () {
    expect(
      lectureTranscriptEmptyMessage(
        reason: LectureTranscriptEmptyReason.waitingForLiveText,
        moduleLabel: 'Shortening 70%',
      ),
      'Waiting for speech',
    );
  });

  test('lectureTranscriptEmptyMessage for snapshot', () {
    expect(
      lectureTranscriptEmptyMessage(
        reason: LectureTranscriptEmptyReason.noSnapshotText,
        moduleLabel: 'Normal',
      ),
      'No transcript was saved for Normal.',
    );
  });

  test('lectureTranscriptEmptyMessage when no module selected', () {
    expect(
      lectureTranscriptEmptyMessage(
        reason: LectureTranscriptEmptyReason.noModuleSelected,
      ),
      'Select a shortening mode above.',
    );
  });
}
