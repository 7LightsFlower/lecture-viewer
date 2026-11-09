import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// True once [initializeSoloudEngine] succeeded.
///
/// On web, SoLoud needs the scripts from `web/index.html`; if they are
/// missing or the browser refuses audio, the app keeps running without TTS.
bool isSoloudReady() {
  try {
    return SoLoud.instance.isInitialized;
  } on Object {
    return false;
  }
}

/// Drops a native SoLoud engine left over after hot restart (Dart isolate gone,
/// FFI callbacks still registered).
void releaseStaleSoloudEngine() {
  if (isSoloudReady()) {
    SoLoud.instance.deinit();
  }
}

/// Call from `main` after [configureLectureTtsAudioSession] and before any
/// TTS playback. Never throws: a failed audio engine must not keep the app
/// from starting (this blanked the screen in Chrome).
Future<void> initializeSoloudEngine() async {
  try {
    releaseStaleSoloudEngine();
    await SoLoud.instance.init();
  } on Object catch (error) {
    debugPrint('[SoLoud] init failed, TTS playback disabled: $error');
  }
}

void disposeSoloudEngine() {
  if (isSoloudReady()) {
    SoLoud.instance.deinit();
  }
}
