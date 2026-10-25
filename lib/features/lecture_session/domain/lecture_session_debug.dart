import 'package:flutter/foundation.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';

const kLectureSessionDebugTag = '[LectureSession]';

DateTime? _partialLogWindowStart;
int _partialsInWindow = 0;
DateTime? _transcriptLogWindowStart;
DateTime? _ignoredLogWindowStart;
int _ignoredInWindow = 0;
DateTime? _ttsPcmLogWindowStart;
int _ttsPcmInWindow = 0;
int _ttsPcmEnqueuedInWindow = 0;
int _ttsPcmSkippedNoLangInWindow = 0;
int _ttsPcmSkippedMismatchInWindow = 0;
int _ttsPcmSkippedNoSelectedLangInWindow = 0;
double _lastLoggedBufferedSec = -1;

void lectureSessionDebugConnect({
  required String sessionId,
  required String wsUrl,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '$kLectureSessionDebugTag connect session=$sessionId wsUrl=$wsUrl',
  );
}

void lectureSessionDebugPhase({
  required String sessionId,
  required LectureWsPhase phase,
}) {
  if (!kDebugMode) return;
  debugPrint('$kLectureSessionDebugTag phase session=$sessionId $phase');
}

void lectureSessionDebugRetry(String sessionId) {
  if (!kDebugMode) return;
  debugPrint('$kLectureSessionDebugTag retry session=$sessionId');
}

void lectureSessionDebugDispose(String sessionId) {
  if (!kDebugMode) return;
  debugPrint('$kLectureSessionDebugTag dispose session=$sessionId');
}

void lectureSessionDebugLanguage({
  required String sessionId,
  required String language,
  required String rawSender,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '$kLectureSessionDebugTag language session=$sessionId '
    'lang=$language module=$rawSender',
  );
}

void lectureSessionDebugSessionEnd({
  required String sessionId,
  String? audioUrl,
  String? raw,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '$kLectureSessionDebugTag session-end session=$sessionId '
    'audioUrl=${audioUrl ?? '—'}'
    '${raw == null ? '' : ' raw=${_preview(raw, 500)}'}',
  );
}

void lectureSessionDebugInfo({
  required String sessionId,
  required List<String> activeLanguages,
  required Map<String, ComputedSenderInfo> computedSenders,
  required String selectedLanguage,
  required String selectedRawSender,
  String? inboundSessionId,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '$kLectureSessionDebugTag info session=$sessionId '
    'inboundSessionId=${inboundSessionId ?? '—'} '
    'langs=${activeLanguages.join(',')} '
    'senders=${computedSenders.length} '
    'selected=$selectedLanguage module=$selectedRawSender',
  );
}

void lectureSessionDebugText({
  required TranscriptTextEvent event,
  required Iterable<String> bucketKeys,
}) {
  if (!kDebugMode) return;

  final force = event.isFinal || event.isEndParagraph;
  if (!force && !_shouldEmitPartial()) return;
  if (!force) _partialsInWindow += 1;

  // debugPrint(
  //   '$kLectureSessionDebugTag text '
  //   'raw=${event.rawSender} sender=${event.sender} '
  //   'buckets=${bucketKeys.isEmpty ? 'skipped' : bucketKeys.join(',')} '
  //   'final=${event.isFinal} endPara=${event.isEndParagraph} '
  //   'textId=${event.textId} text="${_preview(event.text)}"',
  // );
}

void lectureSessionDebugTranscript({
  required SessionTranscriptState transcript,
  bool force = false,
}) {
  if (!kDebugMode) return;

  if (!force) {
    final now = DateTime.now();
    _transcriptLogWindowStart ??= now;
    final elapsed = now.difference(_transcriptLogWindowStart!);
    if (elapsed < const Duration(seconds: 2)) return;
    _transcriptLogWindowStart = now;
  } else {
    _transcriptLogWindowStart = DateTime.now();
  }

}

