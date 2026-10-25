import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/lt2srv_pcm_url.dart';

void main() {
  test('parses id from name=Data/<id>/<suffix>', () {
    const url =
        'https://vais:eiliepo0kiu7Giec@lt2srv.iar.kit.edu/ltapi/stream/data?name=Data/317221/1';
    expect(parseLt2srvSessionIdFromPcmUrl(url), '317221');
  });

  test('returns null when name query missing', () {
    expect(
      parseLt2srvSessionIdFromPcmUrl('https://example.com/ltapi/stream/data'),
      isNull,
    );
  });

  test('returns null when name does not start with Data/', () {
    expect(
      parseLt2srvSessionIdFromPcmUrl(
        'https://example.com/x?name=Other/317221/1',
      ),
      isNull,
    );
  });

  test('returns null for invalid url', () {
    expect(parseLt2srvSessionIdFromPcmUrl(''), isNull);
  });
}
