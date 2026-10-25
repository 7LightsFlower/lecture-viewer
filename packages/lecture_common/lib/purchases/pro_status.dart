import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Trạng thái entitlement Pro, độc lập app.
///
/// Cache JSON thuộc trách nhiệm của app (SharedPreferences), không nằm ở đây.
@immutable
class ProStatus {
  const ProStatus({
    required this.isPro,
    required this.willRenew,
    this.expirationUtc,
    this.productIdentifier,
    this.store,
  });

  factory ProStatus.empty() => const ProStatus(
        isPro: false,
        willRenew: false,
      );

  /// Map từ [CustomerInfo] của RevenueCat. Entitlement inactive / thiếu → Free.
  factory ProStatus.fromCustomerInfo(
    CustomerInfo info, {
    required String entitlementId,
  }) {
    final entitlement = info.entitlements.all[entitlementId];
    if (entitlement == null || !entitlement.isActive) {
      return ProStatus.empty();
    }
    return ProStatus(
      isPro: true,
      willRenew: entitlement.willRenew,
      expirationUtc: _parseUtc(entitlement.expirationDate),
      productIdentifier: entitlement.productIdentifier,
      store: entitlement.store.name,
    ).resolved();
  }

  factory ProStatus.fromJson(Map<String, dynamic> json) {
    return ProStatus(
      isPro: json['isPro'] == true,
      willRenew: json['willRenew'] == true,
      expirationUtc: _parseUtc(json['expirationUtc']),
      productIdentifier: json['productIdentifier'] as String?,
      store: json['store'] as String?,
    );
  }

  static DateTime? _parseUtc(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  final bool isPro;
  final bool willRenew;
  final DateTime? expirationUtc;
  final String? productIdentifier;
  final String? store;

  /// Hết hạn theo đồng hồ local → Free, dù SDK/cache vẫn `isPro`.
  ProStatus resolved([DateTime? now]) {
    final exp = expirationUtc;
    if (!isPro || exp == null) return this;
    final clock = (now ?? DateTime.now()).toUtc();
    if (!exp.isAfter(clock)) return ProStatus.empty();
    return this;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'isPro': isPro,
        'willRenew': willRenew,
        'expirationUtc': expirationUtc?.toUtc().toIso8601String(),
        'productIdentifier': productIdentifier,
        'store': store,
      };

  @override
  bool operator ==(Object other) {
    return other is ProStatus &&
        other.isPro == isPro &&
        other.willRenew == willRenew &&
        other.expirationUtc == expirationUtc &&
        other.productIdentifier == productIdentifier &&
        other.store == store;
  }

  @override
  int get hashCode => Object.hash(
        isPro,
        willRenew,
        expirationUtc,
        productIdentifier,
        store,
      );
}
