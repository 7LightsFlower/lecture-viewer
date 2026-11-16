import 'dart:convert';
import 'dart:math' as math;

import 'public_lt_api.dart';

/// Converts raw KIT Lecture Translator messages into the JSON envelopes the
/// backend's `/mobile/ws/lecture-session` socket would have sent, so
/// `parseLectureInbound` and the session notifier stay untouched.
///
/// Ported (simplified) from `backend/.../funcs/sent_text_to_client.ts`:
/// - `message_id` padded to 4 digits as `textId`, `unstable` → `!isFinal`
/// - paragraph line-breaking after ~120 stable chars at sentence end
///   (forced at 2000), producing `<id>_0` / `<id>_1` split parts
/// - speaker name from `speakerName` (`x:unk-3` → `Unknown 3`), shown when
///   the speaker changes
/// - TTS chunks → `raw_pcm` envelopes with a public `/webapi` URL
///
/// Not ported: speaker-diarization refinement (`refined` cluster updates),
/// music-note paragraph boundaries, meeting language overrides, and text
/// edits (those live in the backend's database).
class PublicLtMessageAdapter {
  PublicLtMessageAdapter({
    required this.apiOrigin,
    required this.sessionId,
    required Map<String, PublicLtSender> senders,
  }) : _senders = Map.unmodifiable(senders);

  final String apiOrigin;
  final String sessionId;
  final Map<String, PublicLtSender> _senders;
  final Map<String, _SenderState> _state = {};

  static const _textStreamPrefixes = ['asr', 'mt', 'postproduction'];
  static const _breakChars = {'.', '。', '!', '?', '！', '？'};
  static const _punctuationBreakThreshold = 120;
  static const _forceBreakThreshold = 2000;

  Map<String, PublicLtSender> get senders => _senders;

  /// `info` envelope with languages and sender metadata.
  String infoEnvelope() {
    final languages = <String>[];
    for (final s in _senders.values) {
      if (s.language.isNotEmpty && !languages.contains(s.language)) {
        languages.add(s.language);
      }
    }
    return _envelope(
      objectType: 'info',
      message: 'connected',
      data: {
        'computedSenders': {
          for (final e in _senders.entries) e.key: e.value.toJson(),
        },
        'sessionID': sessionId,
        'activeLanguages': languages,
      },
    );
  }

  /// Envelope the notifier treats as "session closed".
  static String sessionEndEnvelope(String reason) => _envelope(
        objectType: 'info',
        message: '',
        data: {'status': 'session_end', 'reason': reason},
      );

  /// Envelope the notifier treats as a server error (offers retry).
  static String serverErrorEnvelope(String reason) => jsonEncode({
        'message': reason,
        'status': 500,
        'data': {'status': 'error'},
        'objectType': 'info',
      });

  /// Converts one raw LT message (SSE `data` or history entry).
  List<String> adapt(Map<String, dynamic> raw) {
    final controll = raw['controll'];
    if (controll != null) {
      if ('$controll' == 'END') {
        return [sessionEndEnvelope('lt_controll_end')];
      }
      return const [];
    }

    final rawSender = raw['sender']?.toString() ?? '';
    if (rawSender.isEmpty) return const [];
    final info = _senders[rawSender];
    final seq = raw['seq']?.toString() ?? '';
    if (seq == 'TTS-finish') return const [];

    if (info?.type == 'tts' || rawSender.startsWith('tts:')) {
      final pcm = _ttsEnvelope(raw, rawSender, info);
      return pcm == null ? const [] : [pcm];
    }

    final texts = _textItems(raw, rawSender, info, seq);
    if (texts.isEmpty) return const [];
    return [
      _envelope(objectType: 'texts', message: '', data: {'texts': texts}),
    ];
  }

  /// Converts previously sent messages (from `get_previous_messages`) into
  /// a few large `texts` envelopes. TTS chunks and control messages are
  /// skipped so joining late doesn't queue up all past audio.
  List<String> adaptHistory(
    List<Map<String, dynamic>> messages, {
    int chunkSize = 300,
  }) {
    final sorted = [...messages]..sort(compareHistory);
    final texts = <Map<String, dynamic>>[];
    for (final raw in sorted) {
      if (raw['controll'] != null) continue;
      final rawSender = raw['sender']?.toString() ?? '';
      if (rawSender.isEmpty || rawSender.startsWith('tts:')) continue;
      final info = _senders[rawSender];
      if (info?.type == 'tts') continue;
      final seq = raw['seq']?.toString() ?? '';
      if (seq == 'TTS-finish') continue;
      texts.addAll(_textItems(raw, rawSender, info, seq));
    }
    return [
      for (var i = 0; i < texts.length; i += chunkSize)
        _envelope(
          objectType: 'texts',
          message: '',
          data: {'texts': texts.skip(i).take(chunkSize).toList()},
        ),
    ];
  }

