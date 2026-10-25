String meetingShareBaseName(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return 'Meeting_${y}_${m}_$d';
}

String meetingShareLanguageSuffix(String languageDisplayName) {
  final sanitized =
      languageDisplayName.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
  final collapsed = sanitized
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (collapsed.isEmpty) return 'Language';
  return collapsed;
}

String meetingShareTextFileNameForLanguage(
  DateTime date,
  String languageDisplayName,
) {
  return '${meetingShareBaseName(date)}_${meetingShareLanguageSuffix(languageDisplayName)}.txt';
}

String meetingSharePdfFileNameForLanguage(
  DateTime date,
  String languageDisplayName,
) {
  return '${meetingShareBaseName(date)}_${meetingShareLanguageSuffix(languageDisplayName)}.pdf';
}
