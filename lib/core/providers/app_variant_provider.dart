import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lecture_viewer_v3/core/constants/app_variant.dart';

final appVariantProvider = FutureProvider<AppVariant>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return appVariantFromPackageName(info.packageName);
});
