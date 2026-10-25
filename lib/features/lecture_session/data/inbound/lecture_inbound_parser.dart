import 'package:lecture_common/lecture_common.dart';

typedef LectureInboundMessage = SessionInboundMessage;
typedef LectureInboundInfo = SessionInboundInfo;
typedef LectureInboundTexts = SessionInboundTexts;
typedef LectureInboundSessionEnd = SessionInboundSessionEnd;
typedef LectureInboundWsSessionEnd = SessionInboundWsSessionEnd;
typedef LectureInboundServerError = SessionInboundServerError;
typedef LectureInboundTtsPcm = SessionInboundTtsPcm;
typedef LectureInboundIgnored = SessionInboundIgnored;

LectureInboundMessage parseLectureInbound(String raw) =>
    parseSessionInbound(raw, options: SessionInboundParseOptions.viewer);
