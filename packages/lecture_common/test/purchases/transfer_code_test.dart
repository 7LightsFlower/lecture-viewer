import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('generate is 12 alphabet chars formatted as XXXX-XXXX-XXXX', () {
    final code = TransferCode.generate(Random(1));
    expect(code, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    expect(TransferCode.isValid(code), isTrue);
    expect(TransferCode.normalize(code).length, TransferCode.rawLength);
    for (final ch in TransferCode.normalize(code).split('')) {
      expect(TransferCode.alphabet.contains(ch), isTrue);
    }
  });

  test('generate is deterministic with a seeded Random', () {
    expect(TransferCode.generate(Random(42)), TransferCode.generate(Random(42)));
  });

  test('format and normalize strip separators and lowercase', () {
    expect(TransferCode.normalize('ab-cd ef_gh'), 'ABCDEFGH');
    expect(TransferCode.format('abcdefghjkmn'), 'ABCD-EFGH-JKMN');
  });

  test('isValid rejects wrong length and ambiguous alphabet chars', () {
    expect(TransferCode.isValid('ABCD-EFGH-JKMN'), isTrue);
    expect(TransferCode.isValid('ABCD-EFGH-JKM'), isFalse);
    expect(TransferCode.isValid('ABCD-EFGH-JKM0'), isFalse);
    expect(TransferCode.isValid('ABCD-EFGH-JKMO'), isFalse);
    expect(TransferCode.isValid('ABCD-EFGH-JKM1'), isFalse);
    expect(TransferCode.isValid('ABCD-EFGH-JKMI'), isFalse);
    expect(TransferCode.isValid('ABCD-EFGH-JKML'), isFalse);
  });

  test('parseDeeplink accepts matching scheme and valid code', () {
    final uri = Uri.parse('twowayv2://transfer?code=ABCD-EFGH-JKMN');
    expect(
      TransferCode.parseDeeplink(uri, scheme: 'twowayv2'),
      'ABCD-EFGH-JKMN',
    );
  });

  test('parseDeeplink rejects wrong scheme, host, or invalid code', () {
    expect(
      TransferCode.parseDeeplink(
        Uri.parse('other://transfer?code=ABCD-EFGH-JKMN'),
        scheme: 'twowayv2',
      ),
      isNull,
    );
    expect(
      TransferCode.parseDeeplink(
        Uri.parse('twowayv2://share?code=ABCD-EFGH-JKMN'),
        scheme: 'twowayv2',
      ),
      isNull,
    );
    expect(
      TransferCode.parseDeeplink(
        Uri.parse('twowayv2://transfer?code=BAD'),
        scheme: 'twowayv2',
      ),
      isNull,
    );
  });
}
