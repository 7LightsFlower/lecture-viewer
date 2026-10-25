import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_bucket_key.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';

TranscriptBucket _bucketWithText(String text) {
  return TranscriptBucket(
    paragraphs: [
      TranscriptParagraph(
        segments: [TranscriptSegment(text: text, textCompoundId: 'a')],
      ),
    ],
    speakerLabelByCompoundId: const {},
  );
}

SessionTranscriptState _transcriptFor({
  required String language,
  required String rawSender,
  required String text,
}) {
  return SessionTranscriptState(
    buckets: {
      lectureBucketKey(
        languageDisplayName: language,
        rawSender: rawSender,
      ): _bucketWithText(text),
    },
  );
}

void main() {
  final senders = {
    'mt:0': const ComputedSenderInfo(
      language: 'English',
      type: 'mt',
      percent: 0,
      langCode: 'en',
    ),
    'postproduction:70_en': const ComputedSenderInfo(
      language: 'English',
      type: 'postproduction',
      percent: 70,
      langCode: 'en',
    ),
    'postproduction:90_en': const ComputedSenderInfo(
      language: 'English',
      type: 'postproduction',
      percent: 90,
      langCode: 'en',
    ),
    'asr:0': const ComputedSenderInfo(
      language: 'Transcript',
      type: 'asr',
      percent: 0,
    ),
  };

  test('moduleDisplayLabel maps asr, mt, and postproduction', () {
    expect(
      moduleDisplayLabel(
        const ComputedSenderInfo(
          language: 'Transcript',
          type: 'asr',
          percent: 0,
        ),
      ),
      'Normal',
    );
    expect(
      moduleDisplayLabel(
        const ComputedSenderInfo(
          language: 'English',
          type: 'mt',
          percent: 0,
          langCode: 'en',
        ),
      ),
      'Normal',
    );
    expect(
      moduleDisplayLabel(
        const ComputedSenderInfo(
          language: 'English',
          type: 'postproduction',
          percent: 70,
          langCode: 'en',
        ),
      ),
      'Shortening 70%',
    );
  });

  test('bucketKeysForRawSender matches raw sender entry', () {
    expect(
      bucketKeysForRawSender(
        rawSender: 'postproduction:70_en',
        computedSenders: senders,
      ).toList(),
      ['English|postproduction:70_en'],
    );
  });

  test('moduleOptionsForLanguage lists all configured modules', () {
    final options = moduleOptionsForLanguage(
      selectedLanguage: 'English',
      computedSenders: senders,
    );

    expect(options.map((o) => o.rawSender).toList(), [
      'mt:0',
      'postproduction:70_en',
      'postproduction:90_en',
    ]);
    expect(options.first.label, 'Normal');
  });

  test('moduleOptionsForLanguage excludes unsupported module types', () {
    final sendersWithUnsupported = {
      ...senders,
      'textstructurer:0_en': const ComputedSenderInfo(
        language: 'English',
        type: 'textstructurer',
        percent: 0,
        langCode: 'en',
      ),
      'summarizer:0_en': const ComputedSenderInfo(
        language: 'English',
        type: 'summarizer',
        percent: 0,
        langCode: 'en',
      ),
    };

    final options = moduleOptionsForLanguage(
      selectedLanguage: 'English',
      computedSenders: sendersWithUnsupported,
    );

    expect(options.map((o) => o.rawSender), [
      'mt:0',
      'postproduction:70_en',
      'postproduction:90_en',
    ]);
  });

  test('bucketKeysForRawSender ignores unsupported module types', () {
    final unsupportedSenders = {
      'textstructurer:0_en': const ComputedSenderInfo(
        language: 'English',
        type: 'textstructurer',
        percent: 0,
        langCode: 'en',
      ),
      'summarizer:0_en': const ComputedSenderInfo(
        language: 'English',
        type: 'summarizer',
        percent: 0,
        langCode: 'en',
      ),
    };

    for (final rawSender in unsupportedSenders.keys) {
      expect(
        bucketKeysForRawSender(
          rawSender: rawSender,
          computedSenders: unsupportedSenders,
        ).toList(),
        isEmpty,
      );
    }
  });

  test('moduleOptionsForLanguage orders by module type then percent', () {
    final options = moduleOptionsForLanguage(
      selectedLanguage: 'English',
      computedSenders: senders,
    );

    expect(options.map((o) => o.rawSender).toList(), [
      'mt:0',
      'postproduction:70_en',
      'postproduction:90_en',
    ]);
    expect(options[1].label, 'Shortening 70%');
  });

  test('activeBucketKeyForSelection resolves selected module', () {
    expect(
      activeBucketKeyForSelection(
        selectedLanguage: 'English',
        selectedRawSender: 'postproduction:70_en',
        computedSenders: senders,
      ),
      'English|postproduction:70_en',
    );
  });

  test('defaultLanguageFromComputedSenders prefers Transcript when available', () {
    expect(
      defaultLanguageFromComputedSenders(
        {
          'asr:0': const ComputedSenderInfo(
            language: 'Arabic',
            type: 'asr',
            percent: 0,
          ),
        },
        const ['Arabic', 'Transcript', 'English'],
      ),
      'Transcript',
    );
  });

  test('defaultRawSenderForLanguage picks first configured module', () {
    expect(
      defaultRawSenderForLanguage(
        selectedLanguage: 'English',
        computedSenders: senders,
      ),
      'mt:0',
    );
  });

  test('normalRawSenderForShare prefers asr over mt when both have content', () {
    const language = 'English';
    final senders = {
      'asr:0': const ComputedSenderInfo(
        language: language,
        type: 'asr',
        percent: 0,
      ),
      'mt:1_en': const ComputedSenderInfo(
        language: language,
        type: 'mt',
        percent: 0,
        langCode: 'en',
      ),
    };
    final transcript = SessionTranscriptState(
      buckets: {
        lectureBucketKey(
          languageDisplayName: language,
          rawSender: 'asr:0',
        ): _bucketWithText('source'),
        lectureBucketKey(
          languageDisplayName: language,
          rawSender: 'mt:1_en',
        ): _bucketWithText('translated'),
      },
    );

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: transcript,
      ),
      'asr:0',
    );
  });

  test('normalRawSenderForShare uses mt when asr has no content', () {
    const language = 'English';
    final senders = {
      'asr:0': const ComputedSenderInfo(
        language: language,
        type: 'asr',
        percent: 0,
      ),
      'mt:1_en': const ComputedSenderInfo(
        language: language,
        type: 'mt',
        percent: 0,
        langCode: 'en',
      ),
    };
    final transcript = _transcriptFor(
      language: language,
      rawSender: 'mt:1_en',
      text: 'translated only',
    );

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: transcript,
      ),
      'mt:1_en',
    );
  });

  test('normalRawSenderForShare ignores postproduction-only content', () {
    const language = 'English';
    final senders = {
      'postproduction:70_en': const ComputedSenderInfo(
        language: language,
        type: 'postproduction',
        percent: 70,
        langCode: 'en',
      ),
    };
    final transcript = _transcriptFor(
      language: language,
      rawSender: 'postproduction:70_en',
      text: 'shortened',
    );

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: transcript,
      ),
      isNull,
    );
  });

  test('normalRawSenderForShare returns null when no normal content', () {
    const language = 'English';
    final senders = {
      'mt:1_en': const ComputedSenderInfo(
        language: language,
        type: 'mt',
        percent: 0,
      ),
    };

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: const SessionTranscriptState(buckets: {}),
      ),
      isNull,
    );
  });
}
