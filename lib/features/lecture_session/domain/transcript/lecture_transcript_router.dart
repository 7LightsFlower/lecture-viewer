import 'package:lecture_common/lecture_common.dart';

import 'lecture_bucket_key.dart';
import 'lecture_supported_modules.dart';

/// Selectable module route for a language (from session [computedSenders]).
class LectureModuleOption {
  const LectureModuleOption({
    required this.rawSender,
    required this.bucketKey,
    required this.label,
  });

  final String rawSender;
  final String bucketKey;
  final String label;
}

const _moduleTypeOrder = <String, int>{
  'asr': 0,
  'mt': 1,
  'postproduction': 2,
};

/// Bucket keys that should receive this [rawSender] (one per matching route).
Iterable<String> bucketKeysForRawSender({
  required String rawSender,
  required Map<String, ComputedSenderInfo> computedSenders,
}) sync* {
  final info = computedSenders[rawSender];
  if (info == null || !isSupportedLectureModuleType(info.type)) return;
  yield lectureBucketKey(
    languageDisplayName: info.language,
    rawSender: rawSender,
  );
}

bool transcriptBucketHasDisplayableContent(TranscriptBucket bucket) {
  final partial = bucket.partialText;
  if (partial != null && partial.trim().isNotEmpty) return true;
  return bucket.paragraphs.any((p) => p.segments.isNotEmpty);
}

String moduleDisplayLabel(ComputedSenderInfo info) {
  return switch (info.type) {
    'asr' || 'mt' => 'Normal',
    'postproduction' => 'Shortening ${info.percent}%',
    _ => info.type,
  };
}

/// All supported modules for [selectedLanguage] from [computedSenders].
List<LectureModuleOption> moduleOptionsForLanguage({
  required String selectedLanguage,
  required Map<String, ComputedSenderInfo> computedSenders,
}) {
  final entries = computedSenders.entries
      .where((e) => e.value.language == selectedLanguage)
      .where((e) => isSupportedLectureModuleType(e.value.type))
      .toList()
    ..sort((a, b) => _compareSenderRoutes(a.value, b.value));

  return [
    for (final entry in entries)
      LectureModuleOption(
        rawSender: entry.key,
        bucketKey: lectureBucketKey(
          languageDisplayName: entry.value.language,
          rawSender: entry.key,
        ),
        label: moduleDisplayLabel(entry.value),
      ),
  ];
}

/// First configured module for [selectedLanguage], or null if none.
String? defaultRawSenderForLanguage({
  required String selectedLanguage,
  required Map<String, ComputedSenderInfo> computedSenders,
}) {
  final options = moduleOptionsForLanguage(
    selectedLanguage: selectedLanguage,
    computedSenders: computedSenders,
  );
  if (options.isEmpty) return null;
  return options.first.rawSender;
}

/// First Normal (`asr`, then `mt`) [rawSender] for [language] with shareable
/// bucket content, or null if none.
String? normalRawSenderForShare({
  required String language,
  required Map<String, ComputedSenderInfo> computedSenders,
  required SessionTranscriptState transcript,
}) {
  final options = moduleOptionsForLanguage(
    selectedLanguage: language,
    computedSenders: computedSenders,
  );
  for (final option in options) {
    final type = computedSenders[option.rawSender]?.type;
    if (type != 'asr' && type != 'mt') continue;
    final bucket = transcript.buckets[option.bucketKey];
    if (bucket != null && transcriptBucketHasDisplayableContent(bucket)) {
      return option.rawSender;
    }
  }
  return null;
}

String? activeBucketKeyForSelection({
  required String selectedLanguage,
  required String selectedRawSender,
  required Map<String, ComputedSenderInfo> computedSenders,
}) {
  if (selectedRawSender.isEmpty) return null;
  final info = computedSenders[selectedRawSender];
  if (info == null || info.language != selectedLanguage) return null;
  return lectureBucketKey(
    languageDisplayName: info.language,
    rawSender: selectedRawSender,
  );
}

int _compareSenderRoutes(ComputedSenderInfo a, ComputedSenderInfo b) {
  final typeCmp = (_moduleTypeOrder[a.type] ?? 99).compareTo(
    _moduleTypeOrder[b.type] ?? 99,
  );
  if (typeCmp != 0) return typeCmp;
  return a.percent.compareTo(b.percent);
}

const kTranscriptLanguage = 'Transcript';

String defaultLanguageFromComputedSenders(
  Map<String, ComputedSenderInfo> computedSenders,
  List<String> activeLanguages,
) {
  if (activeLanguages.contains(kTranscriptLanguage)) return kTranscriptLanguage;
  final asr = computedSenders['asr:0'];
  if (asr != null && asr.language.isNotEmpty) return asr.language;
  if (activeLanguages.isNotEmpty) return activeLanguages.first;
  return kTranscriptLanguage;
}
