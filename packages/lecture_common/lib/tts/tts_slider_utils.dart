/// Minimum timeline extent for sliders (avoids div-by-zero).
double ttsSliderMaxSeconds(double bufferedDurationSec) {
  if (bufferedDurationSec.isNaN || bufferedDurationSec.isInfinite) {
    return 1e-6;
  }
  if (bufferedDurationSec <= 0) return 1e-6;
  return bufferedDurationSec;
}
