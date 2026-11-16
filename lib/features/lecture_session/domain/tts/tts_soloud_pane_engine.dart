import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;

import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/core/bootstrap/configure_lecture_tts_audio_session.dart';
import 'package:lecture_viewer_v3/core/bootstrap/soloud_engine.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/lecture_session_debug.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_spoken_piece.dart';

Uint8List _decodeBodyIsolate((String?, Uint8List) args) {
  final (contentType, bodyBytes) = args;
  return decodeTtsPcmResponseBody(
    contentType: contentType,
    bodyBytes: bodyBytes,
  );
}

/// Where one appended chunk sits in the audio stream.
typedef _ChunkSpan = ({double startSec, double endSec, TtsSpokenPiece piece});

/// Per-pane TTS: FIFO URL download, PCM append to a preserved SoLoud buffer.
final class TtsSoloudPaneEngine {
  TtsSoloudPaneEngine({
    required void Function(TtsPaneSnapshot) onSnapshot,
    void Function(TtsSpokenPiece?)? onSpoken,
  })  : _onSnapshot = onSnapshot,
        _onSpoken = onSpoken;

  final void Function(TtsPaneSnapshot) _onSnapshot;
  final void Function(TtsSpokenPiece?)? _onSpoken;
  final Queue<(String, TtsSpokenPiece?)> _queue =
      Queue<(String, TtsSpokenPiece?)>();

  /// Appended chunks with text, in stream order (for the spoken highlight).
  final List<_ChunkSpan> _chunks = [];
  TtsSpokenPiece? _lastSpoken;

  bool _disposed = false;
  int _clearEpoch = 0;
  bool _draining = false;
  int _inFlightDownloads = 0;
  final http.Client _httpClient = http.Client();

  AudioSource? _source;
  SoundHandle? _handle;

  /// True after user starts playback until they explicitly pause. Used to
  /// restart SoLoud when the voice handle goes invalid (buffer underrun) while
  /// new PCM is still being appended.
  bool _userWantsPlayback = false;

  double _bufferedDurationSec = 0;
  double _playbackPositionSec = 0;
  int _bufferGeneration = 0;
  Timer? _positionTimer;

  TtsPaneSnapshot _snapshot() {
    final playing = isSoloudReady() &&
        _handle != null &&
        !SoLoud.instance.getPause(_handle!);
    return TtsPaneSnapshot(
      bufferedDurationSec: _bufferedDurationSec,
      playbackPositionSec: _playbackPositionSec,
      isPlaying: playing,
      pendingDownloadCount: _queue.length + _inFlightDownloads,
      bufferGeneration: _bufferGeneration,
    );
  }

  void _emit() {
    _onSnapshot(_snapshot());
    _emitSpokenIfChanged();
  }

