import '../data/speaker_label_state.dart';
import '../data/transcript_bucket.dart';
import '../data/transcript_paragraph.dart';
import '../data/transcript_segment.dart';
import 'transcript_text_event.dart';
import 'translation_text_compound_id.dart';

SpeakerLabelState _mergeSpeakerLabel(
  SpeakerLabelState? prev,
  TranscriptTextEvent event,
) {
  final d = event.senderDetail;
  if (prev == null) {
    return SpeakerLabelState(
      show: d.isShowSpeakerName,
      speakerName: d.speakerName,
    );
  }
  if (prev.show && !d.isShowSpeakerName) {
    return SpeakerLabelState(show: false, speakerName: prev.speakerName);
  }
  if (!prev.show && d.isShowSpeakerName) {
    return SpeakerLabelState(show: true, speakerName: d.speakerName);
  }
  return SpeakerLabelState(
    show: d.isShowSpeakerName,
    speakerName: d.speakerName,
  );
}

TranscriptBucket applyTranscriptTextEvent(
  TranscriptBucket bucket,
  TranscriptTextEvent event,
) {
  final cid = translationTextCompoundId(
    rawSender: event.rawSender,
    textId: event.textId,
  );
  final prev = bucket.speakerLabelByCompoundId[cid];
  final nextLabel = _mergeSpeakerLabel(prev, event);
  final speakerMap = Map<String, SpeakerLabelState>.from(
    bucket.speakerLabelByCompoundId,
  );
  speakerMap[cid] = nextLabel;

  if (!event.isFinal) {
    return TranscriptBucket(
      paragraphs: bucket.paragraphs,
      partialText: event.text,
      speakerLabelByCompoundId: speakerMap,
    );
  }

  var paragraphs = List<TranscriptParagraph>.from(bucket.paragraphs);
  if (paragraphs.isEmpty) {
    paragraphs.add(const TranscriptParagraph(segments: []));
  }

  if (prev == null) {
    final lastIdx = paragraphs.length - 1;
    final lastPara = paragraphs[lastIdx];
    final newSegments = List<TranscriptSegment>.from(lastPara.segments)
      ..add(TranscriptSegment(text: event.text, textCompoundId: cid));
    paragraphs[lastIdx] = TranscriptParagraph(segments: newSegments);

    if (event.isEndParagraph) {
      paragraphs.add(const TranscriptParagraph(segments: []));
    }
  } else if (event.isEndParagraph) {
    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex += 1) {
      final paragraph = paragraphs[paragraphIndex];
      final segmentIndex = paragraph.segments.indexWhere(
        (segment) => segment.textCompoundId == cid,
      );
      if (segmentIndex < 0) continue;

      if (segmentIndex < paragraph.segments.length - 1) {
        paragraphs[paragraphIndex] = TranscriptParagraph(
          segments: paragraph.segments.sublist(0, segmentIndex + 1),
        );
        paragraphs.insert(
          paragraphIndex + 1,
          TranscriptParagraph(
            segments: paragraph.segments.sublist(segmentIndex + 1),
          ),
        );
      } else if (paragraphIndex == paragraphs.length - 1) {
        paragraphs.add(const TranscriptParagraph(segments: []));
      }
      break;
    }
  }

  return TranscriptBucket(
    paragraphs: paragraphs,
    partialText: null,
    speakerLabelByCompoundId: speakerMap,
  );
}
