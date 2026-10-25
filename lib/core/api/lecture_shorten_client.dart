import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';

const _shortenTimeout = Duration(seconds: 20);
const _shortenLogBodyLimit = 2000;

String _previewShortenBody(String body) {
  final compact = body.replaceAll('\n', r'\n');
  if (compact.length <= _shortenLogBodyLimit) return compact;
  return '${compact.substring(0, _shortenLogBodyLimit)}…';
}

/// Pre-join availability probe. Returns HTTP status, or null on transport failure.
abstract class LectureShortenClient {
  Future<int?> checkShorten(
    String meetingName, {
    String httpsOrigin = kLectureTranslatorHttpOrigin,
  });
}

class HttpLectureShortenClient implements LectureShortenClient {
  HttpLectureShortenClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<int?> checkShorten(
    String meetingName, {
    String httpsOrigin = kLectureTranslatorHttpOrigin,
  }) async {
    final encoded = Uri.encodeComponent(meetingName);
    final base = httpsOrigin.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/webapi/shorten/$encoded');
    if (kDebugMode) {
      debugPrint('[LectureShorten] GET $uri meeting=$meetingName');
    }
    try {
      final response = await _httpClient.get(uri).timeout(_shortenTimeout);
      if (kDebugMode) {
        debugPrint(
          '[LectureShorten] status=${response.statusCode} '
          'body=${_previewShortenBody(response.body)}',
        );
      }
      return response.statusCode;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LectureShorten] error=$error');
      }
      return null;
    }
  }
}

final LectureShortenClient defaultLectureShortenClient =
    HttpLectureShortenClient();
