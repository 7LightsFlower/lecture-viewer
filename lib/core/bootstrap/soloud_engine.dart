import 'package:flutter_soloud/flutter_soloud.dart';

/// Drops a native SoLoud engine left over after hot restart (Dart isolate gone,
/// FFI callbacks still registered).
void releaseStaleSoloudEngine() {
  if (SoLoud.instance.isInitialized) {
    SoLoud.instance.deinit();
  }
}

/// Call from `main` after [configureLectureTtsAudioSession] and before any
/// TTS playback.
Future<void> initializeSoloudEngine() async {
  releaseStaleSoloudEngine();
  await SoLoud.instance.init();
}

void disposeSoloudEngine() {
  if (SoLoud.instance.isInitialized) {
    SoLoud.instance.deinit();
  }
}
