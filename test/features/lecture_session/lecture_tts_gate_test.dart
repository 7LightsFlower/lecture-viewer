import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_gate.dart';

void main() {
  test('shouldEnqueue when language matches selected', () {
    expect(shouldEnqueueTtsForLanguage('German', 'German'), isTrue);
    expect(shouldEnqueueTtsForLanguage('English', 'German'), isFalse);
  });
}
