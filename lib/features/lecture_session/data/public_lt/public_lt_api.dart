import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One output component of a running LT session (from `getgraph`), with the
/// display metadata the viewer needs. Mirrors the backend's
/// `ComponentSenderDetail` (`backend/.../audio-lecture/asr_client.ts`).
@immutable
class PublicLtSender {
  const PublicLtSender({
    required this.original,
    required this.language,
    required this.type,
    required this.percent,
    this.langCode,
  });

  /// Builds metadata for [worker] (e.g. `mt:3_de`, `postproduction:50_en`)
  /// from the raw `get_output_language_component` response body.
  factory PublicLtSender.fromWorker(String worker, String languageBody) {
    var language = languageBody.trim();
    // The endpoint may answer with a JSON string literal.
    if (language.length >= 2 &&
        language.startsWith('"') &&
        language.endsWith('"')) {
      try {
        language = jsonDecode(language) as String;
      } on Object {
        language = language.substring(1, language.length - 1);
      }
    }
    if (worker.contains('tts')) {
      language = language.replaceAll('Audio', '').trim();
    }

    final colonParts = worker.split(':');
    final type = colonParts.first;
    var percent = 0;
    if (worker.contains('postproduction') && colonParts.length > 1) {
      percent = int.tryParse(colonParts[1].split('_').first) ?? 0;
    }
    final underscoreParts = worker.split('_');
    final langCode = underscoreParts.length > 1 ? underscoreParts[1] : null;

    return PublicLtSender(
      original: worker,
      language: language,
      type: type,
      percent: percent,
      langCode: langCode,
    );
  }

  final String original;
  final String language;
  final String type;
  final int percent;
  final String? langCode;

  /// Shape of one `computedSenders` entry in the backend `info` envelope.
  Map<String, dynamic> toJson() => {
        'language': language,
        'type': type,
        'percent': percent,
        'langCode': langCode,
        'original': original,
      };
}

class PublicLtApiException implements Exception {
  PublicLtApiException(this.message);

  final String message;

  @override
  String toString() => 'PublicLtApiException: $message';
}

/// Thin client for the openly reachable KIT Lecture Translator `/webapi`
/// routes. These mirror the credentialed `/ltapi` routes the backend uses.
class PublicLtApi {
  PublicLtApi({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const _jsonHeaders = {
    'Content-Type': 'application/json;charset=UTF-8',
  };
  static const _timeout = Duration(seconds: 30);

  /// KIT expects JSON bodies encoded twice (`_formatBody` in asr_client.ts).
  static String doubleEncoded(Object body) => jsonEncode(jsonEncode(body));

  static String _trimOrigin(String origin) =>
      origin.replaceAll(RegExp(r'/+$'), '');

  /// Resolves a permanent meeting name via
  /// `GET {origin}/webapi/shorten/{name}?returnurl=1`.
  ///
  /// Returns the numeric LT session id plus the origin that hosts it
  /// (taken from the returned session URL), or `null` when no session is
  /// running under that name.
  Future<({String sessionId, String apiOrigin})?> resolveSession({
    required String shortenOrigin,
    required String meetingName,
  }) async {
    final base = _trimOrigin(shortenOrigin);
    final uri = Uri.parse(
      '$base/webapi/shorten/${Uri.encodeComponent(meetingName)}',
    ).replace(queryParameters: {'returnurl': '1'});
    final response = await _client.get(uri).timeout(_timeout);
    if (kDebugMode) {
      debugPrint(
        '[PublicLt] shorten ${response.statusCode} body=${response.body.trim()}',
      );
    }
    return parseShortenResponse(
      statusCode: response.statusCode,
      body: response.body,
      fallbackOrigin: base,
    );
  }

  /// Pure parsing step of [resolveSession], exposed for tests.
  static ({String sessionId, String apiOrigin})? parseShortenResponse({
    required int statusCode,
    required String body,
    required String fallbackOrigin,
  }) {
    if (statusCode != 200) return null;
    final text = body.trim();
    if (text.isEmpty || text.contains('ERROR')) return null;

    final segments =
        text.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty);
    if (segments.isEmpty) return null;
    final id = segments.last;
    if (!RegExp(r'^\d+$').hasMatch(id)) return null;

    var apiOrigin = _trimOrigin(fallbackOrigin);
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      apiOrigin = uri.origin;
    }
    return (sessionId: id, apiOrigin: apiOrigin);
  }

