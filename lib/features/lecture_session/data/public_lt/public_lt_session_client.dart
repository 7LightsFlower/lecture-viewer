import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/data/lecture_session_transport.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';

import 'public_lt_api.dart';
import 'public_lt_message_adapter.dart';
import 'sse_connection.dart';
import 'sse_event_parser.dart';

const _tag = '[PublicLt]';

/// Reads a lecture session straight from the public KIT Lecture Translator
/// (`/webapi/shorten`, `getgraph`, `get_output_language_component`,
/// `get_previous_messages`, `stream?channel=`) instead of the app backend.
///
/// Emits backend-format envelopes through [onText], so it is a drop-in
/// replacement for `LectureSessionWebSocketClient`.
final class PublicLtSessionClient implements LectureSessionTransport {
  PublicLtSessionClient({
    required String meetingName,
    required String shortenOrigin,
    required void Function(String text) onText,
    bool loadHistory = false,
    PublicLtApi? api,
    http.Client Function()? streamClientFactory,
    Random? random,
  })  : _meetingName = meetingName,
        _shortenOrigin = shortenOrigin,
        _onText = onText,
        _loadHistory = loadHistory,
        _api = api ?? PublicLtApi(),
        _ownsApi = api == null,
        _streamClientFactory = streamClientFactory ?? http.Client.new,
        _random = random ?? Random();

  final String _meetingName;
  final String _shortenOrigin;
  final void Function(String) _onText;
  final bool _loadHistory;
  final PublicLtApi _api;
  final bool _ownsApi;
  final http.Client Function() _streamClientFactory;
  final Random _random;

  final StreamController<LectureWsPhase> _phaseController =
      StreamController<LectureWsPhase>.broadcast(sync: true);

  bool _stopRequested = false;
  bool _stoppedPhaseEmitted = false;
  bool _historyLoaded = false;
  bool _everResolved = false;
  SseConnection? _connection;
  StreamSubscription<SseEvent>? _subscription;
  PublicLtMessageAdapter? _adapter;
  Completer<void> _stopSignal = Completer<void>();

  @override
  Stream<LectureWsPhase> get phase => _phaseController.stream;

  @override
  Future<void> start() async {
    _stopRequested = false;
    _stoppedPhaseEmitted = false;
    _stopSignal = Completer<void>();
    unawaited(_runReconnectLoop());
  }

  @override
  Future<void> stop() async {
    _requestStop();
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
    if (_ownsApi) _api.close();
    _emitStoppedOnceIfNeeded();
  }

  Future<void> _runReconnectLoop() async {
    var attempt = 0;
    while (!_stopRequested) {
      if (attempt == 0) {
        _addPhase(LectureWsPhase.connecting);
      } else {
        _addPhase(LectureWsPhase.reconnecting);
        await Future<void>.delayed(
          reconnectDelay(attemptZeroBased: attempt - 1, random: _random),
        );
        if (_stopRequested) break;
      }

      var connected = false;
      try {
        connected = await _connectOnce();
      } catch (error) {
        if (kDebugMode) debugPrint('$_tag connect failed: $error');
        if (kIsWeb && attempt == 0 && error is http.ClientException) {
          // Browsers block cross-origin calls unless KIT sends CORS headers.
          debugPrint(
            '$_tag In Chrome this is usually CORS. For local testing run: '
            'flutter run -d chrome --web-browser-flag "--disable-web-security"',
          );
        }
      }

      if (_stopRequested) break;
      attempt = connected ? 1 : attempt + 1;
    }
    _emitStoppedOnceIfNeeded();
  }

