import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// User-facing last-join label for saved lecture list rows (local calendar + locale).
String formatSavedLectureLastJoinTime(
  String lastJoinedAtIsoUtc, {
  required DateTime now,
  Locale locale = const Locale('en', 'US'),
  DateTime Function(DateTime utc)? utcToLocalOverride,
}) {
  final joinedAtUtc = DateTime.parse(lastJoinedAtIsoUtc).toUtc();
  DateTime toLocal(DateTime utc) =>
      utcToLocalOverride?.call(utc) ?? utc.toLocal();
  final local = toLocal(joinedAtUtc);
  final nowLocal = toLocal(now.toUtc());
  final localDay = DateTime(local.year, local.month, local.day);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final localeName = locale.toString();
  final time = DateFormat.jm(localeName).format(local);

  final String when;
  if (localDay == today) {
    when = 'Today, $time';
  } else if (localDay == yesterday) {
    when = 'Yesterday, $time';
  } else {
    when = DateFormat.yMMMd(localeName).format(local);
  }
  return 'Last join time: $when';
}
