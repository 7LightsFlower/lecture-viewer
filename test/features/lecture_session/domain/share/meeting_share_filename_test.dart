import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/meeting_share_filename.dart';

void main() {
  test('meetingSharePdfFileNameForLanguage produces .pdf extension', () {
    final name = meetingSharePdfFileNameForLanguage(
      DateTime(2026, 6, 12),
      'German',
    );
    expect(name, 'Meeting_2026_06_12_German.pdf');
  });

  test('sanitizes special characters in language name', () {
    final name = meetingSharePdfFileNameForLanguage(
      DateTime(2026, 6, 1),
      'Español (ES)',
    );
    expect(name, startsWith('Meeting_2026_06_01_'));
    expect(name, endsWith('.pdf'));
    expect(name, isNot(contains('(')));
  });
}