  /// `POST /webapi/{id}/getgraph` → component names that publish output
  /// (graph entries whose targets include `api`).
  Future<List<String>> outputComponents({
    required String apiOrigin,
    required String sessionId,
  }) async {
    final uri = Uri.parse('${_trimOrigin(apiOrigin)}/webapi/$sessionId/getgraph');
    final response =
        await _client.post(uri, headers: _jsonHeaders).timeout(_timeout);
    if (response.statusCode != 200) {
      throw PublicLtApiException('getgraph HTTP ${response.statusCode}');
    }
    return outputComponentsFromGraph(jsonDecode(response.body));
  }

  /// Pure parsing step of [outputComponents], exposed for tests.
  static List<String> outputComponentsFromGraph(Object? graph) {
    if (graph is! Map) return const [];
    final out = <String>[];
    for (final entry in graph.entries) {
      final targets = entry.value;
      final publishes = targets is List
          ? targets.any((t) => '$t'.contains('api'))
          : '$targets'.contains('api');
      if (publishes) out.add('${entry.key}');
    }
    return out;
  }

  /// `POST /webapi/{id}/{stream}/get_output_language_component` for each
  /// component (4 at a time, like the backend).
  Future<Map<String, PublicLtSender>> senders({
    required String apiOrigin,
    required String sessionId,
    required List<String> components,
  }) async {
    final base = _trimOrigin(apiOrigin);
    final out = <String, PublicLtSender>{};
    const batchSize = 4;
    for (var i = 0; i < components.length; i += batchSize) {
      final batch = components.skip(i).take(batchSize);
      await Future.wait(batch.map((worker) async {
        final parts = worker.split(':');
        if (parts.length < 2) return;
        final uri = Uri.parse(
          '$base/webapi/$sessionId/${parts[1]}/get_output_language_component',
        );
        final response = await _client
            .post(
              uri,
              headers: _jsonHeaders,
              body: doubleEncoded({'component': worker}),
            )
            .timeout(_timeout);
        if (response.statusCode != 200) {
          throw PublicLtApiException(
            'get_output_language_component($worker) '
            'HTTP ${response.statusCode}',
          );
        }
        out[worker] = PublicLtSender.fromWorker(worker, response.body);
      }));
    }
    return out;
  }

  /// `POST /webapi/{id}/get_previous_messages` for one component.
  /// The response is a JSON array of JSON-encoded message strings.
  Future<List<Map<String, dynamic>>> previousMessages({
    required String apiOrigin,
    required String sessionId,
    required String component,
  }) async {
    final uri = Uri.parse(
      '${_trimOrigin(apiOrigin)}/webapi/$sessionId/get_previous_messages',
    );
    final response = await _client
        .post(
          uri,
          headers: _jsonHeaders,
          body: doubleEncoded({'component': component, 'begin': 0}),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw PublicLtApiException(
        'get_previous_messages($component) HTTP ${response.statusCode}',
      );
    }
    return decodePreviousMessages(response.body);
  }

  /// Pure parsing step of [previousMessages], exposed for tests.
  static List<Map<String, dynamic>> decodePreviousMessages(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      try {
        final map = item is String ? jsonDecode(item) : item;
        if (map is Map<String, dynamic>) out.add(map);
      } on Object {
        // Skip malformed entries, like the backend does.
      }
    }
    return out;
  }

  /// URI of the live event stream for [sessionId].
  static Uri streamUri({required String apiOrigin, required String sessionId}) {
    return Uri.parse('${_trimOrigin(apiOrigin)}/webapi/stream')
        .replace(queryParameters: {'channel': sessionId});
  }

  void close() => _client.close();
}