  // --- TTS -----------------------------------------------------------------

  String? _ttsEnvelope(
    Map<String, dynamic> raw,
    String rawSender,
    PublicLtSender? info,
  ) {
    final url = publicTtsUrl(raw['b64_enc_pcm_s16le']?.toString());
    if (url == null) return null;
    return _envelope(
      objectType: 'raw_pcm',
      message: '',
      data: {
        'type': 'chunk-info',
        'index': int.tryParse('${raw['message_id']}'),
        'duration': raw['length'],
        'language': info?.language ?? rawSender,
        'rawSender': rawSender,
        'senderDetail': info?.toJson(),
        'url': url,
        // What the chunk says, for highlighting it in the transcript.
        if ((raw['text'] ?? '').toString().trim().isNotEmpty)
          'text': raw['text'].toString(),
        if (raw['min_message_id'] != null)
          'minMessageId': int.tryParse('${raw['min_message_id']}'),
        if (raw['max_message_id'] != null)
          'maxMessageId': int.tryParse('${raw['max_message_id']}'),
      },
    );
  }

  /// Maps `b64_enc_pcm_s16le` to something the TTS player can fetch.
  /// A reference (`Data/<session>/<n>`, `/ltapi/stream/data?name=...`)
  /// becomes its public `/webapi` URL, without login (like KIT's page and
  /// LT_ClientApp). Inline base64 PCM becomes a `data:` URL.
  String? publicTtsUrl(String? ref) {
    ref = ref?.trim();
    if (ref == null || ref.isEmpty) return null;
    final base = apiOrigin.replaceAll(RegExp(r'/+$'), '');
    if (ref.startsWith('Data/') && ref.length < 300) {
      return '$base/webapi/stream/data?name=$ref';
    }
    if (ref.startsWith('/ltapi/')) {
      return '$base/webapi/${ref.substring('/ltapi/'.length)}';
    }
    if (ref.startsWith('/')) return '$base$ref';
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      final uri = Uri.parse(ref.replaceFirst('/ltapi/', '/webapi/'));
      return uri.replace(userInfo: '').toString();
    }
    // Inline base64 PCM (base64 has no ? . : & _ - characters).
    if (!RegExp(r'[?.:&_\-\s]').hasMatch(ref)) {
      return 'data:audio/pcm;base64,$ref';
    }
    return null;
  }

  // --- Texts ---------------------------------------------------------------

  List<Map<String, dynamic>> _textItems(
    Map<String, dynamic> raw,
    String rawSender,
    PublicLtSender? info,
    String seq,
  ) {
    final unstable = raw['unstable'] == true;
    final speakerRaw = raw['speakerName']?.toString() ?? '';
    var speakerName = speakerRaw.split(':').last;
    if (speakerName.contains('unk')) {
      speakerName = speakerName.replaceFirst('unk-', 'Unknown ');
    }

    final state = _state.putIfAbsent(
      rawSender,
      () => _SenderState(speaker: speakerRaw, speakerName: speakerName),
    );

    var text = seq;
    final segments = _applyLineBreaking(state, rawSender, unstable, text);
    if (segments != null) {
      text = segments.map((s) => s.text).join(' ');
    }
    _updateSpeaker(state, unstable, seq, speakerRaw, speakerName);

    if (text.isNotEmpty && !text.startsWith(' ')) text = ' $text';
    if (segments != null &&
        segments.first.text.isNotEmpty &&
        !segments.first.text.startsWith(' ')) {
      segments[0] = (
        text: ' ${segments.first.text}',
        isEndParagraph: segments.first.isEndParagraph,
      );
    }

    final language = info?.language ?? rawSender;
    if (language.toLowerCase().contains('audio')) return const [];

    final textId = padTextId(raw['message_id']);
    Map<String, dynamic> item(String t, String id, bool? endParagraph) => {
          'text': t,
          'isFinal': !unstable,
          'textId': id,
          'etime': _seconds(raw['end']) * 1000,
          'stime': _seconds(raw['start']) * 1000,
          'sender': language,
          'rawSender': rawSender,
          'senderDetail': {
            ...?info?.toJson(),
            'speakerName': state.speakerName,
            'speaker': state.speaker,
            'isShowSpeakerName': state.isShowSpeakerName,
            'beforeSpeaker': state.beforeSpeaker,
          },
          'isEndParagraph': ?endParagraph,
        };

    if (segments == null) return [item(text, textId, null)];
    return [
      for (var i = 0; i < segments.length; i++)
        item(
          i > 0 ? segments[i].text.trimLeft() : segments[i].text,
          '${textId}_$i',
          segments[i].isEndParagraph,
        ),
    ];
  }

  List<({String text, bool isEndParagraph})>? _applyLineBreaking(
    _SenderState state,
    String rawSender,
    bool unstable,
    String text,
  ) {
    if (unstable || !_textStreamPrefixes.any(rawSender.contains)) return null;

    final lengthBefore = state.stableLengthCount;
    state.stableLengthCount = lengthBefore + text.length;

    if (state.stableLengthCount > _punctuationBreakThreshold) {
      for (var i = 0; i < text.length; i++) {
        final atBoundary = i + 1 == text.length || text[i + 1] == ' ';
        if (_breakChars.contains(text[i]) && atBoundary) {
          final part1 = text.substring(0, i + 1);
          final part2 = text.substring(i + 1).trimLeft();
          state.stableLengthCount = part2.length;
          return [
            (text: part1, isEndParagraph: true),
            (text: part2, isEndParagraph: false),
          ];
        }
      }
    }

    if (state.stableLengthCount > _forceBreakThreshold && text.isNotEmpty) {
      final ideal = math.min(
        math.max(0, _forceBreakThreshold - lengthBefore),
        text.length,
      );
      final before = text.lastIndexOf(' ', ideal);
      final after = text.indexOf(' ', ideal);
      final breakIndex = before != -1 ? before : after;
      if (breakIndex != -1) {
        final part1 = text.substring(0, breakIndex);
        final part2 = text.substring(breakIndex).trimLeft();
        state.stableLengthCount = part2.length;
        return [
          (text: part1, isEndParagraph: true),
          (text: part2, isEndParagraph: false),
        ];
      }
    }
    return null;
  }

  void _updateSpeaker(
    _SenderState state,
    bool unstable,
    String seq,
    String speakerRaw,
    String speakerName,
  ) {
    if (speakerName.isEmpty || unstable || seq.trim().isEmpty) return;
    final previous = state.speaker;
    final changed =
        previous.isNotEmpty && speakerRaw.isNotEmpty && previous != speakerRaw;
    if (changed) {
      state.stableLengthCount = 0;
      state.isShowSpeakerName = true;
    } else {
      state.isShowSpeakerName = false;
    }
    state.beforeSpeaker = previous;
    state.speakerName = speakerName;
    state.speaker = speakerRaw;
  }

  // --- helpers ---------------------------------------------------------------

  /// Backend pads ids to 4 digits (`toSortedTexts`): `2` → `0002`.
  static String padTextId(Object? id) {
    final s = id == null ? '' : '$id';
    return (s.isEmpty ? '0' : s).padLeft(4, '0');
  }

  static num _seconds(Object? v) =>
      v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  static String _envelope({
    required String objectType,
    required String message,
    required Map<String, dynamic> data,
  }) =>
      jsonEncode({
        'message': message,
        'status': 200,
        'data': data,
        'objectType': objectType,
      });

  /// Sort order the backend uses for history replay.
  static int compareHistory(Map<String, dynamic> a, Map<String, dynamic> b) {
    int byNum(String k) => _seconds(a[k]).compareTo(_seconds(b[k]));
    var c = byNum('start');
    if (c != 0) return c;
    c = byNum('end');
    if (c != 0) return c;
    c = _seconds(a['message_id']).compareTo(_seconds(b['message_id']));
    if (c != 0) return c;
    return '${a['sender'] ?? ''}'.compareTo('${b['sender'] ?? ''}');
  }
}

class _SenderState {
  _SenderState({required this.speaker, required this.speakerName});

  int stableLengthCount = 0;
  String speaker;
  String speakerName;
  bool isShowSpeakerName = false;
  String beforeSpeaker = '';
}
