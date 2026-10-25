import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('apiKeyForPlatform selects iOS key on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      PurchasesGateway.apiKeyForPlatform(
        iosKey: 'appl_ios',
        androidKey: 'goog_android',
      ),
      'appl_ios',
    );
  });

  test('fallbackSubscriptionManagementUrl is App Store on iOS', () {
    expect(
      PurchasesGateway.fallbackSubscriptionManagementUrl(
        platform: TargetPlatform.iOS,
      ).toString(),
      'https://apps.apple.com/account/subscriptions',
    );
  });

  test('fallbackSubscriptionManagementUrl is Play Store on Android', () {
    expect(
      PurchasesGateway.fallbackSubscriptionManagementUrl(
        platform: TargetPlatform.android,
      ).toString(),
      'https://play.google.com/store/account/subscriptions',
    );
  });

  test('apiKeyForPlatform selects Android key on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      PurchasesGateway.apiKeyForPlatform(
        iosKey: 'appl_ios',
        androidKey: 'goog_android',
      ),
      'goog_android',
    );
  });
}
