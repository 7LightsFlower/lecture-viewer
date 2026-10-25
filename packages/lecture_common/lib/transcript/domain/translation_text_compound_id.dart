/// Stable id for speaker + transcript correlation.
///
/// Uses ASCII unit separator so `rawSender` / `textId` cannot collide.
String translationTextCompoundId({
  required String rawSender,
  required String textId,
}) {
  return '$rawSender\u001f$textId';
}
