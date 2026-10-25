import 'dart:math';

/// Full jitter backoff: delay in [base, cap], exponential by attempt.
Duration reconnectDelay({
  required int attemptZeroBased,
  required Random random,
  Duration base = const Duration(milliseconds: 500),
  Duration cap = const Duration(seconds: 30),
}) {
  final maxThisRoundMs = min(
    cap.inMilliseconds,
    base.inMilliseconds * (1 << min(attemptZeroBased, 16)),
  );
  final maxThisRound = Duration(milliseconds: maxThisRoundMs);
  final hi = maxThisRound.inMilliseconds;
  final lo = (hi ~/ 2).clamp(1, hi);
  return Duration(milliseconds: lo + random.nextInt(hi - lo + 1));
}
