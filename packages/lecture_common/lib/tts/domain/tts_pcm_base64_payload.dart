import 'dart:convert';
import 'dart:typed_data';

/// Some TTS endpoints return the payload as a JSON string literal, e.g.
/// `"AQID..."` including the surrounding double quotes. Raw base64 is also
/// accepted.
String pcmBase64PayloadFromHttpBody(String body) {
  var s = body.trim();
  if (s.isEmpty) return s;
  if (s.startsWith('\uFEFF')) {
    s = s.substring(1).trim();
  }
  if (s.startsWith('"')) {
    try {
      final v = jsonDecode(s);
      if (v is String) return v.trim();
    } catch (_) {
      // Not valid JSON; strip a single pair of wrapping quotes if present.
    }
    if (s.length >= 2 && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
  }
  return s;
}

Uint8List decodePcmBase64BytesFromHttpBody(String body) {
  final payload = pcmBase64PayloadFromHttpBody(body);
  if (payload.isEmpty) return Uint8List(0);
  return Uint8List.fromList(base64Decode(payload));
}