void lectureSessionDebugTtsPcm({
  required String rawSender,
  required String? languageFromPayload,
  required String? resolvedLanguage,
  required String selectedLanguage,
  required bool enqueued,
  String? skipReason,
}) {
  if (!kDebugMode) return;

  _ttsPcmInWindow += 1;
  if (enqueued) {
    _ttsPcmEnqueuedInWindow += 1;
  } else if (skipReason == 'no_language') {
    _ttsPcmSkippedNoLangInWindow += 1;
  } else if (skipReason == 'no_selected_language') {
    _ttsPcmSkippedNoSelectedLangInWindow += 1;
  } else if (skipReason == 'language_mismatch') {
    _ttsPcmSkippedMismatchInWindow += 1;
  }

  final now = DateTime.now();
  _ttsPcmLogWindowStart ??= now;
  if (now.difference(_ttsPcmLogWindowStart!) < const Duration(seconds: 2)) {
    return;
  }

  debugPrint(
    '$kLectureSessionDebugTag tts-pcm window '
    'total=$_ttsPcmInWindow enqueued=$_ttsPcmEnqueuedInWindow '
    'skipNoLang=$_ttsPcmSkippedNoLangInWindow '
    'skipNoSelected=$_ttsPcmSkippedNoSelectedLangInWindow '
    'skipMismatch=$_ttsPcmSkippedMismatchInWindow '
    'selected=$selectedLanguage',
  );
  if (!enqueued && skipReason != null) {
    debugPrint(
      '$kLectureSessionDebugTag tts-pcm last-skip '
      'reason=$skipReason rawSender=$rawSender '
      'payloadLang=${languageFromPayload ?? '—'} '
      'resolved=${resolvedLanguage ?? '—'} selected=$selectedLanguage',
    );
  }
  _ttsPcmInWindow = 0;
  _ttsPcmEnqueuedInWindow = 0;
  _ttsPcmSkippedNoLangInWindow = 0;
  _ttsPcmSkippedMismatchInWindow = 0;
  _ttsPcmSkippedNoSelectedLangInWindow = 0;
  _ttsPcmLogWindowStart = now;
}

void lectureSessionDebugTtsEnqueue({required String url}) {
  if (!kDebugMode) return;
  debugPrint(
    '$kLectureSessionDebugTag tts enqueue url=${_preview(url, 100)}',
  );
}

void lectureSessionDebugTtsFetch({
  required String url,
  required String outcome,
  double? addedSeconds,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '$kLectureSessionDebugTag tts fetch $outcome '
    'url=${_preview(url, 80)} '
    '${addedSeconds != null ? 'added=${addedSeconds.toStringAsFixed(2)}s' : ''}',
  );
}

void lectureSessionDebugTtsSnapshot(TtsPaneSnapshot snap) {
  if (!kDebugMode) return;

  final buf = snap.bufferedDurationSec;
  final changed = (buf - _lastLoggedBufferedSec).abs() > 0.25 ||
      snap.isPlaying != false && _lastLoggedBufferedSec < 0;
  if (!changed && snap.pendingDownloadCount == 0) return;

  _lastLoggedBufferedSec = buf;
  debugPrint(
    '$kLectureSessionDebugTag tts snapshot '
    'buffered=${buf.toStringAsFixed(2)}s '
    'pos=${snap.playbackPositionSec.toStringAsFixed(2)}s '
    'playing=${snap.isPlaying} pending=${snap.pendingDownloadCount} '
    'playEnabled=${buf > 0}',
  );
}

void lectureSessionDebugIgnored({required String raw}) {
  if (!kDebugMode) return;

  _ignoredInWindow += 1;
  final now = DateTime.now();
  _ignoredLogWindowStart ??= now;
  final elapsed = now.difference(_ignoredLogWindowStart!);
  if (elapsed < const Duration(seconds: 2)) return;

  final sample = _preview(raw, 120);
  debugPrint(
    '$kLectureSessionDebugTag ignored '
    'count=$_ignoredInWindow sample="$sample"',
  );
  if (raw.contains('raw_pcm')) {
    debugPrint(
      '$kLectureSessionDebugTag ignored raw_pcm — check parser '
      '(url/rawSender/tts: prefix)',
    );
  }
  _ignoredInWindow = 0;
  _ignoredLogWindowStart = now;
}

bool _shouldEmitPartial() {
  final now = DateTime.now();
  _partialLogWindowStart ??= now;
  final elapsed = now.difference(_partialLogWindowStart!);
  if (elapsed >= const Duration(seconds: 2)) {
    if (_partialsInWindow > 0) {
      debugPrint(
        '$kLectureSessionDebugTag partial window: '
        '$_partialsInWindow suppressed',
      );
    }
    _partialsInWindow = 0;
    _partialLogWindowStart = now;
    return true;
  }
  return false;
}

String _preview(String text, [int maxLen = 80]) {
  final compact = text.replaceAll('\n', r'\n');
  if (compact.length <= maxLen) return compact;
  return '${compact.substring(0, maxLen)}…';
}
