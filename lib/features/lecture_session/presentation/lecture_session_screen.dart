import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_controls.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_qr_dialog.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_tts_app_bar_button.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_transcript_pane.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_pop_result.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/save_lecture_on_exit.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/session_unavailable_dialog.dart';

class LectureSessionScreen extends ConsumerStatefulWidget {
  const LectureSessionScreen({
    required this.scope,
    super.key,
  });

  final LectureSessionScope scope;

  @override
  ConsumerState<LectureSessionScreen> createState() =>
      _LectureSessionScreenState();
}

class _LectureSessionScreenState extends ConsumerState<LectureSessionScreen> {
  bool _sessionEndDialogShown = false;
  bool _serverErrorDialogShown = false;
  bool _skipSavePromptOnPop = false;
  bool _controlsExpanded = false;

  LectureSessionScope get scope => widget.scope;
  String get linkRecord => scope.linkRecord;

  Future<void> _popToHome({required bool skipSavePrompt}) async {
    _skipSavePromptOnPop = skipSavePrompt;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showSessionEndedDialog() async {
    if (_sessionEndDialogShown || !mounted) return;
    _sessionEndDialogShown = true;
    await showSessionUnavailableDialog(context);
    if (!mounted) return;
    await _popToHome(skipSavePrompt: true);
  }

  Future<void> _showServerErrorDialog() async {
    if (_serverErrorDialogShown || !mounted) return;
    _serverErrorDialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Server error'),
        content: const Text(
          'The server encountered an error. Please try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _skipSavePromptOnPop = true;
    Navigator.of(context).pop(LectureSessionPopResult.retryJoin);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      lectureSessionProvider(scope).select((s) => s.sessionExitRequested),
      (previous, next) {
        if (next && previous != true) {
          unawaited(_showSessionEndedDialog());
        }
      },
    );

    ref.listen<bool>(
      lectureSessionProvider(scope).select((s) => s.serverErrorRetryRequested),
      (previous, next) {
        if (next && previous != true) {
          unawaited(_showServerErrorDialog());
        }
      },
    );

    final sessionId = ref.watch(
      lectureSessionProvider(scope).select((s) => s.sessionId),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await handleLectureSessionExit(
          context,
          ref,
          linkRecord: linkRecord,
          sessionId: sessionId,
          joinUrl: scope.joinUrl,
          skipSavePrompt: _skipSavePromptOnPop,
        );
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(sessionId),
          actions: [
            if (scope.joinUrl case final joinUrl?)
              IconButton(
                tooltip: 'Show join QR',
                icon: const Icon(Icons.qr_code_2),
                onPressed: () => showLectureSessionQrDialog(
                  context: context,
                  joinUrl: joinUrl,
                ),
              ),
            LectureTtsAppBarButton(scope: scope),
            IconButton(
              tooltip: _controlsExpanded ? 'Collapse controls' : 'Expand controls',
              iconSize: 36,
              onPressed: () =>
                  setState(() => _controlsExpanded = !_controlsExpanded),
              icon: Icon(
                _controlsExpanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LectureSessionControls(
              scope: scope,
              expanded: _controlsExpanded,
            ),
            _LectureSessionErrorBanner(scope: scope),
            Expanded(
              child: _LectureSessionTranscriptBody(scope: scope),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectureSessionErrorBanner extends ConsumerWidget {
  const _LectureSessionErrorBanner({required this.scope});

  final LectureSessionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorMessage = ref.watch(
      lectureSessionProvider(scope).select((s) => s.errorMessage),
    );
    if (errorMessage == null) return const SizedBox.shrink();

    final notifier = ref.read(lectureSessionProvider(scope).notifier);
    return MaterialBanner(
      content: Text(errorMessage),
      actions: [
        TextButton(
          onPressed: () => notifier.retryConnect(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _LectureSessionTranscriptBody extends ConsumerWidget {
  const _LectureSessionTranscriptBody({required this.scope});

  final LectureSessionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preInfoStatus = ref.watch(
      lectureSessionProvider(scope).select(
        (s) => (
          hasReceivedInfo: s.hasReceivedInfo,
          wsConnected: s.wsPhase == LectureWsPhase.connected,
        ),
      ),
    );
    if (!preInfoStatus.hasReceivedInfo) {
      return Center(
        child: Text(
          preInfoStatus.wsConnected
              ? 'Waiting for speech'
              : 'Loading session…',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final transcriptSelection = ref.watch(
      lectureSessionProvider(scope).select((s) {
        final bucketKey = activeBucketKeyForSelection(
          selectedLanguage: s.selectedLanguage,
          selectedRawSender: s.selectedRawSender,
          computedSenders: s.computedSenders,
        );
        final activeBucket = bucketKey == null
            ? TranscriptBucket.initial()
            : s.transcript.buckets[bucketKey] ?? TranscriptBucket.initial();
        return (bucketKey: bucketKey, activeBucket: activeBucket);
      }),
    );
    final activeBucket = transcriptSelection.activeBucket;
    final selection = ref.watch(
      lectureSessionProvider(scope).select(
        (s) => (
          hasModule: s.selectedRawSender.isNotEmpty,
          moduleLabel: s.computedSenders[s.selectedRawSender] == null
              ? null
              : moduleDisplayLabel(s.computedSenders[s.selectedRawSender]!),
        ),
      ),
    );
    final textScale = ref.watch(appSettingsProvider.select((s) => s.textScale));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LectureTranscriptPane(
        textScaler: TextScaler.linear(textScale),
        activeBucket: activeBucket,
        followScopeKey: transcriptSelection.bucketKey,
        hasModuleSelection: selection.hasModule,
        moduleLabel: selection.moduleLabel,
      ),
    );
  }
}
