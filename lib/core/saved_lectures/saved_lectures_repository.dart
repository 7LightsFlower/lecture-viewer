import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'saved_lecture.dart';

const String kSavedLecturesPrefsKey = 'saved_lectures_v1';

class SavedLecturesRepository {
  SavedLecturesRepository(this._prefs);

  final SharedPreferences _prefs;

  List<SavedLecture> load() {
    final raw = _prefs.getString(kSavedLecturesPrefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final lectures = decoded
        .whereType<Map>()
        .map((e) => SavedLecture.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    lectures.sort((a, b) => b.lastJoinedAt.compareTo(a.lastJoinedAt));
    return lectures;
  }

  bool containsLinkRecord(String linkRecord) {
    final normalized = linkRecord.trim();
    return load().any((e) => e.linkRecord.trim() == normalized);
  }

  Future<bool> add(SavedLecture lecture) async {
    final normalized = lecture.linkRecord.trim();
    final existing = load();
    if (existing.any((e) => e.linkRecord.trim() == normalized)) {
      return false;
    }
    final next = [lecture, ...existing];
    return _persist(next);
  }

  Future<void> removeByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final next = load().where((e) => !ids.contains(e.id)).toList();
    await _persist(next);
  }

  Future<bool> updateDisplayName(String id, String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return false;

    final existing = load();
    if (!existing.any((e) => e.id == id)) return false;

    final next = existing
        .map((lecture) => lecture.id == id
            ? lecture.copyWith(displayName: trimmed)
            : lecture)
        .toList();
    return _persist(next);
  }

  Future<bool> recordLastJoin(String id) async {
    final joinedAt = DateTime.now().toUtc().toIso8601String();
    final next = load().map((lecture) {
      if (lecture.id != id) return lecture;
      return lecture.copyWith(lastJoinedAt: joinedAt);
    }).toList();
    if (!next.any((e) => e.id == id)) return false;
    return _persist(next);
  }

  Future<bool> setJoinUrlIfMissing(String linkRecord, String joinUrl) async {
    final trimmedUrl = joinUrl.trim();
    if (trimmedUrl.isEmpty) return false;

    final normalized = linkRecord.trim();
    final existing = load();
    var changed = false;
    final next = existing.map((lecture) {
      if (lecture.linkRecord.trim() != normalized) return lecture;
      if (lecture.joinUrl != null) return lecture;
      changed = true;
      return lecture.copyWith(joinUrl: trimmedUrl);
    }).toList();
    if (!changed) return false;
    return _persist(next);
  }

  Future<bool> _persist(List<SavedLecture> lectures) async {
    final encoded = jsonEncode(lectures.map((e) => e.toJson()).toList());
    return _prefs.setString(kSavedLecturesPrefsKey, encoded);
  }
}
