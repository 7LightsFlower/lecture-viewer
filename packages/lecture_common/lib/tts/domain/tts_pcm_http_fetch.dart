import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// URI string safe for logs (no embedded credentials).
String ttsPcmUriForLog(Uri uri) {
  return uri.replace(userInfo: '').toString();
}

/// Public, login-free address of a TTS chunk.
///
/// The backend links chunks under the internal `/ltapi/` route with
/// `user:password@` in the URL. KIT serves the same data publicly under
/// `/webapi/` (this is what KIT's own page and LT_ClientApp use), so the
/// credentials are dropped and the route swapped. Browsers would refuse
/// URLs with credentials anyway.
Uri publicTtsPcmUri(Uri uri) {
  if (uri.scheme == 'data') return uri;
  var out = uri.userInfo.isEmpty ? uri : uri.replace(userInfo: '');
  if (out.path.startsWith('/ltapi/')) {
    out = out.replace(path: '/webapi/${out.path.substring('/ltapi/'.length)}');
  }
  return out;
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
///
/// With [usePublicRoute], the chunk is fetched from its login-free `/webapi`
/// address (see [publicTtsPcmUri]) instead of the URL as sent.
Future<http.Response?> fetchTtsPcmChunk(
  Uri uri, {
  required http.Client client,
  required bool Function() isCancelled,
  bool usePublicRoute = false,
  Duration firstAttemptDelay = const Duration(milliseconds: 50),
  int maxAttempts = 3,
  List<Duration> retryDelays = const [
    Duration(milliseconds: 150),
    Duration(milliseconds: 400),
  ],
}) async {
  if (isCancelled()) return null;
  if (uri.scheme == 'data') {
    // Inline audio (sent in the message itself): nothing to download.
    final data = uri.data!;
    return http.Response.bytes(
      data.contentAsBytes(),
      200,
      headers: {'content-type': data.mimeType},
    );
  }
  final requestUri = usePublicRoute ? publicTtsPcmUri(uri) : uri;

  if (firstAttemptDelay > Duration.zero) {
    await Future<void>.delayed(firstAttemptDelay);
    if (isCancelled()) return null;
  }

  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (isCancelled()) return null;

    try {
      final response = await client.get(requestUri);
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
