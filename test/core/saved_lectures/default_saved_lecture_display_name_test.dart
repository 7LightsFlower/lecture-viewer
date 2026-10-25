import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/format/default_saved_lecture_display_name.dart';

void main() {
  const locale = Locale('en', 'US');
  final now = DateTime(2026, 5, 20, 14, 30);

  test('first save of day returns localized date only', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const [],
        now: now,
      ),
      'May 20, 2026',
    );
  });

  test('second save same day appends (2)', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const ['May 20, 2026'],
        now: now,
      ),
      'May 20, 2026 (2)',
    );
  });

  test('third save uses (3) when (2) exists', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const ['May 20, 2026', 'May 20, 2026 (2)'],
        now: now,
      ),
      'May 20, 2026 (3)',
    );
  });

  test('ignores unrelated display names', () {
    expect(
      defaultSavedLectureDisplayName(
        locale: locale,
        existingDisplayNames: const ['Other lecture', 'May 19, 2026'],
        now: now,
      ),
      'May 20, 2026',
    );
  });
}
