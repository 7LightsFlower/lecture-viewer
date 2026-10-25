import 'package:flutter/foundation.dart';

const String kTtsPlayStartDebugTag = '[TtsPlayStart]';

void ttsPlayStartDebug(String message) {
  if (kDebugMode) {
    debugPrint('$kTtsPlayStartDebugTag $message');
  }
}
