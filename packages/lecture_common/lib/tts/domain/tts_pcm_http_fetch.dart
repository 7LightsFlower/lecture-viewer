import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// URI string safe for logs (no embedded credentials).
String ttsPcmUriForLog(Uri uri) {
  return uri.replace(userInfo: '').toString();
}

bool _isRetriableFetchError(Object error) {
  return error is http.ClientException ||
      error is SocketException ||
      error is TimeoutException ||
      error is IOException;
}

/// Downloads one TTS PCM chunk with bounded retries for transient transport errors.
///
/// Returns the first HTTP 200 [http.Response], or `null` if cancelled, non-200,
/// or all attempts failed.
Future<http.Response?> fetchTtsPcmChunk(
  Uri uri, {
  required http.Client client,
  required bool Function() isCancelled,
  Duration firstAttemptDelay = const Duration(milliseconds: 50),
  int maxAttempts = 3,
  List<Duration> retryDelays = const [
    Duration(milliseconds: 150),
    Duration(milliseconds: 400),
  ],
}) async {
  if (isCancelled()) return null;

  if (firstAttemptDelay > Duration.zero) {
    await Future<void>.delayed(firstAttemptDelay);
    if (isCancelled()) return null;
  }

  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (isCancelled()) return null;

    try {
      final response = await client.get(uri);
      if (response.statusCode == 200) {
        return response;
      }
      return null;
    } on Object catch (e) {
      if (!_isRetriableFetchError(e)) {
        rethrow;
      }
      lastError = e;
      if (attempt >= maxAttempts) break;

      final delayIndex = attempt - 1;
      final delay = delayIndex < retryDelays.length
          ? retryDelays[delayIndex]
          : retryDelays.last;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (isCancelled()) return null;
    }
  }

  debugPrint(
    'TTS PCM fetch failed after $maxAttempts attempts: '
    '${ttsPcmUriForLog(uri)} ($lastError)',
  );
  return null;
}
