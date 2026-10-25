import '../transcript/domain/transcript_sender_detail.dart';
import '../transcript/domain/transcript_text_event.dart';

/// Permissive parse of `objectType: texts` payload. No module or empty-text filter.
List<TranscriptTextEvent>? parseInboundTextsPayload(
  Map<String, dynamic> decoded,
) {
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) return null;
  final texts = data['texts'];
  if (texts is! List || texts.isEmpty) return null;

  final out = <TranscriptTextEvent>[];
  for (final item in texts) {
    if (item is! Map<String, dynamic>) continue;
    final text = item['text'];
    final sender = item['sender'];
    final rawSender = item['rawSender'];
    if (text is! String || sender is! String || rawSender is! String) {
      continue;
    }
    final sd = item['senderDetail'];
    var speakerName = '';
    var showSpeaker = false;
    if (sd is Map<String, dynamic>) {
      final n = sd['speakerName'];
      if (n is String) speakerName = n;
      showSpeaker = sd['isShowSpeakerName'] == true;
    }
    out.add(
      TranscriptTextEvent(
        text: text,
        isFinal: item['isFinal'] == true,
        textId: '${item['textId']}',
        sender: sender,
        rawSender: rawSender,
        isEndParagraph: item['isEndParagraph'] == true,
        senderDetail: TranscriptSenderDetail(
          speakerName: speakerName,
          isShowSpeakerName: showSpeaker,
        ),
      ),
    );
  }
  if (out.isEmpty) return null;
  return out;
}
