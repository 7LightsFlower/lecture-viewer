import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_record.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/lecture_share_input.dart';

LectureShareInput lectureShareInputFromSnapshot({
  required String subject,
  required LectureSnapshotRecord record,
  required String httpsOrigin,
}) {
  return LectureShareInput(
    subject: subject,
    activeLanguages: record.activeLanguages,
    sessionId: record.sessionId,
    httpsOrigin: httpsOrigin,
  );
}
