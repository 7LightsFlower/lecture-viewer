import 'dart:async';
import 'dart:math';

import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/lecture_session_transport.dart';

import 'lecture_ws_phase.dart';

/// Receive-only WebSocket client for lecture session viewer.
final class LectureSessionWebSocketClient implements LectureSessionTransport {
  LectureSessionWebSocketClient({
    required String wsUrl,
    required void Function(String text) onText,
    Random? random,
  }) : _uri = Uri.parse(wsUrl),
       _onText = onText,
       _random = random ?? Random();

  final Uri _uri;
  final void Function(String) _onText;
  final Random _random;

  final StreamController<LectureWsPhase> _phaseController =
      StreamController<LectureWsPhase>.broadcast(sync: true);

  bool _stopRequested = false;
  bool _stoppedPhaseEmitted = false;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;

  @override
  Stream<LectureWsPhase> get phase => _phaseController.stream;

  @override
  Future<void> start() async {
    _stopRequested = false;
    _stoppedPhaseEmitted = false;
    unawaited(_runReconnectLoop());
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _emitStoppedOnceIfNeeded();
  }

  Future<void> _runReconnectLoop() async {
    var attempt = 0;
    while (!_stopRequested) {
      if (attempt == 0) {
        _addPhase(LectureWsPhase.connecting);
      } else {
        _addPhase(LectureWsPhase.reconnecting);
        await Future.delayed(
          reconnectDelay(attemptZeroBased: attempt - 1, random: _random),
        );
        if (_stopRequested) break;
      }

      WebSocketChannel? ch;
      try {
        final connectUri = kLectureWsNoHistoryOnInitialConnect || attempt == 0
            ? _uri
            : lectureSessionWsReconnectUri(_uri);
        ch = WebSocketChannel.connect(connectUri);
        _channel = ch;
        await ch.ready;
        if (_stopRequested) {
          await _closeQuietly(ch.sink);
          break;
        }

        _addPhase(LectureWsPhase.connected);
        attempt = 0;

        final done = Completer<void>();
        _streamSubscription = ch.stream.listen(
          (data) {
            if (data is String) _onText(data);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          onError: (_, _) {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        await done.future;
      } catch (_) {
        // retry
      } finally {
        await _streamSubscription?.cancel();
        _streamSubscription = null;
        if (identical(_channel, ch)) _channel = null;
        await _closeQuietly(ch?.sink);
      }

      if (_stopRequested) break;
      attempt++;
    }
    _emitStoppedOnceIfNeeded();
  }

  void _emitStoppedOnceIfNeeded() {
    if (_stoppedPhaseEmitted || _phaseController.isClosed) return;
    _stoppedPhaseEmitted = true;
    _phaseController.add(LectureWsPhase.stopped);
  }

  void _addPhase(LectureWsPhase phase) {
    if (!_phaseController.isClosed) _phaseController.add(phase);
  }

  static Future<void> _closeQuietly(dynamic sink) async {
    if (sink == null) return;
    try {
      await sink.close();
    } catch (_) {}
  }
}
