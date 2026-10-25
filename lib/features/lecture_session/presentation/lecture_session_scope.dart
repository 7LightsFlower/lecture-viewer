typedef LectureSessionScope = ({
  String sessionId,
  String linkRecord,
  String? joinUrl,
});

LectureSessionScope lectureSessionScope({
  required String sessionId,
  required String linkRecord,
  String? joinUrl,
}) =>
    (sessionId: sessionId, linkRecord: linkRecord, joinUrl: joinUrl);
