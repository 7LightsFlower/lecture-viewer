import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/format/default_saved_lecture_display_name.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_repository.dart';

final savedLecturesProvider =
    NotifierProvider<SavedLecturesNotifier, List<SavedLecture>>(
  SavedLecturesNotifier.new,
);

class SavedLecturesNotifier extends Notifier<List<SavedLecture>> {
  late final SavedLecturesRepository _repository;

  @override
  List<SavedLecture> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    _repository = SavedLecturesRepository(prefs);
    return _repository.load();
  }

  bool containsLinkRecord(String linkRecord) {
    return _repository.containsLinkRecord(linkRecord);
  }

  Future<bool> add({
    String? displayName,
    required String linkRecord,
    required String sessionId,
    String? joinUrl,
    Locale? locale,
    DateTime? now,
  }) async {
    final trimmedName = displayName?.trim() ?? '';
    final resolvedName = trimmedName.isEmpty
        ? defaultSavedLectureDisplayName(
            locale: locale ?? const Locale('en', 'US'),
            existingDisplayNames: state.map((e) => e.displayName),
            now: now,
          )
        : trimmedName;

    final when = now ?? DateTime.now();
    final nowIso = when.toUtc().toIso8601String();
    final lecture = SavedLecture(
      id: const Uuid().v4(),
      displayName: resolvedName,
      linkRecord: linkRecord.trim(),
      sessionId: sessionId,
      savedAt: nowIso,
      lastJoinedAt: nowIso,
      joinUrl: () {
        final trimmed = joinUrl?.trim();
        if (trimmed == null || trimmed.isEmpty) return null;
        return trimmed;
      }(),
    );

    final ok = await _repository.add(lecture);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }

  Future<bool> updateDisplayName(String id, String displayName) async {
    final ok = await _repository.updateDisplayName(id, displayName);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }

  Future<void> removeByIds(Set<String> ids) async {
    await _repository.removeByIds(ids);
    state = _repository.load();
  }

  Future<void> recordLastJoin(String id) async {
    final ok = await _repository.recordLastJoin(id);
    if (ok) {
      state = _repository.load();
    }
  }

  Future<bool> setJoinUrlIfMissing(String linkRecord, String joinUrl) async {
    final ok = await _repository.setJoinUrlIfMissing(linkRecord, joinUrl);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }
}
