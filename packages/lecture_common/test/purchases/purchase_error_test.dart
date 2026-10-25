import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

PlatformException _rcError(PurchasesErrorCode code) {
  return PlatformException(
    code: code.index.toString(),
    message: code.name,
  );
}

void main() {
  test('maps known PurchasesErrorCode values', () {
    expect(
      mapPurchasesError(_rcError(PurchasesErrorCode.purchaseCancelledError)),
      PurchaseErrorKind.cancelled,
    );
    expect(
      mapPurchasesError(_rcError(PurchasesErrorCode.networkError)),
      PurchaseErrorKind.network,
    );
    expect(
      mapPurchasesError(_rcError(PurchasesErrorCode.productAlreadyPurchasedError)),
      PurchaseErrorKind.alreadyOwned,
    );
    expect(
      mapPurchasesError(_rcError(PurchasesErrorCode.storeProblemError)),
      PurchaseErrorKind.storeProblem,
    );
    expect(
      mapPurchasesError(_rcError(PurchasesErrorCode.purchaseNotAllowedError)),
      PurchaseErrorKind.notAllowed,
    );
    expect(
      mapPurchasesError(_rcError(PurchasesErrorCode.unknownError)),
      PurchaseErrorKind.unknown,
    );
  });

  test('unknown platform code maps to unknown', () {
    expect(
      mapPurchasesError(PlatformException(code: 'not-a-number')),
      PurchaseErrorKind.unknown,
    );
  });

  test('cancelled has empty default message; others are non-empty', () {
    expect(defaultPurchaseErrorMessage(PurchaseErrorKind.cancelled), isEmpty);
    for (final kind in PurchaseErrorKind.values) {
      if (kind == PurchaseErrorKind.cancelled) continue;
      expect(defaultPurchaseErrorMessage(kind), isNotEmpty);
    }
  });
}
