import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Map<String, Object?> _entitlementJson({
  required bool isActive,
  bool willRenew = true,
  String productIdentifier = 'pro_monthly',
  String? expirationDate = '2026-10-16T00:00:00Z',
}) {
  return <String, Object?>{
    'identifier': 'pro',
    'isActive': isActive,
    'willRenew': willRenew,
    'periodType': 'NORMAL',
    'latestPurchaseDate': '2026-09-16T00:00:00Z',
    'latestPurchaseDateMillis': 1757980800000,
    'originalPurchaseDate': '2026-09-16T00:00:00Z',
    'originalPurchaseDateMillis': 1757980800000,
    'expirationDate': expirationDate,
    'expirationDateMillis': expirationDate == null ? null : 1792108800000,
    'store': 'APP_STORE',
    'productIdentifier': productIdentifier,
    'productPlanIdentifier': null,
    'isSandbox': true,
    'unsubscribeDetectedAt': null,
    'unsubscribeDetectedAtMillis': null,
    'billingIssueDetectedAt': null,
    'billingIssueDetectedAtMillis': null,
    'ownershipType': 'PURCHASED',
    'verification': 'NOT_REQUESTED',
  };
}

CustomerInfo _customerInfo({
  Map<String, Object?>? entitlement,
}) {
  final entitlements = <String, Object?>{};
  if (entitlement != null) {
    entitlements['pro'] = entitlement;
  }
  return CustomerInfo.fromJson(<String, Object?>{
    'requestDate': '2026-09-16T00:00:00Z',
    'firstSeen': '2026-09-16T00:00:00Z',
    'originalAppUserId': r'$RCAnonymousID:abc',
    'nonSubscriptionTransactions': <Object>[],
    'entitlements': <String, Object?>{
      'all': entitlements,
      'active': isActiveEntitlement(entitlement)
          ? <String, Object?>{'pro': entitlement}
          : <String, Object?>{},
      'verification': 'NOT_REQUESTED',
    },
    'allPurchasedProductIdentifiers': <String>['pro_monthly'],
    'allExpirationDates': <String, Object?>{
      'pro_monthly': '2026-10-16T00:00:00Z',
    },
    'allPurchaseDates': <String, Object?>{
      'pro_monthly': '2026-09-16T00:00:00Z',
    },
    'activeSubscriptions': <String>['pro_monthly'],
  });
}

bool isActiveEntitlement(Map<String, Object?>? entitlement) {
  return entitlement != null && entitlement['isActive'] == true;
}

void main() {
  test('empty is Free', () {
    final status = ProStatus.empty();
    expect(status.isPro, isFalse);
    expect(status.willRenew, isFalse);
    expect(status.expirationUtc, isNull);
    expect(status.productIdentifier, isNull);
    expect(status.store, isNull);
  });

  test('json roundtrip preserves Pro fields', () {
    final original = ProStatus(
      isPro: true,
      willRenew: true,
      expirationUtc: DateTime.utc(2026, 10, 16),
      productIdentifier: 'pro_yearly',
      store: 'appStore',
    );
    final restored = ProStatus.fromJson(original.toJson());
    expect(restored, original);
  });

  test('fromJson treats missing / corrupt fields as Free defaults', () {
    expect(ProStatus.fromJson(const {}), ProStatus.empty());
    expect(
      ProStatus.fromJson(const {'isPro': 'yes', 'expirationUtc': 'nope'}),
      ProStatus.empty(),
    );
  });

  test('fromCustomerInfo maps active entitlement to Pro', () {
    final info = _customerInfo(entitlement: _entitlementJson(isActive: true));
    final status = ProStatus.fromCustomerInfo(info, entitlementId: 'pro');
    expect(status.isPro, isTrue);
    expect(status.willRenew, isTrue);
    expect(status.productIdentifier, 'pro_monthly');
    expect(status.store, isNotEmpty);
    expect(status.expirationUtc, isNotNull);
  });

  test('resolved treats past expiration as Free', () {
    final expired = ProStatus(
      isPro: true,
      willRenew: false,
      expirationUtc: DateTime.utc(2020, 1, 1),
    );
    expect(expired.resolved(DateTime.utc(2026, 9, 16)).isPro, isFalse);

    final active = ProStatus(
      isPro: true,
      willRenew: true,
      expirationUtc: DateTime.utc(2026, 10, 16),
    );
    expect(active.resolved(DateTime.utc(2026, 9, 16)).isPro, isTrue);
  });

  test('fromCustomerInfo maps inactive / missing entitlement to Free', () {
    final inactive = _customerInfo(
      entitlement: _entitlementJson(isActive: false),
    );
    expect(
      ProStatus.fromCustomerInfo(inactive, entitlementId: 'pro').isPro,
      isFalse,
    );
    expect(
      ProStatus.fromCustomerInfo(_customerInfo(), entitlementId: 'pro').isPro,
      isFalse,
    );
  });
}
