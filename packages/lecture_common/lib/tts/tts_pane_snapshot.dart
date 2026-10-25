import 'package:flutter/foundation.dart';

@immutable
class TtsPaneSnapshot {
  const TtsPaneSnapshot({
    this.bufferedDurationSec = 0,
    this.playbackPositionSec = 0,
    this.isPlaying = false,
    this.pendingDownloadCount = 0,
    this.bufferGeneration = 0,
  });

  final double bufferedDurationSec;
  final double playbackPositionSec;
  final bool isPlaying;
  final int pendingDownloadCount;
  final int bufferGeneration;

  TtsPaneSnapshot copyWith({
    double? bufferedDurationSec,
    double? playbackPositionSec,
    bool? isPlaying,
    int? pendingDownloadCount,
    int? bufferGeneration,
  }) {
    return TtsPaneSnapshot(
      bufferedDurationSec: bufferedDurationSec ?? this.bufferedDurationSec,
      playbackPositionSec: playbackPositionSec ?? this.playbackPositionSec,
      isPlaying: isPlaying ?? this.isPlaying,
      pendingDownloadCount: pendingDownloadCount ?? this.pendingDownloadCount,
      bufferGeneration: bufferGeneration ?? this.bufferGeneration,
    );
  }
}
