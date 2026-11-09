import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'public_lt_api.dart';
import 'sse_connection.dart';
import 'sse_event_parser.dart';

Future<SseConnection> openSseConnection(
  Uri uri, {
  required http.Client Function() clientFactory,
}) {
  final source = web.EventSource(uri.toString());
  final connection = _EventSourceConnection(source);
  final opened = Completer<SseConnection>();

  source.onopen = ((web.Event _) {
    if (!opened.isCompleted) opened.complete(connection);
  }).toJS;

  source.onmessage = ((web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is! String) return;
    connection._add(
      SseEvent(event: 'message', data: data, id: event.lastEventId),
    );
  }).toJS;

  source.onerror = ((web.Event _) {
    // EventSource would retry on its own; reconnects are handled by
    // PublicLtSessionClient's loop instead, so end this connection here.
    // A failure before `open` is usually CORS or a non-200 response.
    unawaited(connection.close());
    if (!opened.isCompleted) {
      opened.completeError(
        PublicLtApiException(
          'EventSource failed to open $uri (CORS blocked or HTTP error)',
        ),
      );
    }
  }).toJS;

  return opened.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      unawaited(connection.close());
      throw PublicLtApiException('EventSource open timed out: $uri');
    },
  );
}

final class _EventSourceConnection implements SseConnection {
  _EventSourceConnection(this._source);

  final web.EventSource _source;
  final StreamController<SseEvent> _controller = StreamController<SseEvent>();

  @override
  Stream<SseEvent> get events => _controller.stream;

  void _add(SseEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  @override
  Future<void> close() async {
    _source.close();
    // Not awaited: close() of an unlistened controller never completes.
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}
