import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Nhóm lỗi mua hàng / restore / logIn — app map sang copy UI riêng.
enum PurchaseErrorKind {
  cancelled,
  network,
  alreadyOwned,
  storeProblem,
  notAllowed,
  unknown,
}

/// Message mặc định tiếng Anh (app có thể override).
String defaultPurchaseErrorMessage(PurchaseErrorKind kind) {
  switch (kind) {
    case PurchaseErrorKind.cancelled:
      return '';
    case PurchaseErrorKind.network:
      return 'Network error. Check your connection and try again.';
    case PurchaseErrorKind.alreadyOwned:
      return 'This purchase is already owned. Try Restore Purchases.';
    case PurchaseErrorKind.storeProblem:
      return 'The store had a problem. Please try again later.';
    case PurchaseErrorKind.notAllowed:
      return 'Purchases are not allowed on this device.';
    case PurchaseErrorKind.unknown:
      return 'Something went wrong. Please try again.';
  }
}

/// Map [PlatformException] từ purchases_flutter sang [PurchaseErrorKind].
PurchaseErrorKind mapPurchasesError(PlatformException exception) {
  late final PurchasesErrorCode code;
  try {
    code = PurchasesErrorHelper.getErrorCode(exception);
  } on Object {
    return PurchaseErrorKind.unknown;
  }
  switch (code) {
    case PurchasesErrorCode.purchaseCancelledError:
      return PurchaseErrorKind.cancelled;
    case PurchasesErrorCode.networkError:
      return PurchaseErrorKind.network;
    case PurchasesErrorCode.productAlreadyPurchasedError:
      return PurchaseErrorKind.alreadyOwned;
    case PurchasesErrorCode.storeProblemError:
      return PurchaseErrorKind.storeProblem;
    case PurchasesErrorCode.purchaseNotAllowedError:
      return PurchaseErrorKind.notAllowed;
    default:
      return PurchaseErrorKind.unknown;
  }
}
