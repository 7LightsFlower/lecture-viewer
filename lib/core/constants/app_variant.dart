/// Installed app build: store [product] vs internal [alpha].
enum AppVariant {
  product,
  alpha,
}

/// Alpha builds use a bundle id / application id ending with `.alpha`.
AppVariant appVariantFromPackageName(String packageName) =>
    packageName.endsWith('.alpha') ? AppVariant.alpha : AppVariant.product;
