import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/core/bootstrap/init_lecture_tts_audio_service.dart';
import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/providers/api_environment_notifier.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/media/lecture_tts_audio_handler.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/inbound/lecture_inbound_parser.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_controller.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_gate.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_language_change.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_media_seek.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/lecture_session_transport.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/public_lt/public_lt_session_client.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_session_websocket_client.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_record.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/lecture_session_debug.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';

/// Direct (KIT public) mode: replay earlier output when first joining a
/// session, so late joiners see the whole lecture. Retries skip it.
const kPublicLtLoadHistoryOnJoin = true;

final lectureSessionProvider = NotifierProvider.autoDispose
    .family<LectureSessionNotifier, LectureSessionState, LectureSessionScope>(
  LectureSessionNotifier.new,
);

class LectureSessionNotifier extends AutoDisposeFamilyNotifier<LectureSessionState,
    LectureSessionScope> implements LectureTtsRemoteDelegate {
  LectureSessionTransport? _client;
  StreamSubscription<LectureWsPhase>? _phaseSub;
  LectureTtsController? _tts;
  bool _ttsMediaAttached = false;
  Timer? _snapshotDebounce;

  bool get ttsUserWantsPlayback => _tts?.userWantsPlayback ?? false;

  @override
  LectureSessionState build(LectureSessionScope scope) {
    ref.onDispose(_dispose);
    Future.microtask(() => _connect(scope.sessionId));
    return LectureSessionState(sessionId: scope.sessionId);
  }

  void setLanguage(String language) {
    if (language == state.selectedLanguage) return;
    unawaited(_applyLanguageChange(language));
  }

  Future<void> _applyLanguageChange(String language) async {
    final hadPlaybackIntent = _tts?.userWantsPlayback ?? false;
    await _clearTtsForLanguageChange(language);
    final rawSender = defaultRawSenderForLanguage(
      selectedLanguage: language,
      computedSenders: state.computedSenders,
    );
    final availability = ttsVoiceAvailability(
      selectedLanguage: language,
      computedSenders: state.computedSenders,
    );
    final clearSlider = shouldClearTtsCollapsedSliderOnLanguageChange(
      availability,
    );
    state = state.copyWith(
      selectedLanguage: language,
      selectedRawSender: rawSender ?? '',
      ttsCollapsedSliderVisible: clearSlider
          ? false
          : hadPlaybackIntent || state.ttsCollapsedSliderVisible,
    );
    lectureSessionDebugLanguage(
      sessionId: state.sessionId,
      language: language,
      rawSender: state.selectedRawSender,
    );
    _scheduleSnapshotPersist();
  }

  void setModule(String rawSender) {
    state = state.copyWith(selectedRawSender: rawSender);
    lectureSessionDebugLanguage(
      sessionId: state.sessionId,
      language: state.selectedLanguage,
      rawSender: rawSender,
    );
    _scheduleSnapshotPersist();
  }

  void _syncModuleSelection() {
    final options = moduleOptionsForLanguage(
      selectedLanguage: state.selectedLanguage,
      computedSenders: state.computedSenders,
    );
    if (options.isEmpty) {
      if (state.selectedRawSender.isNotEmpty) {
        state = state.copyWith(selectedRawSender: '');
      }
      return;
    }
    final stillValid =
        options.any((o) => o.rawSender == state.selectedRawSender);
    if (!stillValid) {
      state = state.copyWith(selectedRawSender: options.first.rawSender);
    }
  }

  Future<void> _handleWsSessionEnd() async {
    await _disposeClient();
    state = state.copyWith(sessionExitRequested: true);
  }

  Future<void> _handleServerError() async {
    await _disposeClient();
    state = state.copyWith(serverErrorRetryRequested: true);
  }

  Future<void> retryConnect() async {
    lectureSessionDebugRetry(state.sessionId);
    await _disposeClient();
    await _connect(state.sessionId, noHistory: true);
  }

  Future<void> _connect(
    String sessionId, {
    bool noHistory = kLectureWsNoHistoryOnInitialConnect,
  }) async {
    final env = ref.read(apiEnvironmentProvider);
    if (env == ApiEnvironment.kitPublicDirect) {
      final shortenOrigin = httpsOriginForLectureHttp(
        environment: env,
        linkRecord: arg.linkRecord,
      );
      final loadHistory = kPublicLtLoadHistoryOnJoin
          ? state.transcript.buckets.isEmpty
          : !noHistory;
      lectureSessionDebugConnect(
        sessionId: sessionId,
        wsUrl: '$shortenOrigin/webapi (direct, history=$loadHistory)',
      );
      _client = PublicLtSessionClient(
        meetingName: sessionId,
        shortenOrigin: shortenOrigin,
        loadHistory: loadHistory,
        onText: _onRawMessage,
      );
    } else {
      _client = _backendClient(env, sessionId, noHistory: noHistory);
    }
    _phaseSub = _client!.phase.listen((phase) {
      lectureSessionDebugPhase(sessionId: sessionId, phase: phase);
      state = state.copyWith(wsPhase: phase, clearError: true);
    });
    await _client!.start();
  }

  LectureSessionTransport _backendClient(
    ApiEnvironment env,
    String sessionId, {
    required bool noHistory,
  }) {
    final origin = httpsOriginForLectureWs(
      environment: env,
      linkRecord: arg.linkRecord,
    );
    final wsUrl = lectureSessionWsUri(
      httpsOrigin: origin,
      sessionId: sessionId,
      noHistory: noHistory,
    ).toString();

    lectureSessionDebugConnect(sessionId: sessionId, wsUrl: wsUrl);
    return LectureSessionWebSocketClient(
      wsUrl: wsUrl,
      onText: _onRawMessage,
    );
  }

  void _onRawMessage(String raw) {
    final message = parseLectureInbound(raw);
    switch (message) {
      case LectureInboundInfo(
        :final activeLanguages,
        :final computedSenders,
        :final sessionId,
      ):
        if (activeLanguages.isEmpty && computedSenders.isEmpty) {
          lectureSessionDebugIgnored(
            raw: 'info with no language metadata (ignored)',
          );
          break;
        }
        final inboundSessionId = sessionId != null && sessionId.isNotEmpty
            ? sessionId
            : null;
        final languages = activeLanguages.contains(kTranscriptLanguage)
            ? [
                kTranscriptLanguage,
                ...activeLanguages.where((l) => l != kTranscriptLanguage),
              ]
            : activeLanguages;
        final keepLanguage = state.hasReceivedInfo &&
            state.activeLanguages.contains(state.selectedLanguage);
        final language = keepLanguage
            ? state.selectedLanguage
            : defaultLanguageFromComputedSenders(
                computedSenders,
                languages,
              );
        final keepModule = keepLanguage &&
            computedSenders.containsKey(state.selectedRawSender) &&
            computedSenders[state.selectedRawSender]!.language == language;
        final rawSender = keepModule
            ? state.selectedRawSender
            : (defaultRawSenderForLanguage(
                  selectedLanguage: language,
                  computedSenders: computedSenders,
                ) ??
                '');
        state = state.copyWith(
          activeLanguages: languages,
          computedSenders: computedSenders,
          selectedLanguage: language,
          selectedRawSender: rawSender,
          hasReceivedInfo: true,
          inboundSessionId: inboundSessionId,
          clearError: true,
        );
        _syncModuleSelection();
        _scheduleSnapshotPersist();

        lectureSessionDebugInfo(
          sessionId: state.sessionId,
          activeLanguages: languages,
          computedSenders: computedSenders,
          selectedLanguage: language,
          selectedRawSender: state.selectedRawSender,
          inboundSessionId: sessionId,
        );
      case LectureInboundSessionEnd(:final audioUrl):
        lectureSessionDebugSessionEnd(
          sessionId: state.sessionId,
          audioUrl: audioUrl,
          raw: raw,
        );
      case LectureInboundWsSessionEnd(:final reason):
        lectureSessionDebugSessionEnd(
          sessionId: state.sessionId,
          audioUrl: reason,
          raw: raw,
        );
        if (state.sessionExitRequested) break;
        unawaited(_handleWsSessionEnd());
      case LectureInboundTexts(:final events):
        _applyTexts(events);
      case LectureInboundTtsPcm(:final event):
        if (kDebugMode) {
          // debugPrint(
          //   '$kLectureSessionDebugTag tts-pcm parsed '
          //   'rawSender=${event.rawSender} '
          //   'payloadLang=${event.languageFromPayload ?? '—'}',
          // );
        }
        _handleTtsPcm(event);
      case LectureInboundServerError():
        if (state.serverErrorRetryRequested) break;
        unawaited(_handleServerError());
      case LectureInboundIgnored():
        lectureSessionDebugIgnored(raw: raw);
    }
  }

  LectureTtsController _ensureTts() {
    _attachTtsMediaIfNeeded();
    return _tts ??= LectureTtsController(
      onSnapshot: (snap) {
        lectureSessionDebugTtsSnapshot(snap);
        state = state.copyWith(tts: snap);
        _syncTtsMedia(snap);
      },
    );
  }

  void _attachTtsMediaIfNeeded() {
    if (_ttsMediaAttached) return;
    final handler = lectureTtsAudioHandler;
    if (handler == null) return;
    handler.attach(this);
    _ttsMediaAttached = true;
  }

  void _syncTtsMedia(TtsPaneSnapshot snap) {
    lectureTtsAudioHandler?.syncFromSnapshot(
      sessionId: state.sessionId,
      selectedLanguage: state.selectedLanguage,
      snapshot: snap,
    );
  }

  @override
  Future<void> onRemotePlay() async {
    if (!state.tts.isPlaying) {
      engageTtsCollapsedSlider();
      ttsPlayPause();
    }
  }

  @override
  Future<void> onRemotePause() async {
    if (state.tts.isPlaying) {
      ttsPlayPause();
    }
  }

  @override
  Future<void> onRemoteSeek(Duration position) async {
    ttsSeekEnd(
      ttsNormalizedSeekFromDuration(
        position: position,
        bufferedDurationSec: state.tts.bufferedDurationSec,
      ),
    );
  }

  void _handleTtsPcm(TtsPcmEvent event) {
    final selected = state.selectedLanguage;
    final lang = resolveLectureTtsLanguage(event, state.computedSenders);

    if (selected.isEmpty) {
      lectureSessionDebugTtsPcm(
        rawSender: event.rawSender,
        languageFromPayload: event.languageFromPayload,
        resolvedLanguage: lang,
        selectedLanguage: selected,
        enqueued: false,
        skipReason: 'no_selected_language',
      );
      return;
    }
    if (lang == null) {
      lectureSessionDebugTtsPcm(
        rawSender: event.rawSender,
        languageFromPayload: event.languageFromPayload,
        resolvedLanguage: null,
        selectedLanguage: selected,
        enqueued: false,
        skipReason: 'no_language',
      );
      return;
    }
    if (!shouldEnqueueTtsForLanguage(lang, selected)) {
      lectureSessionDebugTtsPcm(
        rawSender: event.rawSender,
        languageFromPayload: event.languageFromPayload,
        resolvedLanguage: lang,
        selectedLanguage: selected,
        enqueued: false,
        skipReason: 'language_mismatch',
      );
      return;
    }
    lectureSessionDebugTtsPcm(
      rawSender: event.rawSender,
      languageFromPayload: event.languageFromPayload,
      resolvedLanguage: lang,
      selectedLanguage: selected,
      enqueued: true,
    );
    lectureSessionDebugTtsEnqueue(url: event.url);
    _ensureTts().enqueue(event.url);
  }

  void engageTtsCollapsedSlider() {
    if (state.ttsCollapsedSliderVisible) return;
    state = state.copyWith(ttsCollapsedSliderVisible: true);
  }

  void ttsPlayPause() {
    final playbackRequested = state.tts.isPlaying || ttsUserWantsPlayback;
    if (playbackRequested) {
      state = state.copyWith(ttsCollapsedSliderVisible: false);
    }
    unawaited(
      _ensureTts().playPauseFromUser(isPlaying: state.tts.isPlaying),
    );
  }

  void ttsSeekEnd(double normalized) {
    _ensureTts().seekEnd(normalized);
  }

  Future<void> _clearTtsForLanguageChange(String newLanguage) async {
    final controller = _tts;
    if (controller == null) {
      await lectureTtsAudioHandler?.clearMediaSession();
      return;
    }

    final preserve = preserveTtsPlaybackOnLanguageChange(
      userWantsPlayback: controller.userWantsPlayback,
    );

    await controller.clearForLanguageChange(
      preserveUserPlaybackIntent: preserve,
    );
    await lectureTtsAudioHandler?.clearMediaSession();
  }

  void _applyTexts(List<TranscriptTextEvent> events) {
    var transcript = state.transcript;
    var forceTranscriptLog = false;
    for (final event in events) {
      final keys = bucketKeysForRawSender(
        rawSender: event.rawSender,
        computedSenders: state.computedSenders,
      );
      lectureSessionDebugText(event: event, bucketKeys: keys);
      for (final key in keys) {
        transcript = transcript.applyToBucket(
          bucketKey: key,
          apply: (b) => applyTranscriptTextEvent(b, event),
        );
      }
      if (event.isFinal || event.isEndParagraph) {
        forceTranscriptLog = true;
      }
    }

    lectureSessionDebugTranscript(
      transcript: transcript,
      force: forceTranscriptLog,
    );

    state = state.copyWith(transcript: transcript);
    _syncModuleSelection();
    _scheduleSnapshotPersist();
  }

  void _scheduleSnapshotPersist() {
    final linkRecord = arg.linkRecord;
    if (linkRecord.isEmpty) return;
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_flushSnapshotPersist());
    });
  }

  Future<void> _flushSnapshotPersist() async {
    final linkRecord = arg.linkRecord;
    if (linkRecord.isEmpty) return;
    try {
      final repo = await ref.read(lectureSnapshotRepositoryProvider.future);
      await repo.upsert(
        LectureSnapshotRecord(
          linkRecord: linkRecord,
          sessionId: state.apiSessionId,
          updatedAtUtc: DateTime.now().toUtc(),
          transcript: state.transcript,
          computedSenders: state.computedSenders,
          activeLanguages: state.activeLanguages,
          selectedLanguage: state.selectedLanguage,
          selectedRawSender: state.selectedRawSender,
        ),
      );
    } on Object {
      // Best-effort persistence.
    }
  }

  Future<void> _disposeClient() async {
    await _phaseSub?.cancel();
    _phaseSub = null;
    await _client?.stop();
    _client = null;
  }

  void _dispose() {
    _snapshotDebounce?.cancel();
    lectureSessionDebugDispose(state.sessionId);
    final handler = lectureTtsAudioHandler;
    handler?.detach();
    unawaited(handler?.clearMediaSession());
    _ttsMediaAttached = false;
    unawaited(_tts?.dispose());
    _tts = null;
    unawaited(_disposeClient());
  }
}
