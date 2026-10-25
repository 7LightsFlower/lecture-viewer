import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'pro_status.dart';

/// Wrapper mỏng quanh purchases_flutter. Config (API key, entitlement id)
/// do app inject. Không expose [Purchases.logOut] — logout sẽ mất quyền.
class PurchasesGateway {
  PurchasesGateway();

  static final PurchasesGateway instance = PurchasesGateway();

  String _entitlementId = 'pro';
  bool _configured = false;
  bool _sdkListenerAttached = false;
  final List<void Function(ProStatus)> _listeners = <void Function(ProStatus)>[];

  Future<void> configure({
    required String iosKey,
    required String androidKey,
    required String entitlementId,
  }) async {
    _entitlementId = entitlementId;
    if (_configured) return;
    final apiKey = apiKeyForPlatform(iosKey: iosKey, androidKey: androidKey);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _attachSdkListener();
    _configured = true;
  }

  /// iOS → [iosKey], Android (và mọi nền tảng khác) → [androidKey].
  @visibleForTesting
  static String apiKeyForPlatform({
    required String iosKey,
    required String androidKey,
  }) {
    return defaultTargetPlatform == TargetPlatform.iOS ? iosKey : androidKey;
  }

  /// [invalidateCache] chỉ khi resume app / lần fetch đầu — xóa cache local
  /// (kể cả update từ Customer Center) rồi hỏi backend, dễ ra status cũ.
  Future<ProStatus> getProStatus({bool invalidateCache = false}) async {
    if (invalidateCache) {
      try {
        await Purchases.invalidateCustomerInfoCache();
      } on Object {
        // SDK chưa configure.
      }
    }
    final info = await Purchases.getCustomerInfo();
    return ProStatus.fromCustomerInfo(info, entitlementId: _entitlementId);
  }

  Future<ProStatus> restore() async {
    final info = await Purchases.restorePurchases();
    return ProStatus.fromCustomerInfo(info, entitlementId: _entitlementId);
  }

  /// Store page để hủy / đổi gói. Flutter SDK không có
  /// `Purchases.showManageSubscriptions()` — dùng [CustomerInfo.managementURL].
  Future<Uri> subscriptionManagementUrl() async {
    final info = await Purchases.getCustomerInfo();
    final raw = info.managementURL;
    if (raw != null && raw.isNotEmpty) {
      return Uri.parse(raw);
    }
    return fallbackSubscriptionManagementUrl();
  }

  /// App Store trên iOS/macOS, Google Play trên mọi nền tảng khác.
  @visibleForTesting
  static Uri fallbackSubscriptionManagementUrl({TargetPlatform? platform}) {
    final target = platform ?? defaultTargetPlatform;
    if (target == TargetPlatform.iOS || target == TargetPlatform.macOS) {
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    }
    return Uri.parse('https://play.google.com/store/account/subscriptions');
  }

  Future<ProStatus> logIn(String code) async {
    final result = await Purchases.logIn(code);
    return ProStatus.fromCustomerInfo(
      result.customerInfo,
      entitlementId: _entitlementId,
    );
  }

  void addProStatusListener(void Function(ProStatus) callback) {
    _listeners.add(callback);
  }

  void removeProStatusListener(void Function(ProStatus) callback) {
    _listeners.remove(callback);
  }

  void _attachSdkListener() {
    if (_sdkListenerAttached) return;
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    _sdkListenerAttached = true;
  }

  void _onCustomerInfo(CustomerInfo info) {
    final status = ProStatus.fromCustomerInfo(
      info,
      entitlementId: _entitlementId,
    );
    for (final callback in List<void Function(ProStatus)>.of(_listeners)) {
      callback(status);
    }
  }
}
