import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';

/// Default host for cached-text API (same as shorten when not using deeplink).
const kCachedTextApiOrigin = kLectureTranslatorHttpOrigin;

/// Max concurrent API fetches when the user taps Select all in the share sheet.
const kShareSelectAllFetchConcurrency = 2;

class CachedTextFetchException implements Exception {
  CachedTextFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<String> fetchCachedText({
  required String sessionId,
  required String language,
  String httpsOrigin = kCachedTextApiOrigin,
  http.Client? client,
}) async {
  final uri = Uri.parse(httpsOrigin).replace(
    path: '/get_cached_text/$sessionId',
    queryParameters: {'window': language},
  );
  if (kDebugMode) {
    debugPrint('fetchCachedText: GET $uri');
  }
  final c = client ?? http.Client();
  try {
    final response = await c.get(uri).timeout(const Duration(seconds: 30));
    if (kDebugMode) {
      debugPrint(
        'fetchCachedText: ${response.statusCode} '
        'bodyLength=${response.body.length}',
      );
    }
    if (response.statusCode != 200) {
      throw CachedTextFetchException(
        'HTTP ${response.statusCode}',
      );
    }
    if (response.body.trim().isEmpty) {
      throw CachedTextFetchException('empty response');
    }
    return response.body;
  } on CachedTextFetchException {
    rethrow;
  } catch (e) {
    throw CachedTextFetchException('$e');
  }
}
