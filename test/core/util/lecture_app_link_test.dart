import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/constants/lecture_app_link_constants.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

void main() {
  group('isLectureViewerAppLink', () {
    test('accepts example Branch link', () {
      final uri = Uri.parse(kExampleLectureAppLink);
      expect(isLectureViewerAppLink(uri), isTrue);
    });

    test('rejects wrong host', () {
      expect(
        isLectureViewerAppLink(
          Uri.parse('https://example.com/x?link_record=a'),
        ),
        isFalse,
      );
    });

    test('rejects missing link_record', () {
      expect(
        isLectureViewerAppLink(Uri.parse('https://lectureviewer.app.link/abc')),
        isFalse,
      );
    });
  });

  group('resolveSessionUrl', () {
    test('prepends https when no scheme', () {
      expect(
        resolveSessionUrl('lt2srv.iar.kit.edu/mobile/session/foo'),
        'https://lt2srv.iar.kit.edu/mobile/session/foo',
      );
    });

    test('keeps https link_record', () {
      expect(
        resolveSessionUrl('https://lt2srv.iar.kit.edu/mobile/session/foo'),
        'https://lt2srv.iar.kit.edu/mobile/session/foo',
      );
    });
  });

  group('meetingNameFromLinkRecord', () {
    test('returns last path segment', () {
      expect(
        meetingNameFromLinkRecord(
          'lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture',
        ),
        'tkq1221114001-lecture',
      );
    });

    test('returns null when path empty', () {
      expect(meetingNameFromLinkRecord('https://example.com'), isNull);
    });
  });

  group('sessionNameFromAppLinkUri', () {
    test('reads session_name query param', () {
      expect(
        sessionNameFromAppLinkUri(
          Uri.parse(
            'https://lectureviewer.app.link/x?link_record=host/path&session_name=Room%20A',
          ),
        ),
        'Room A',
      );
    });

    test('returns null when missing or empty', () {
      expect(
        sessionNameFromAppLinkUri(
          Uri.parse('https://lectureviewer.app.link/x?link_record=host/path'),
        ),
        isNull,
      );
    });
  });

  group('sessionNameFromLinkRecord', () {
    test('reads session_name from resolved link_record url', () {
      expect(
        sessionNameFromLinkRecord(
          'lt2srv.iar.kit.edu/mobile/session/foo?session_name=My%20Lecture',
        ),
        'My Lecture',
      );
    });
  });

  group('sessionNameFromBranchSession', () {
    test('reads direct session_name key', () {
      expect(
        sessionNameFromBranchSession({'session_name': 'Dialog'}),
        'Dialog',
      );
    });

    test('parses session_name from canonical url', () {
      expect(
        sessionNameFromBranchSession({
          r'$canonical_url':
              'https://lectureviewer.app.link/x?link_record=host/path&session_name=Room',
        }),
        'Room',
      );
    });
  });

  group('linkRecordFromBranchSession', () {
    test('reads direct link_record key', () {
      expect(
        linkRecordFromBranchSession({'link_record': 'host/path'}),
        'host/path',
      );
    });

    test('parses link_record from canonical url', () {
      expect(
        linkRecordFromBranchSession({
          r'$canonical_url':
              'https://lectureviewer.app.link/x?link_record=host/path',
        }),
        'host/path',
      );
    });
  });

  group('joinUrlFromBranchSession', () {
    test('returns first valid lecture app link', () {
      expect(
        joinUrlFromBranchSession({
          r'$canonical_url':
              'https://lectureviewer.app.link/x?link_record=host/path',
          '+url': 'https://example.com/nope',
        }),
        'https://lectureviewer.app.link/x?link_record=host/path',
      );
    });

    test('skips invalid keys and uses later valid url', () {
      expect(
        joinUrlFromBranchSession({
          r'$canonical_url': 'https://example.com/x?link_record=host/path',
          '+url':
              'https://lectureviewer.app.link/y?link_record=host/path',
        }),
        'https://lectureviewer.app.link/y?link_record=host/path',
      );
    });

    test('returns null when only link_record custom data exists', () {
      expect(
        joinUrlFromBranchSession({'link_record': 'host/path'}),
        isNull,
      );
    });
  });
}
