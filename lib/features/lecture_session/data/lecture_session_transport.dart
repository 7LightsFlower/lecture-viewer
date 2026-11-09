import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';

/// Receive-only source of lecture session envelopes.
///
/// Implementations deliver backend-format JSON envelopes
/// (`{"status":200,"objectType":"info"|"texts"|"raw_pcm",...}`) through the
/// `onText` callback they are constructed with, so the session notifier and
/// `parseLectureInbound` work unchanged regardless of where data comes from.
abstract interface class LectureSessionTransport {
  Stream<LectureWsPhase> get phase;

  Future<void> start();

  Future<void> stop();
}
