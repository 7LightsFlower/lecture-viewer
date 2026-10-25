import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/format/saved_lecture_last_join_format.dart';

String _norm(String s) => s.replaceAll('\u202f', ' ');

void main() {
  const locale = Locale('en', 'US');
  DateTime utcAsLocal(DateTime u) => u;

  group('formatSavedLectureLastJoinTime', () {
    test('same calendar day shows Today and time', () {
      final now = DateTime.utc(2026, 5, 15, 20, 0);
      final result = formatSavedLectureLastJoinTime(
        '2026-05-15T14:30:00.000Z',
        now: now,
        locale: locale,
        utcToLocalOverride: utcAsLocal,
      );
      expect(_norm(result), 'Last join time: Today, 2:30 PM');
    });

    test('previous calendar day shows Yesterday and time', () {
      final now = DateTime.utc(2026, 5, 15, 10, 0);
      final result = formatSavedLectureLastJoinTime(
        '2026-05-14T21:15:00.000Z',
        now: now,
        locale: locale,
        utcToLocalOverride: utcAsLocal,
      );
      expect(_norm(result), 'Last join time: Yesterday, 9:15 PM');
    });

    test('older than yesterday shows short date without time', () {
      final now = DateTime.utc(2026, 5, 15, 10, 0);
      final result = formatSavedLectureLastJoinTime(
        '2026-05-10T12:00:00.000Z',
        now: now,
        locale: locale,
        utcToLocalOverride: utcAsLocal,
      );
      expect(result, 'Last join time: May 10, 2026');
    });
  });
}
