import 'package:http/http.dart' as http;

import 'sse_connection_io.dart'
    if (dart.library.js_interop) 'sse_connection_web.dart' as impl;
import 'sse_event_parser.dart';

/// An open Server-Sent Events connection.
abstract interface class SseConnection {
  /// Events until the connection ends (server close, network error, [close]).
  Stream<SseEvent> get events;

  Future<void> close();
}

/// Opens [uri] as an event stream. Completes once the server accepted it
/// (HTTP 200 / `EventSource.onopen`), throws otherwise.
///
/// Mobile/VM: streamed `package:http` request built with [clientFactory].
/// Web: the browser's native `EventSource` ([clientFactory] is unused there,
/// because XHR-based clients may not deliver a response before it ends).
Future<SseConnection> openSseConnection(
  Uri uri, {
  required http.Client Function() clientFactory,
}) =>
    impl.openSseConnection(uri, clientFactory: clientFactory);
