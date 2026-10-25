import '../transcript/domain/transcript_text_event.dart';

/// Module types excluded from viewer transcript display/storage.
const viewerTranscriptUnsupportedModuleTypes = {
  'tts',
  'textstructurer',
  'summarizer',
};

String moduleTypeFromRawSender(String rawSender) => rawSender.split(':').first;

bool isViewerTranscriptModuleType(String type) =>
    !viewerTranscriptUnsupportedModuleTypes.contains(type);

typedef SessionInboundTextFilter = List<TranscriptTextEvent> Function(
  List<TranscriptTextEvent> events,
);

class SessionInboundParseOptions {
  const SessionInboundParseOptions({
    this.filterTexts,
    this.shouldStoreSenderType,
  });

  final SessionInboundTextFilter? filterTexts;
  final bool Function(String type)? shouldStoreSenderType;

  /// Viewer: filter transcript modules; keep `tts` in computedSenders for routing.
  static final viewer = SessionInboundParseOptions(
    filterTexts: _filterViewerTexts,
    shouldStoreSenderType: _viewerShouldStoreSenderType,
  );

  /// 2-way: permissive texts; store all sender types in info metadata.
  static const twoWay = SessionInboundParseOptions(
    shouldStoreSenderType: _twoWayShouldStoreSenderType,
  );
}

bool _viewerShouldStoreSenderType(String type) =>
    type == 'tts' || isViewerTranscriptModuleType(type);

bool _twoWayShouldStoreSenderType(String type) => type.isNotEmpty;

List<TranscriptTextEvent> _filterViewerTexts(List<TranscriptTextEvent> events) =>
    events
        .where(
          (e) =>
              isViewerTranscriptModuleType(
                moduleTypeFromRawSender(e.rawSender),
              ) &&
              (e.isEndParagraph || e.text.trim().isNotEmpty),
        )
        .toList();
