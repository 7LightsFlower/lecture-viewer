import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('toJson/fromJson round-trip', () {
    const info = ComputedSenderInfo(
      language: 'English',
      type: 'mt',
      percent: 0,
      langCode: 'en',
    );
    expect(ComputedSenderInfo.fromJson(info.toJson()), info);
  });
}