  /// The piece at the playhead while audio is being played.
  TtsSpokenPiece? get currentSpoken {
    if (_handle == null || _chunks.isEmpty) return null;
    final pos = _playbackPositionSec;
    // Binary search: last chunk starting at or before the playhead.
    var lo = 0, hi = _chunks.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_chunks[mid].startSec <= pos) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (found < 0) return null;
    final c = _chunks[found];
    return pos < c.endSec ? c.piece : null;
  }

  void _emitSpokenIfChanged() {
    final cur = currentSpoken;
    if (identical(cur, _lastSpoken)) return;
    _lastSpoken = cur;
    _onSpoken?.call(cur);
  }

  void enqueue(String url, {TtsSpokenPiece? spoken}) {
    if (_disposed) return;
    _queue.addLast((url, spoken));
    _emit();
    unawaited(_drainQueue());
  }

  /// KIT names only the last text message of a chunk (min = max), but a
  /// chunk speaks everything since the previous one of the same stream.
  TtsSpokenPiece _withRangeFromPrevious(TtsSpokenPiece piece) {
    final maxId = piece.maxId;
    if (maxId == null) return piece;
    int? prevMax;
    for (final c in _chunks.reversed) {
      final m = c.piece.maxId;
      if (c.piece.textSender == piece.textSender && m != null && m < maxId) {
        prevMax = m;
        break;
      }
    }
    if (prevMax == null || prevMax + 1 > maxId) return piece;
    final lo = piece.minId;
    return lo == null || lo > prevMax + 1 ? piece.withMinId(prevMax + 1) : piece;
  }

  Future<void> _drainQueue() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final (url, spoken) = _queue.removeFirst();
        _inFlightDownloads++;
        _emit();
        try {
          await _fetchDecodeAppend(url, spoken);
        } finally {
          _inFlightDownloads--;
          _emit();
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _fetchDecodeAppend(String url, TtsSpokenPiece? spoken) async {
    final epoch = _clearEpoch;
    if (_disposed) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      lectureSessionDebugTtsFetch(url: url, outcome: 'bad_uri');
      return;
    }

    final res = await fetchTtsPcmChunk(
      uri,
      client: _httpClient,
      isCancelled: () => _disposed || epoch != _clearEpoch,
      // Like KIT's page and LT_ClientApp: public /webapi, no login.
      usePublicRoute: true,
    );
    if (_disposed || epoch != _clearEpoch) {
      lectureSessionDebugTtsFetch(url: url, outcome: 'cancelled');
      return;
    }
    if (res == null) {
      lectureSessionDebugTtsFetch(url: url, outcome: 'fetch_failed');
      return;
    }

    final bodyBytes = res.bodyBytes;
    if (bodyBytes.isEmpty) {
      lectureSessionDebugTtsFetch(url: url, outcome: 'empty_body');
      return;
    }

    // Base64 in JSON/text, or raw PCM (see decodeTtsPcmResponseBody).
    final contentType = res.headers['content-type'];
    final Uint8List decoded;
    try {
      decoded = bodyBytes.length > 100000
          ? await compute(_decodeBodyIsolate, (contentType, bodyBytes))
          : decodeTtsPcmResponseBody(
              contentType: contentType,
              bodyBytes: bodyBytes,
            );
    } on FormatException {
      lectureSessionDebugTtsFetch(url: url, outcome: 'bad_audio_payload');
      return;
    }
    if (_disposed || epoch != _clearEpoch) return;

    var pcm = decoded;
    if (pcm.lengthInBytes.isOdd) {
      pcm = Uint8List.sublistView(pcm, 0, pcm.lengthInBytes - 1);
    }
    if (pcm.isEmpty) {
      lectureSessionDebugTtsFetch(url: url, outcome: 'empty_pcm');
      return;
    }

    if (epoch != _clearEpoch || _disposed) return;

    if (!isSoloudReady()) {
      lectureSessionDebugTtsFetch(url: url, outcome: 'no_audio_engine');
      return;
    }

    final samples = pcm.lengthInBytes ~/ 2;
    final seconds = samples / 16000.0;

    _source ??= SoLoud.instance.setBufferStream(
      maxBufferSizeDuration: const Duration(hours: 8),
      bufferingType: BufferingType.preserved,
      bufferingTimeNeeds: 0.35,
      sampleRate: 16000,
      channels: Channels.mono,
      format: BufferType.s16le,
    );

    SoLoud.instance.addAudioDataStream(_source!, pcm);
    if (spoken != null) {
      _chunks.add((
        startSec: _bufferedDurationSec,
        endSec: _bufferedDurationSec + seconds,
        piece: _withRangeFromPrevious(spoken),
      ));
    }
    _bufferedDurationSec += seconds;
    _bufferGeneration++;
    lectureSessionDebugTtsFetch(
      url: url,
      outcome: 'ok',
      addedSeconds: seconds,
    );
    _emit();
    unawaited(_resumePlaybackIfNeededAfterAppend());
  }

  /// Keeps playback going when new chunks arrive: unpause after buffering, or
  /// start a new voice if the previous one ended at the buffer tail.
  Future<void> _resumePlaybackIfNeededAfterAppend() async {
    if (_disposed || !_userWantsPlayback) return;
    final src = _source;
    if (src == null || _bufferedDurationSec <= 0) return;

    await activateLectureTtsAudioSession();
    if (_disposed || !_userWantsPlayback) {
      await deactivateLectureTtsAudioSession();
      _emit();
      return;
    }

    final h = _handle;
    if (h != null && SoLoud.instance.getIsValidVoiceHandle(h)) {
      SoLoud.instance.setPause(h, false);
      _emit();
      return;
    }

    await _restartVoiceAfterUnderrun();
  }

  Future<void> _restartVoiceAfterUnderrun() async {
    if (_disposed || !_userWantsPlayback) return;
    final src = _source;
    if (src == null || _bufferedDurationSec <= 0) return;

    _handle = null;
    final resumeSec = _playbackPositionSec.clamp(
      0.0,
      max(0.0, _bufferedDurationSec - 0.02),
    );
    final pos = Duration(microseconds: (resumeSec * 1e6).round());

    final h = await SoLoud.instance.play(src);
    if (_disposed || !_userWantsPlayback) {
      await SoLoud.instance.stop(h);
      await deactivateLectureTtsAudioSession();
      _emit();
      return;
    }
    _handle = h;
    SoLoud.instance.seek(h, pos);
    _startPositionTicker();
    _emit();
  }

  void _startPositionTicker() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_disposed) return;
      final h = _handle;
      if (h == null) return;
      try {
        final d = SoLoud.instance.getPosition(h);
        _playbackPositionSec = d.inMicroseconds / 1e6;
        _emit();
      } catch (_) {}
    });
  }

  void _stopPositionTicker() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Stops SoLoud voice and disposes the buffer source (must run before
  /// [deactivateLectureTtsAudioSession] on iOS).
  Future<void> _stopVoiceAndSource() async {
    _stopPositionTicker();
    final h = _handle;
    if (h != null) {
      await SoLoud.instance.stop(h);
      _handle = null;
    }
    final src = _source;
    if (src != null) {
      await SoLoud.instance.disposeSource(src);
      _source = null;
    }
  }

  /// User pressed Play on transport. Tail-join via [resolveTtsPlayStart].
  Future<void> playFromUserTap() async {
    _userWantsPlayback = true;
    if (_source == null || _bufferedDurationSec <= 0) {
      _emit();
      return;
    }
    await _startPlaybackAtResolved(
      resolveTtsPlayStart(
        playheadSec: _playbackPositionSec,
        bufferedSec: _bufferedDurationSec,
      ),
      debugLabel: 'explicit play',
      preserveIntentOnFailure: true,
    );
  }

  /// User pressed Pause. Stops output; clears user intent; keeps buffer/queue.
  Future<void> pauseFromUserTap() async {
    if (_disposed) return;
    _userWantsPlayback = false;
    final h = _handle;
    if (h != null) {
      _stopPositionTicker();
      try {
        await SoLoud.instance.stop(h);
      } catch (_) {}
      if (_handle == h) {
        _handle = null;
      }
    }
    await deactivateLectureTtsAudioSession();
    _emit();
  }

  /// Auto-TTS duck: pause output only; keep playhead.
  Future<void> pauseForAutoDuck() async => _pauseOutput();

  /// Auto-TTS resume after duck: continue from playhead when possible.
  Future<void> resumeAfterAutoDuck() async {
    final decision = resolveTtsResumeAfterDuck(
      playheadSec: _playbackPositionSec,
      bufferedSec: _bufferedDurationSec,
    );
    switch (decision) {
      case TtsResumeAfterDuckSkip():
        return;
      case TtsResumeAfterDuckFromPlayhead(:final startSec):
        _userWantsPlayback = true;
        await _startPlaybackAtSec(startSec, debugLabel: 'auto-resume');
      case TtsResumeAfterDuckTailJoin(:final playStart):
        _userWantsPlayback = true;
        await _startPlaybackAtResolved(playStart, debugLabel: 'auto-resume tail');
    }
  }

  Future<void> _pauseOutput() async {
    if (_disposed) return;
    _userWantsPlayback = false;
    final h = _handle;
    if (h != null &&
        SoLoud.instance.getIsValidVoiceHandle(h) &&
        !SoLoud.instance.getPause(h)) {
      SoLoud.instance.setPause(h, true);
      _stopPositionTicker();
    }
    await deactivateLectureTtsAudioSession();
    _emit();
  }

  Future<void> _startPlaybackAtResolved(
    TtsPlayStartResult result, {
    required String debugLabel,
    bool preserveIntentOnFailure = false,
  }) async {
    ttsPlayStartDebug(
      '$debugLabel (p=${_playbackPositionSec.toStringAsFixed(3)}s '
      'D=${_bufferedDurationSec.toStringAsFixed(3)}s)',
    );
    final src = _source;
    if (src == null || _bufferedDurationSec <= 0) {
      ttsPlayStartDebug(
        'abort no source/buffer (hasSource=${src != null} '
        'D=${_bufferedDurationSec.toStringAsFixed(3)}s)',
      );
      if (!preserveIntentOnFailure) {
        _userWantsPlayback = false;
      }
      _emit();
      return;
    }

    switch (result) {
      case TtsPlayStartSkip():
        ttsPlayStartDebug('engine skip → stay paused');
        if (!preserveIntentOnFailure) {
          _userWantsPlayback = false;
        }
        _emit();
      case TtsPlayStartFrom(:final startSec):
        await _startPlaybackAtSec(startSec, debugLabel: debugLabel);
    }
  }

  Future<void> _startPlaybackAtSec(
    double startSec, {
    required String debugLabel,
  }) async {
    final src = _source;
    if (src == null || _bufferedDurationSec <= 0) {
      _userWantsPlayback = false;
      _emit();
      return;
    }

    await activateLectureTtsAudioSession();
    if (_disposed || !_userWantsPlayback) {
      await deactivateLectureTtsAudioSession();
      _emit();
      return;
    }

    final target = startSec.clamp(0.0, _bufferedDurationSec);
    final targetDur = Duration(microseconds: (target * 1e6).round());

    final existing = _handle;
    if (existing != null && SoLoud.instance.getIsValidVoiceHandle(existing)) {
      ttsPlayStartDebug(
        '$debugLabel seek existing → ${target.toStringAsFixed(3)}s',
      );
      SoLoud.instance.setPause(existing, false);
      SoLoud.instance.seek(existing, targetDur);
      _playbackPositionSec = target;
      _startPositionTicker();
      _emit();
      return;
    }

    ttsPlayStartDebug(
      '$debugLabel play+seek new → ${target.toStringAsFixed(3)}s',
    );
    _handle = null;
    final h = await SoLoud.instance.play(src);
    if (_disposed || !_userWantsPlayback) {
      await SoLoud.instance.stop(h);
      await deactivateLectureTtsAudioSession();
      _emit();
      return;
    }
    _handle = h;
    SoLoud.instance.seek(h, targetDur);
    _playbackPositionSec = target;
    _startPositionTicker();
    _emit();
  }

  @Deprecated('Use playFromUserTap / pauseFromUserTap')
  Future<void> pausePlaybackOnly() async => pauseFromUserTap();

  @Deprecated('Use playFromUserTap / pauseFromUserTap')
  Future<void> togglePlayPause() async {
    if (_disposed) return;
    final h = _handle;
    if (h != null &&
        SoLoud.instance.getIsValidVoiceHandle(h) &&
        !SoLoud.instance.getPause(h)) {
      await pauseFromUserTap();
      return;
    }
    await playFromUserTap();
  }

  void seekToNormalized(double normalized) {
    if (_disposed) return;
    final h = _handle;
    if (h == null || _bufferedDurationSec <= 0) return;
    final clamped = normalized.clamp(0.0, 1.0);
    final posSec = clamped * _bufferedDurationSec;
    SoLoud.instance.seek(
      h,
      Duration(microseconds: (posSec * 1e6).round()),
    );
    _playbackPositionSec = posSec;
    _emit();
  }

  bool get userWantsPlayback => _userWantsPlayback;

  Future<void> clear() => clearBuffer(preserveUserPlaybackIntent: false);

  Future<void> clearBuffer({bool preserveUserPlaybackIntent = false}) async {
    _clearEpoch++;
    if (!preserveUserPlaybackIntent) {
      _userWantsPlayback = false;
    }
    _queue.clear();
    _chunks.clear();
    await _stopVoiceAndSource();
    _bufferedDurationSec = 0;
    _playbackPositionSec = 0;
    _bufferGeneration = 0;
    await deactivateLectureTtsAudioSession();
    _emit();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _clearEpoch++;
    _userWantsPlayback = false;
    _disposed = true;
    _httpClient.close();
    _queue.clear();
    await _stopVoiceAndSource();
    await deactivateLectureTtsAudioSession();
  }
}
