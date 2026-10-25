import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;

/// Playback-only session so TTS (SoLoud) continues when the app is backgrounded.
///
/// Call from `main` before [initializeSoloudEngine]. Re-call
/// [activateLectureTtsAudioSession] before starting output so iOS keeps the
/// process eligible for background audio.
Future<void> configureLectureTtsAudioSession() async {
  if (kIsWeb) return;
  final session = await AudioSession.instance;
  // Playback category does not support allowBluetooth / allowBluetoothA2dp
  // (those require playAndRecord); invalid options cause OSStatus -50 on iOS/macOS.
  await session.configure(const AudioSessionConfiguration.speech());
}

bool _lectureTtsAudioSessionActive = false;

/// Marks the app as actively playing audio (required for iOS background playback).
Future<void> activateLectureTtsAudioSession() async {
  if (kIsWeb) return;
  final session = await AudioSession.instance;
  await session.setActive(true);
  _lectureTtsAudioSessionActive = true;
}

/// Releases background audio eligibility when the user stops TTS output.
///
/// Call only after SoLoud output has stopped; iOS rejects deactivation while
/// audio is still playing ([AVAudioSessionErrorCodeIsBusy] / 560030580).
Future<void> deactivateLectureTtsAudioSession() async {
  if (kIsWeb || !_lectureTtsAudioSessionActive) return;
  try {
    final session = await AudioSession.instance;
    await session.setActive(
      false,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    );
  } on PlatformException {
    // Already inactive or teardown raced with platform audio — safe to ignore.
  } finally {
    _lectureTtsAudioSessionActive = false;
  }
}
