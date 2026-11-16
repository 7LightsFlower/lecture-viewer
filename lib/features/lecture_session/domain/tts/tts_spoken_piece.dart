import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lecture_common/lecture_common.dart';

/// One TTS audio chunk and the text it speaks.
@immutable
class TtsSpokenPiece {
  const TtsSpokenPiece({
    required this.key,
    required this.textSender,
    required this.text,
    this.minId,
    this.maxId,
  });

  /// Builds the piece for [event], or null when KIT sent no text or ids.
  static TtsSpokenPiece? fromEvent(TtsPcmEvent event) {
    final text = event.text?.trim() ?? '';
    if (text.isEmpty && event.maxMessageId == null) return null;
    return TtsSpokenPiece(
      key: '${event.rawSender}|${event.index}|${event.maxMessageId}',
      textSender: textSenderForTts(event.rawSender),
      text: text,
      minId: event.minMessageId ?? event.maxMessageId,
      maxId: event.maxMessageId,
    );
  }

  final String key;

  /// The text stream it reads (`mt:3_de` for `tts:3_de`).
  final String textSender;

  /// What it says.
  final String text;

  /// KIT message ids of [textSender] it reads.
  final int? minId;
  final int? maxId;

  TtsSpokenPiece withMinId(int? minId) => TtsSpokenPiece(
        key: key,
        textSender: textSender,
        text: text,
        minId: minId,
        maxId: maxId,
      );

  bool speaksMessageId(int id) {
    final lo = minId;
    if (lo == null) return false;
    return id >= lo && id <= (maxId ?? lo);
  }
}

/// `tts:N` speaks the output of `mt:N` (same as KIT's page / LT_ClientApp).
String textSenderForTts(String ttsSender) =>
    ttsSender.startsWith('tts') ? ttsSender.replaceFirst('tts', 'mt') : ttsSender;

/// `rawSender\u001ftextId` → (rawSender, KIT message id).
({String rawSender, int? messageId}) _parseCompoundId(String compoundId) {
  final sep = compoundId.indexOf('\u001f');
  if (sep < 0) return (rawSender: '', messageId: null);
  final textId = compoundId.substring(sep + 1);
  return (
    rawSender: compoundId.substring(0, sep),
    messageId: int.tryParse(textId.split('_').first),
  );
}

const _matchWindow = 60;
const _recentWindow = 600;

final RegExp _wordRe = RegExp(r'[\p{L}\p{N}]+', unicode: true);

Set<String> _words(String text) =>
    {for (final m in _wordRe.allMatches(text.toLowerCase())) m.group(0)!};

/// Segments of [bucket] (by `textCompoundId`) that [piece] speaks.
///
/// Port of LT_ClientApp's `spokenSpanKeys`: matches the spoken text with the
/// segments' text, because ids alone miss text that was corrected or split
/// differently after the audio was made. The message ids only decide which
/// place is meant when the same words occur more than once. Works for any
/// module of the language; ids are used only on the stream TTS reads.
Set<String> spokenSegmentIds(TranscriptBucket bucket, TtsSpokenPiece piece) {
  final all = <TranscriptSegment>[
    for (final p in bucket.paragraphs) ...p.segments,
  ];
  if (all.isEmpty) return const {};

  final allAnchors = <int>[];
  for (var i = 0; i < all.length; i++) {
    final parsed = _parseCompoundId(all[i].textCompoundId);
    final id = parsed.messageId;
    if (parsed.rawSender == piece.textSender &&
        id != null &&
        piece.speaksMessageId(id)) {
      allAnchors.add(i);
    }
  }

  // Runs on every live update while audio plays: only compare text near the
  // ids (or, without ids, in the most recent part of a long lecture).
  final from = math.max(
    0,
    allAnchors.isNotEmpty
        ? allAnchors.first - _matchWindow
        : all.length - _recentWindow,
  );
  final to = allAnchors.isNotEmpty
      ? math.min(all.length, allAnchors.last + _matchWindow + 1)
      : all.length;
  final segments = all.sublist(from, to);
  final anchors = [for (final a in allAnchors) a - from];

  final spoken = _words(piece.text);
  if (spoken.isEmpty) {
    return {for (final i in anchors) segments[i].textCompoundId};
  }

  // Segments whose words are (mostly) in the spoken text.
  final hit = List<bool>.filled(segments.length, false);
  final score = List<int>.filled(segments.length, 0);
  final hasWords = List<bool>.filled(segments.length, false);
  for (var i = 0; i < segments.length; i++) {
    final w = _words(segments[i].text);
    if (w.isEmpty) continue;
    hasWords[i] = true;
    final found = w.where(spoken.contains).length;
    score[i] = found;
    hit[i] = found / w.length >= 0.6;
  }

  // Runs of neighbouring matching segments; pick the best one.
  final runs = <List<int>>[];
  for (var i = 0; i < segments.length; i++) {
    if (!hit[i]) continue;
    if (runs.isNotEmpty) {
      // Neighbour if only word-less segments lie in between.
      var j = runs.last.last + 1;
      while (j < i && !hasWords[j]) {
        j++;
      }
      if (j == i) {
        runs.last.add(i);
        continue;
      }
    }
    runs.add([i]);
  }
  if (runs.isEmpty) {
    return {for (final i in anchors) segments[i].textCompoundId};
  }

  int runScore(List<int> r) => r.fold(0, (a, i) => a + score[i]);
  int distance(List<int> r) {
    if (anchors.isEmpty) return 0;
    var best = 1 << 30;
    for (final a in anchors) {
      final d = a < r.first ? r.first - a : (a > r.last ? a - r.last : 0);
      if (d < best) best = d;
    }
    return best;
  }

  var best = runs.first;
  for (final r in runs.skip(1)) {
    final dr = distance(r), db = distance(best);
    // Closest to KIT's ids first, then most words; later wins a tie (live).
    if (dr < db || (dr == db && runScore(r) >= runScore(best))) best = r;
  }
  return {for (final i in best) segments[i].textCompoundId};
}
