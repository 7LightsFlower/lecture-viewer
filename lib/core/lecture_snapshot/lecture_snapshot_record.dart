import 'dart:convert';

import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

class LectureSnapshotRecord {
  const LectureSnapshotRecord({
    required this.linkRecord,
    required this.sessionId,
    required this.updatedAtUtc,
    required this.transcript,
    required this.computedSenders,
    required this.activeLanguages,
    required this.selectedLanguage,
    required this.selectedRawSender,
  });

  final String linkRecord;
  final String sessionId;
  final DateTime updatedAtUtc;
  final SessionTranscriptState transcript;
  final Map<String, ComputedSenderInfo> computedSenders;
  final List<String> activeLanguages;
  final String selectedLanguage;
  final String selectedRawSender;

  /// True when [sessionId] is the websocket `info.sessionID`, not the meeting name.
  bool get hasWebsocketSessionId {
    final meetingName = meetingNameFromLinkRecord(linkRecord);
    if (meetingName == null || sessionId.trim().isEmpty) return false;
    return sessionId != meetingName;
  }

  Map<String, Object?> toRow() => {
        'link_record': linkRecord,
        'session_id': sessionId,
        'updated_at_utc': updatedAtUtc.toUtc().toIso8601String(),
        'transcript_json': jsonEncode(transcript.toJson()),
        'computed_senders_json': jsonEncode(
          computedSenders.map((k, v) => MapEntry(k, v.toJson())),
        ),
        'active_languages_json': jsonEncode(activeLanguages),
        'selected_language': selectedLanguage,
        'selected_raw_sender': selectedRawSender,
      };

  static LectureSnapshotRecord fromRow(Map<String, Object?> row) {
    final sendersRaw =
        jsonDecode(row['computed_senders_json']! as String) as Map<String, dynamic>;
    final senders = <String, ComputedSenderInfo>{};
    for (final entry in sendersRaw.entries) {
      senders[entry.key] = ComputedSenderInfo.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    final langs = (jsonDecode(row['active_languages_json']! as String) as List)
        .map((e) => e.toString())
        .toList();
    return LectureSnapshotRecord(
      linkRecord: row['link_record']! as String,
      sessionId: row['session_id']! as String,
      updatedAtUtc: DateTime.parse(row['updated_at_utc']! as String),
      transcript: SessionTranscriptState.fromJson(
        jsonDecode(row['transcript_json']! as String) as Map<String, dynamic>,
      ),
      computedSenders: senders,
      activeLanguages: langs,
      selectedLanguage: row['selected_language']! as String,
      selectedRawSender: row['selected_raw_sender']! as String,
    );
  }
}
