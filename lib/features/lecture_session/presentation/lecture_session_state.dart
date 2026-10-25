import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';

class LectureSessionState {
  const LectureSessionState({
    required this.sessionId,
    this.wsPhase = LectureWsPhase.connecting,
    this.activeLanguages = const [],
    this.computedSenders = const {},
    this.selectedLanguage = '',
    this.selectedRawSender = '',
    this.transcript = const SessionTranscriptState.empty(),
    this.tts = const TtsPaneSnapshot(),
    this.errorMessage,
    this.hasReceivedInfo = false,
    this.sessionExitRequested = false,
    this.serverErrorRetryRequested = false,
    this.ttsCollapsedSliderVisible = false,
    this.inboundSessionId,
  });

  final String sessionId;
  final LectureWsPhase wsPhase;
  final List<String> activeLanguages;
  final Map<String, ComputedSenderInfo> computedSenders;
  final String selectedLanguage;
  final String selectedRawSender;
  final SessionTranscriptState transcript;
  final TtsPaneSnapshot tts;
  final String? errorMessage;
  final bool hasReceivedInfo;
  final bool sessionExitRequested;
  final bool serverErrorRetryRequested;
  final bool ttsCollapsedSliderVisible;

  /// `sessionID` from websocket `info` message — used for share / cached-text API.
  final String? inboundSessionId;

  String get apiSessionId => inboundSessionId ?? sessionId;

  LectureSessionState copyWith({
    LectureWsPhase? wsPhase,
    List<String>? activeLanguages,
    Map<String, ComputedSenderInfo>? computedSenders,
    String? selectedLanguage,
    String? selectedRawSender,
    SessionTranscriptState? transcript,
    TtsPaneSnapshot? tts,
    String? errorMessage,
    bool? hasReceivedInfo,
    bool? sessionExitRequested,
    bool? serverErrorRetryRequested,
    bool? ttsCollapsedSliderVisible,
    String? inboundSessionId,
    bool clearError = false,
  }) {
    return LectureSessionState(
      sessionId: sessionId,
      wsPhase: wsPhase ?? this.wsPhase,
      activeLanguages: activeLanguages ?? this.activeLanguages,
      computedSenders: computedSenders ?? this.computedSenders,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedRawSender: selectedRawSender ?? this.selectedRawSender,
      transcript: transcript ?? this.transcript,
      tts: tts ?? this.tts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasReceivedInfo: hasReceivedInfo ?? this.hasReceivedInfo,
      sessionExitRequested:
          sessionExitRequested ?? this.sessionExitRequested,
      serverErrorRetryRequested:
          serverErrorRetryRequested ?? this.serverErrorRetryRequested,
      ttsCollapsedSliderVisible:
          ttsCollapsedSliderVisible ?? this.ttsCollapsedSliderVisible,
      inboundSessionId: inboundSessionId ?? this.inboundSessionId,
    );
  }
}
