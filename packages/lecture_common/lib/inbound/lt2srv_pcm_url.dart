/// Extracts LT2SRV session id from PCM stream URLs:
/// `...?name=Data/<lt2srv_session_id>/...`
String? parseLt2srvSessionIdFromPcmUrl(String url) {
  try {
    final name = Uri.parse(url).queryParameters['name'];
    if (name == null || name.isEmpty) return null;
    final parts = name.split('/');
    if (parts.length < 2 || parts[0] != 'Data') return null;
    final id = parts[1].trim();
    if (id.isEmpty) return null;
    return id;
  } on Object {
    return null;
  }
}
