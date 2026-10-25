import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

class LectureSessionControls extends ConsumerWidget {
  const LectureSessionControls({
    required this.scope,
    required this.expanded,
    super.key,
  });

  final LectureSessionScope scope;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = ref.watch(
      lectureSessionProvider(scope).select(
        (s) => (
          activeLanguages: s.activeLanguages,
          selectedLanguage: s.selectedLanguage,
          selectedRawSender: s.selectedRawSender,
          computedSenders: s.computedSenders,
          moduleOptions: moduleOptionsForLanguage(
            selectedLanguage: s.selectedLanguage,
            computedSenders: s.computedSenders,
          ),
        ),
      ),
    );
    final notifier = ref.read(lectureSessionProvider(scope).notifier);
    final tts = ref.watch(lectureSessionProvider(scope).select((s) => s.tts));
    final ttsCollapsedSliderVisible = ref.watch(
      lectureSessionProvider(scope).select((s) => s.ttsCollapsedSliderVisible),
    );

    final moduleValues = controls.moduleOptions.map((o) => o.rawSender).toSet();
    final selectedModule = moduleValues.contains(controls.selectedRawSender)
        ? controls.selectedRawSender
        : null;
    final voiceAvailability = ttsVoiceAvailability(
      selectedLanguage: controls.selectedLanguage,
      computedSenders: controls.computedSenders,
    );

    final collapsedSeekRow =
        !expanded &&
        voiceAvailability == TtsVoiceAvailability.available &&
        ttsCollapsedSliderVisible;

    if (!expanded && !collapsedSeekRow) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 8, expanded ? 8 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ttsCollapsedSliderVisible)
              TranslationTtsTransport(
                showPlayButton: false,
                snapshot: tts,
                onPlayPause: notifier.ttsPlayPause,
                onSeekEnd: notifier.ttsSeekEnd,
              ),
            if (expanded) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue:
                    controls.activeLanguages.contains(controls.selectedLanguage)
                    ? controls.selectedLanguage
                    : null,
                decoration: const InputDecoration(labelText: 'Language'),
                items: controls.activeLanguages
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(l, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => controls.activeLanguages
                    .map(
                      (l) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: controls.activeLanguages.isEmpty
                    ? null
                    : (v) {
                        if (v == null) return;
                        notifier.setLanguage(v);
                      },
              ),
              if (controls.moduleOptions.length > 1) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedModule,
                  decoration: const InputDecoration(
                    labelText: 'Shortening mode',
                  ),
                  items: controls.moduleOptions
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.rawSender,
                          child: Text(o.label, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) => controls.moduleOptions
                      .map(
                        (o) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            o.label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.setModule(v);
                  },
                ),
              ],
              Row(
                children: [
                  IconButton(
                    tooltip: 'Smaller text',
                    onPressed: () => ref
                        .read(appSettingsProvider.notifier)
                        .decreaseTextScale(),
                    icon: const Icon(Icons.text_decrease),
                  ),
                  IconButton(
                    tooltip: 'Larger text',
                    onPressed: () => ref
                        .read(appSettingsProvider.notifier)
                        .increaseTextScale(),
                    icon: const Icon(Icons.text_increase),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
