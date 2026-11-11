import 'dart:convert';
import 'dart:typed_data';

/// Extracts the base64 PCM payload from a TTS endpoint's text body.
///
/// Accepted shapes (same as KIT's page / LT_ClientApp):
/// - raw base64
/// - a JSON string literal `"AQID..."`
/// - a JSON object carrying it in `b64_enc_pcm_s16le`, `data` or `audio`
///   (otherwise its longest string value)
/// - any of the above with a `data:...;base64,` prefix
String pcmBase64PayloadFromHttpBody(String body) {
  var s = body.trim();
  if (s.isEmpty) return s;
  if (s.startsWith('﻿')) {
    s = s.substring(1).trim();
  }
  if (s.startsWith('"')) {
    try {
      final v = jsonDecode(s);
      if (v is String) s = v.trim();
    } catch (_) {
      // Not valid JSON; strip a single pair of wrapping quotes if present.
      if (s.length >= 2 && s.endsWith('"')) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
  } else if (s.startsWith('{')) {
    try {
      final v = jsonDecode(s);
      if (v is Map) s = _payloadFromJsonObject(v);
    } catch (_) {
      // Leave as is; base64 decoding will report the problem.
    }
  }
  if (s.startsWith('data:') && s.contains(',')) {
    s = s.substring(s.indexOf(',') + 1);
  }
  return s.replaceAll(RegExp(r'\s'), '');
}

String _payloadFromJsonObject(Map<dynamic, dynamic> json) {
  final known = json['b64_enc_pcm_s16le'] ?? json['data'] ?? json['audio'];
  if (known is String) return known.trim();
  String? longest;
  for (final v in json.values) {
    if (v is String && (longest == null || v.length > longest.length)) {
      longest = v;
    }
  }
  return longest?.trim() ?? '';
}

Uint8List decodePcmBase64BytesFromHttpBody(String body) {
  final payload = pcmBase64PayloadFromHttpBody(body);
  if (payload.isEmpty) return Uint8List(0);
  return Uint8List.fromList(base64Decode(base64.normalize(payload)));
}

/// Decodes a TTS chunk response into 16-bit little-endian PCM bytes.
///
/// JSON/text answers carry base64 (see [pcmBase64PayloadFromHttpBody]);
/// audio/binary answers are raw PCM. With no usable content type, text
/// that decodes as base64 wins, otherwise the bytes are taken as PCM.
Uint8List decodeTtsPcmResponseBody({
  required String? contentType,
  required Uint8List bodyBytes,
}) {
  if (bodyBytes.isEmpty) return Uint8List(0);
  final type = (contentType ?? '').toLowerCase();
  final isText = type.contains('json') || type.startsWith('text/');
  final isBinary = type.startsWith('audio/') ||
      type.contains('octet-stream') ||
      type.contains('pcm');
  if (isBinary && !isText) return bodyBytes;

  try {
    final text = utf8.decode(bodyBytes);
    return decodePcmBase64BytesFromHttpBody(text);
  } on FormatException {
    if (isText) rethrow;
    return bodyBytes; // Not text and not base64: raw PCM.
  }
}
