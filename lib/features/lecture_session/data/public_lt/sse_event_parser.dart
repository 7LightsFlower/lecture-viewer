import 'dart:async';

/// One Server-Sent Event.
class SseEvent {
  const SseEvent({required this.event, required this.data, this.id});

  /// Event name; `message` when the stream did not set one.
  final String event;
  final String data;
  final String? id;
}

/// Turns a stream of text lines (already split, e.g. via `LineSplitter`)
/// into [SseEvent]s following the WHATWG event-stream rules:
/// `data:` lines accumulate (joined by `\n`), a blank line dispatches,
/// lines starting with `:` are comments.
class SseEventTransformer extends StreamTransformerBase<String, SseEvent> {
  const SseEventTransformer();

  @override
  Stream<SseEvent> bind(Stream<String> lines) async* {
    String? eventName;
    String? lastId;
    final data = <String>[];

    await for (final line in lines) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          yield SseEvent(
            event: eventName ?? 'message',
            data: data.join('\n'),
            id: lastId,
          );
        }
        data.clear();
        eventName = null;
        continue;
      }
      if (line.startsWith(':')) continue;

      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);

      switch (field) {
        case 'data':
          data.add(value);
        case 'event':
          eventName = value;
        case 'id':
          lastId = value;
        default:
          break; // `retry` and unknown fields are ignored.
      }
    }

    // Stream closed without a trailing blank line: flush what we have.
    if (data.isNotEmpty) {
      yield SseEvent(
        event: eventName ?? 'message',
        data: data.join('\n'),
        id: lastId,
      );
    }
  }
}