  /// One full connect cycle. Returns true if the live stream was opened.
  Future<bool> _connectOnce() async {
    // Re-resolve on every (re)connect: a restarted lecture gets a new id.
    final resolved = await _api.resolveSession(
      shortenOrigin: _shortenOrigin,
      meetingName: _meetingName,
    );
    if (_stopRequested) return false;
    if (resolved == null) {
      _requestStop();
      _emit(
        _everResolved
            ? PublicLtMessageAdapter.sessionEndEnvelope('session_already_over')
            : PublicLtMessageAdapter.serverErrorEnvelope('session not found'),
      );
      return false;
    }
    _everResolved = true;
    final (:sessionId, :apiOrigin) = resolved;

    final components = await _api.outputComponents(
      apiOrigin: apiOrigin,
      sessionId: sessionId,
    );
    final senders = await _api.senders(
      apiOrigin: apiOrigin,
      sessionId: sessionId,
      components: components,
    );
    if (_stopRequested) return false;

    // Keep paragraph/speaker state across reconnects of the same session.
    final previous = _adapter;
    final adapter = previous != null &&
            previous.sessionId == sessionId &&
            setEquals(previous.senders.keys.toSet(), senders.keys.toSet())
        ? previous
        : PublicLtMessageAdapter(
            apiOrigin: apiOrigin,
            sessionId: sessionId,
            senders: senders,
          );
    if (!identical(adapter, previous)) _historyLoaded = false;
    _adapter = adapter;
    _emit(adapter.infoEnvelope());

    if (_loadHistory && !_historyLoaded) {
      await _replayHistory(adapter);
      _historyLoaded = true;
      if (_stopRequested) return false;
    }

    return _listen(adapter);
  }

  Future<void> _replayHistory(PublicLtMessageAdapter adapter) async {
    final textSenders = adapter.senders.entries
        .where((e) => e.value.type != 'tts')
        .map((e) => e.key)
        .toList();
    final all = <Map<String, dynamic>>[];
    for (final sender in textSenders) {
      try {
        all.addAll(
          await _api.previousMessages(
            apiOrigin: adapter.apiOrigin,
            sessionId: adapter.sessionId,
            component: sender,
          ),
        );
      } catch (error) {
        if (kDebugMode) debugPrint('$_tag history($sender) failed: $error');
      }
      if (_stopRequested) return;
    }
    for (final envelope in adapter.adaptHistory(all)) {
      _emit(envelope);
    }
  }

  Future<bool> _listen(PublicLtMessageAdapter adapter) async {
    final connection = await openSseConnection(
      PublicLtApi.streamUri(
        apiOrigin: adapter.apiOrigin,
        sessionId: adapter.sessionId,
      ),
      clientFactory: _streamClientFactory,
    );
    _connection = connection;
    try {
      if (_stopRequested) return false;
      _addPhase(LectureWsPhase.connected);

      final done = Completer<void>();
      _subscription = connection.events.listen(
        (event) => _handleEvent(adapter, event),
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (Object error, StackTrace _) {
          if (kDebugMode) debugPrint('$_tag stream error: $error');
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      // stop() cancels the subscription, which completes neither callback.
      await Future.any([done.future, _stopSignal.future]);
      return true;
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      if (identical(_connection, connection)) _connection = null;
      await connection.close();
    }
  }

  void _requestStop() {
    _stopRequested = true;
    if (!_stopSignal.isCompleted) _stopSignal.complete();
  }

  void _handleEvent(PublicLtMessageAdapter adapter, SseEvent event) {
    if (_stopRequested) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(event.data);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    for (final envelope in adapter.adapt(decoded)) {
      _emit(envelope);
    }
    if ('${decoded['controll'] ?? ''}' == 'END') {
      _requestStop();
    }
  }

  void _emit(String envelope) {
    try {
      _onText(envelope);
    } catch (error) {
      if (kDebugMode) debugPrint('$_tag onText threw: $error');
    }
  }

  void _emitStoppedOnceIfNeeded() {
    if (_stoppedPhaseEmitted || _phaseController.isClosed) return;
    _stoppedPhaseEmitted = true;
    _phaseController.add(LectureWsPhase.stopped);
  }

  void _addPhase(LectureWsPhase phase) {
    if (!_phaseController.isClosed) _phaseController.add(phase);
  }
}
