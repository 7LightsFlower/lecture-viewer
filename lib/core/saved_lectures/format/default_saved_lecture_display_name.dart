import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// Default bookmark title: localized calendar date, with `(2)` suffix on collision.
String defaultSavedLectureDisplayName({
  required Locale locale,
  required Iterable<String> existingDisplayNames,
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final base = DateFormat.yMMMd(locale.toString()).format(when);
  final escaped = RegExp.escape(base);
  final suffixPattern = RegExp('^$escaped \\((\\d+)\\)\$');

  var maxSuffix = 0;
  for (final name in existingDisplayNames) {
    if (name == base) {
      maxSuffix = maxSuffix < 1 ? 1 : maxSuffix;
      continue;
    }
    final match = suffixPattern.firstMatch(name);
    if (match != null) {
      final n = int.parse(match.group(1)!);
      if (n > maxSuffix) maxSuffix = n;
    }
  }

  if (maxSuffix == 0) return base;
  return '$base (${maxSuffix + 1})';
}
