import 'package:flutter/material.dart';

import '../data/transcript_bucket.dart';
import 'translation_result_transcript_view.dart';

/// Distance from [ScrollPosition.maxScrollExtent] treated as "at bottom".
const double kTranscriptFollowBottomThreshold = 48.0;

/// Scrollable transcript that follows the latest text unless the user scrolls up.
class TranslationResultTranscriptFollowView extends StatefulWidget {
  const TranslationResultTranscriptFollowView({
    super.key,
    required this.textScaler,
    required this.activeBucket,
    this.followScopeKey,
    this.scrollToBottomIcon = Icons.keyboard_arrow_down,
    this.viewerSpeakerLayout = false,
    this.highlightedSegmentIds,
  });

  final TextScaler textScaler;
  final TranscriptBucket activeBucket;

  /// When this changes (e.g. language|module bucket key), follow mode resets.
  /// Content updates within the same scope must not re-enable follow.
  final Object? followScopeKey;

  final IconData scrollToBottomIcon;
  final bool viewerSpeakerLayout;

  /// Segments (by `textCompoundId`) to mark, e.g. the text TTS is speaking.
  final Set<String>? highlightedSegmentIds;

  @override
  State<TranslationResultTranscriptFollowView> createState() =>
      _TranslationResultTranscriptFollowViewState();
}

class _TranslationResultTranscriptFollowViewState
    extends State<TranslationResultTranscriptFollowView> {
  final ScrollController _scrollController = ScrollController();
  bool _followLatest = true;
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollPositionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottomIfFollowing();
      _syncFabVisibility();
    });
  }

  @override
  void didUpdateWidget(TranslationResultTranscriptFollowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followScopeKey != oldWidget.followScopeKey) {
      _followLatest = true;
      _showFab = false;
    }
    if (_followLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom();
        _syncFabVisibility();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom(ScrollPosition position) {
    if (!position.hasContentDimensions) return true;
    if (position.maxScrollExtent <= 0) return true;
    return position.maxScrollExtent - position.pixels <=
        kTranscriptFollowBottomThreshold;
  }

  bool _canScroll(ScrollPosition position) {
    if (!position.hasContentDimensions) return false;
    return position.maxScrollExtent > kTranscriptFollowBottomThreshold;
  }

  void _syncFabVisibility() {
    if (!_scrollController.hasClients) {
      if (_showFab) setState(() => _showFab = false);
      return;
    }
    final position = _scrollController.position;
    final nextShowFab = !_followLatest && _canScroll(position);
    if (nextShowFab != _showFab) {
      setState(() => _showFab = nextShowFab);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    _scrollController.jumpTo(position.maxScrollExtent);
  }

  void _scrollToBottomIfFollowing() {
    if (!_followLatest) return;
    _scrollToBottom();
  }

  void _applyScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearBottom = _isNearBottom(position);

    if (nearBottom) {
      if (!_followLatest || _showFab) {
        setState(() {
          _followLatest = true;
          _showFab = false;
        });
      }
      return;
    }

    if (_followLatest) {
      setState(() {
        _followLatest = false;
        _showFab = _canScroll(position);
      });
      return;
    }

    _syncFabVisibility();
  }

  void _onScrollPositionChanged() {
    _applyScrollPosition();
  }

  void _onFabPressed() {
    setState(() {
      _followLatest = true;
      _showFab = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TranslationResultTranscriptView(
          textScaler: widget.textScaler,
          activeBucket: widget.activeBucket,
          scrollController: _scrollController,
          viewerSpeakerLayout: widget.viewerSpeakerLayout,
          highlightedSegmentIds: widget.highlightedSegmentIds,
        ),
        if (_showFab)
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              onPressed: _onFabPressed,
              tooltip: 'Scroll to latest',
              child: Icon(widget.scrollToBottomIcon),
            ),
          ),
      ],
    );
  }
}
