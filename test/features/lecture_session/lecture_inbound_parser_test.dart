import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/inbound/lecture_inbound_parser.dart';

void main() {
  test('parses language metadata info', () {
    const json = '''
{
  "status": 200,
  "objectType": "info",
  "data": {
    "sessionID": "317374",
    "activeLanguages": ["English", "German"],
    "computedSenders": {
      "asr:0": {
        "language": "Transcript",
        "type": "asr",
        "percent": 0
      },
      "mt:0": {
        "language": "English",
        "type": "mt",
        "percent": 0
      }
    }
  }
}
''';

    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundInfo>());
    final info = message as LectureInboundInfo;
    expect(info.activeLanguages, ['English', 'German']);
    expect(info.computedSenders.length, 2);
    expect(info.sessionId, '317374');
  });

  test('info keeps tts senders for PCM language routing', () {
    const json = '''
{
  "status": 200,
  "objectType": "info",
  "data": {
    "activeLanguages": ["English", "German"],
    "computedSenders": {
      "tts:0": {
        "language": "English",
        "type": "tts",
        "percent": 0
      },
      "mt:0": {
        "language": "English",
        "type": "mt",
        "percent": 0
      }
    }
  }
}
''';
    final message = parseLectureInbound(json);
    final info = message as LectureInboundInfo;
    expect(info.computedSenders.keys, containsAll(['tts:0', 'mt:0']));
    expect(info.computedSenders['tts:0']!.language, 'English');
  });

  test('info omits unsupported module types', () {
    const json = '''
{
  "status": 200,
  "objectType": "info",
  "data": {
    "activeLanguages": ["English"],
    "computedSenders": {
      "mt:0": {
        "language": "English",
        "type": "mt",
        "percent": 0
      },
      "textstructurer:0_en": {
        "language": "English",
        "type": "textstructurer",
        "percent": 0
      },
      "summarizer:0_en": {
        "language": "English",
        "type": "summarizer",
        "percent": 0
      }
    }
  }
}
''';

    final message = parseLectureInbound(json);
    final info = message as LectureInboundInfo;
    expect(info.computedSenders.keys, ['mt:0']);
  });

  test('parses session_end info as LectureInboundWsSessionEnd', () {
    const json = '''
{
  "message": "connected",
  "status": 200,
  "data": {
    "status": "session_end",
    "reason": "session_already_over"
  },
  "objectType": "info"
}
''';

    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundWsSessionEnd>());
    final end = message as LectureInboundWsSessionEnd;
    expect(end.reason, 'session_already_over');
  });

  test('parses session END info without wiping as empty metadata', () {
    const json = '''
{
  "status": 200,
  "objectType": "info",
  "data": {
    "status": "END",
    "audioUrl": "https://example.com/recording.wav"
  }
}
''';

    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundSessionEnd>());
    final end = message as LectureInboundSessionEnd;
    expect(end.audioUrl, 'https://example.com/recording.wav');
  });

  test('parses raw_pcm for tts sender', () {
    const json = '''
{"status":200,"objectType":"raw_pcm","data":{"url":"https://example.com/pcm","rawSender":"tts:1","language":"German","index":3}}
''';
    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundTtsPcm>());
    final pcm = message as LectureInboundTtsPcm;
    expect(pcm.event.url, 'https://example.com/pcm');
    expect(pcm.event.rawSender, 'tts:1');
    expect(pcm.event.languageFromPayload, 'German');
    expect(pcm.event.index, 3);
  });

  test('raw_pcm without url is ignored', () {
    const json =
        '{"status":200,"objectType":"raw_pcm","data":{"rawSender":"tts:0","language":"English"}}';
    expect(parseLectureInbound(json), isA<LectureInboundIgnored>());
  });

  test('raw_pcm with non-tts rawSender is ignored', () {
    const json =
        '{"status":200,"objectType":"raw_pcm","data":{"url":"https://x","rawSender":"mt:0","language":"English"}}';
    expect(parseLectureInbound(json), isA<LectureInboundIgnored>());
  });

  test('parses top-level 500 status string as LectureInboundServerError', () {
    const json = r'''
{"status": "500 - \"<!doctype html>\\n<html lang=en>\\n<title>500 Internal Server Error</title>\\n<h1>Internal Server Error</h1>\\n<p>The server encountered an internal error and was unable to complete your request. Either the server is overloaded or there is an error in the application.</p>\\n\""}
''';

    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundServerError>());
  });

  test('status 200 info is not LectureInboundServerError', () {
    const json = '''
{
  "status": 200,
  "objectType": "info",
  "data": {
    "activeLanguages": ["English"],
    "computedSenders": {
      "mt:0": {"language": "English", "type": "mt", "percent": 0}
    }
  }
}
''';
    expect(parseLectureInbound(json), isA<LectureInboundInfo>());
  });

  test('top-level status 403 string is LectureInboundServerError', () {
    const json = '{"status": "403 Forbidden"}';
    expect(parseLectureInbound(json), isA<LectureInboundServerError>());
  });
}
