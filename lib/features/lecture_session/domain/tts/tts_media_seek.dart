/// Maps lock-screen / notification seek position to in-app normalized seek.
double ttsNormalizedSeekFromDuration({
  required Duration position,
  required double bufferedDurationSec,
}) {
  if (bufferedDurationSec <= 0) return 0;
  final bufferedMs = (bufferedDurationSec * 1000).round();
  if (bufferedMs <= 0) return 0;
  final normalized = position.inMilliseconds / bufferedMs;
  if (normalized.isNaN || normalized.isInfinite) return 0;
  return normalized.clamp(0.0, 1.0);
}
