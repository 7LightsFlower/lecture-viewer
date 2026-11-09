import 'dart:convert';

import 'package:http/http.dart' as http;

import 'public_lt_api.dart';
import 'sse_connection.dart';
import 'sse_event_parser.dart';

Future<SseConnection> openSseConnection(
  Uri uri, {
  required http.Client Function() clientFactory,
}) async {
  final client = clientFactory();
  try {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache';
    final response =
        await client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw PublicLtApiException('stream HTTP ${response.statusCode}');
    }
    final events = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .transform(const SseEventTransformer());
    return _HttpSseConnection(events, client);
  } catch (_) {
    client.close();
    rethrow;
  }
}

final class _HttpSseConnection implements SseConnection {
  _HttpSseConnection(this.events, this._client);

  @override
  final Stream<SseEvent> events;
  final http.Client _client;

  @override
  Future<void> close() async => _client.close();
}
