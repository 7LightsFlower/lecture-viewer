import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';

void main() {
  test('toJson/fromJson round-trip', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    final restored = SavedLecture.fromJson(lecture.toJson());
    expect(restored, lecture);
  });

  test('fromJson falls back lastJoinedAt to savedAt', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    final json = lecture.toJson()..remove('lastJoinedAt');
    final restored = SavedLecture.fromJson(json);
    expect(restored.lastJoinedAt, lecture.savedAt);
  });

  test('fromJson without joinUrl is null', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    final json = lecture.toJson()..remove('joinUrl');
    expect(SavedLecture.fromJson(json).joinUrl, isNull);
  });

  test('fromJson blank joinUrl is null', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    final json = lecture.toJson()..['joinUrl'] = '   ';
    expect(SavedLecture.fromJson(json).joinUrl, isNull);
  });

  test('toJson/fromJson keeps joinUrl', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
      joinUrl:
          'https://lectureviewer.app.link/x?link_record=lt2srv.example.edu/mobile/session/foo-lecture',
    );
    expect(SavedLecture.fromJson(lecture.toJson()), lecture);
  });

  test('copyWith sets joinUrl when missing', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    const url =
        'https://lectureviewer.app.link/x?link_record=lt2srv.example.edu/mobile/session/foo-lecture';
    expect(lecture.copyWith(joinUrl: url).joinUrl, url);
  });
}
