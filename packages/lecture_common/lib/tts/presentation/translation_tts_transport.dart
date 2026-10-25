import 'package:flutter/material.dart';

import '../tts_pane_snapshot.dart';
import '../tts_slider_utils.dart';

/// Play/pause + seek + buffered duration for one pane's TTS buffer.
class TranslationTtsTransport extends StatefulWidget {
  const TranslationTtsTransport({
    super.key,
    required this.snapshot,
    required this.onPlayPause,
    required this.onSeekEnd,
    this.onNoBufferPlayTap,
    this.showPlayButton = true,
    this.showProgress = true,
    this.iconCustom,
  });

  final TtsPaneSnapshot snapshot;
  final VoidCallback onPlayPause;
  final void Function(double normalizedPosition) onSeekEnd;

  /// When set, play is tappable even with an empty buffer (e.g. show a snackbar).
  final VoidCallback? onNoBufferPlayTap;

  /// When false, only seek slider and duration are shown (play lives elsewhere).
  final bool showPlayButton;

  /// When false, the seek slider and buffered duration are hidden (play only).
  final bool showProgress;

  /// Overrides the play button's icon widget. Falls back to play/pause icons.
  final Widget? iconCustom;

  static String formatBuffered(double seconds) {
    var s = seconds;
    if (s.isNaN || s.isInfinite || s < 0) s = 0;
    final d = Duration(milliseconds: (s * 1000).round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  State<TranslationTtsTransport> createState() =>
      _TranslationTtsTransportState();
}

class _TranslationTtsTransportState extends State<TranslationTtsTransport> {
  double? _dragNormalized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = widget.snapshot;
    final maxSec = ttsSliderMaxSeconds(snapshot.bufferedDurationSec);
    final hasBuffer = snapshot.bufferedDurationSec > 0;
    final fromState = hasBuffer
        ? (snapshot.playbackPositionSec / maxSec).clamp(0.0, 1.0)
        : 0.0;
    final sliderValue = _dragNormalized ?? fromState;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final maxW = constraints.maxWidth;
        final showSlider = widget.showProgress && maxW >= 96;
        final showDuration = widget.showProgress && maxW >= 152;
        final pending = snapshot.pendingDownloadCount;

        return Row(
          children: [
            if (widget.showPlayButton)
              IconButton(
                tooltip: snapshot.isPlaying ? 'Pause TTS' : 'Play TTS',
                onPressed: hasBuffer
                    ? widget.onPlayPause
                    : widget.onNoBufferPlayTap,
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: widget.iconCustom ??
                    Icon(snapshot.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            if (showSlider)
              Expanded(
                child: Semantics(
                  label: pending > 0
                      ? 'Downloading $pending audio chunks'
                      : null,
                  child: _TtsSliderWithPendingIndicator(
                    value: sliderValue,
                    pendingDownloadCount: pending,
                    showFullPendingLabel: showDuration,
                    onChanged: hasBuffer
                        ? (v) => setState(() => _dragNormalized = v)
                        : null,
                    onChangeEnd: hasBuffer
                        ? (v) {
                            setState(() => _dragNormalized = null);
                            widget.onSeekEnd(v);
                          }
                        : null,
                  ),
                ),
              ),
            if (showDuration)
              Text(
                TranslationTtsTransport.formatBuffered(
                  snapshot.bufferedDurationSec,
                ),
                style: theme.textTheme.labelSmall,
              ),
          ],
        );
      },
    );
  }
}

class _TtsSliderWithPendingIndicator extends StatelessWidget {
  const _TtsSliderWithPendingIndicator({
    required this.value,
    required this.pendingDownloadCount,
    required this.showFullPendingLabel,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final int pendingDownloadCount;
  final bool showFullPendingLabel;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPending = pendingDownloadCount > 0;
    final overlayLabel = hasPending
        ? (showFullPendingLabel
            ? '$pendingDownloadCount pending'
            : '$pendingDownloadCount')
        : null;

    final slider = Slider(
      value: value,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );

    if (!hasPending) {
      return slider;
    }

    final inactiveTrack = scheme.primaryContainer;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onPrimaryContainer,
      fontWeight: FontWeight.w600,
    );

    return SliderTheme(
      data: theme.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: inactiveTrack,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          slider,
          if (overlayLabel != null)
            IgnorePointer(
              child: Text(overlayLabel, style: labelStyle),
            ),
        ],
      ),
    );
  }
}
