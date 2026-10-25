import 'dart:math';

/// Mã chuyển gói 12 ký tự, format `XXXX-XXXX-XXXX`.
///
/// Alphabet: A–Z và 2–9, loại `0/O/1/I/L` để tránh nhầm khi đọc.
class TransferCode {
  static const int rawLength = 12;
  static const String alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Tạo mã mới. [random] chỉ dùng trong test.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final chars = List<String>.generate(
      rawLength,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    );
    return format(chars.join());
  }

  /// Chuẩn hóa về chữ hoa, bỏ mọi ký tự không phải A–Z / 0–9.
  static String normalize(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Nhóm 12 ký tự thành `XXXX-XXXX-XXXX`. Chuỗi không đủ/thừa vẫn nhóm theo 4.
  static String format(String raw) {
    final cleaned = normalize(raw);
    final chunks = <String>[];
    for (var i = 0; i < cleaned.length; i += 4) {
      final end = i + 4 > cleaned.length ? cleaned.length : i + 4;
      chunks.add(cleaned.substring(i, end));
    }
    return chunks.join('-');
  }

  static bool isValid(String raw) {
    final cleaned = normalize(raw);
    if (cleaned.length != rawLength) return false;
    for (var i = 0; i < cleaned.length; i++) {
      if (!alphabet.contains(cleaned[i])) return false;
    }
    return true;
  }

  /// Parse `scheme://transfer?code=XXXX-XXXX-XXXX`.
  /// [scheme] phải là URI scheme hợp lệ (bắt đầu bằng chữ, ví dụ `twowayv2`).
  /// Trả null nếu sai scheme / host / mã.
  static String? parseDeeplink(Uri uri, {required String scheme}) {
    if (uri.scheme.toLowerCase() != scheme.toLowerCase()) return null;
    if (uri.host.toLowerCase() != 'transfer') return null;
    final code = uri.queryParameters['code'];
    if (code == null || !isValid(code)) return null;
    return format(code);
  }
}
