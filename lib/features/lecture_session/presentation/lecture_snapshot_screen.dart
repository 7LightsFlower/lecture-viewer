import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_record.dart';
import 'package:lecture_viewer_v3/core/providers/api_environment_notifier.dart';
import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_input_factory.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_sheet.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_transcript_pane.dart';

/// Shown on [LectureSnapshotScreen] so users know snapshot scope.
const String kLectureSnapshotScopeNotice =
    'This is data from the last time you joined. It only includes text '
    'received while you were in the session—not the full event transcript.';

class LectureSnapshotScreen extends ConsumerStatefulWidget {
  const LectureSnapshotScreen({
    required this.linkRecord,
    required this.displayName,
    super.key,
  });

  final String linkRecord;
  final String displayName;

  @override
  ConsumerState<LectureSnapshotScreen> createState() =>
      _LectureSnapshotScreenState();
}

class _LectureSnapshotScreenState extends ConsumerState<LectureSnapshotScreen> {
  LectureSnapshotRecord? _record;
  String _selectedLanguage = '';
  String _selectedRawSender = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = await ref.read(lectureSnapshotRepositoryProvider.future);
    final record = await repo.get(widget.linkRecord);
    if (!mounted) return;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved result')),
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _record = record;
      _selectedLanguage = record.selectedLanguage.isNotEmpty
          ? record.selectedLanguage
          : (record.activeLanguages.isNotEmpty
              ? record.activeLanguages.first
              : '');
      _selectedRawSender = record.selectedRawSender;
      _loading = false;
    });
    _syncModuleSelection();
  }

  void _syncModuleSelection() {
    final record = _record;
    if (record == null) return;
    final options = moduleOptionsForLanguage(
      selectedLanguage: _selectedLanguage,
      computedSenders: record.computedSenders,
    );
    if (options.isEmpty) {
      _selectedRawSender = '';
      return;
    }
    if (!options.any((o) => o.rawSender == _selectedRawSender)) {
      _selectedRawSender = options.first.rawSender;
    }
  }

  void _onShare() {
    final record = _record;
    if (record == null) return;
    final httpsOrigin = httpsOriginForLectureHttp(
      environment: ref.read(apiEnvironmentProvider),
      linkRecord: widget.linkRecord,
    );
    showLectureShareSheet(
      context: context,
      input: lectureShareInputFromSnapshot(
        subject: widget.displayName,
        record: record,
        httpsOrigin: httpsOrigin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.displayName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final record = _record!;
    final languages = record.activeLanguages;
    final moduleOptions = moduleOptionsForLanguage(
      selectedLanguage: _selectedLanguage,
      computedSenders: record.computedSenders,
    );
    final bucketKey = activeBucketKeyForSelection(
      selectedLanguage: _selectedLanguage,
      selectedRawSender: _selectedRawSender,
      computedSenders: record.computedSenders,
    );
    final activeBucket = bucketKey == null
        ? TranscriptBucket.initial()
        : record.transcript.buckets[bucketKey] ?? TranscriptBucket.initial();
    final moduleLabel = record.computedSenders[_selectedRawSender] == null
        ? null
        : moduleDisplayLabel(record.computedSenders[_selectedRawSender]!);
    final textScale = ref.watch(appSettingsProvider.select((s) => s.textScale));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _onShare,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _SnapshotScopeNotice(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: languages.contains(_selectedLanguage)
                        ? _selectedLanguage
                        : (languages.isNotEmpty ? languages.first : null),
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      isDense: true,
                    ),
                    items: [
                      for (final lang in languages)
                        DropdownMenuItem(value: lang, child: Text(lang)),
                    ],
                    onChanged: languages.isEmpty
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedLanguage = v;
                              _syncModuleSelection();
                            });
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: moduleOptions.any(
                      (o) => o.rawSender == _selectedRawSender,
                    )
                        ? _selectedRawSender
                        : (moduleOptions.isNotEmpty
                            ? moduleOptions.first.rawSender
                            : null),
                    decoration: const InputDecoration(
                      labelText: 'Module',
                      isDense: true,
                    ),
                    items: [
                      for (final o in moduleOptions)
                        DropdownMenuItem(
                          value: o.rawSender,
                          child: Text(o.label),
                        ),
                    ],
                    onChanged: moduleOptions.isEmpty
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _selectedRawSender = v);
                          },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LectureTranscriptPane(
                textScaler: TextScaler.linear(textScale),
                activeBucket: activeBucket,
                followScopeKey: bucketKey,
                hasModuleSelection: _selectedRawSender.isNotEmpty,
                moduleLabel: moduleLabel,
                liveSession: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotScopeNotice extends StatelessWidget {
  const _SnapshotScopeNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                kLectureSnapshotScopeNotice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
