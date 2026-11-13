// ============================================================================
//  ENNVO — PLATFORM STUB
//
//  The web build cannot use `dart:io`, so this stub replaces it there. It
//  mirrors the small part of the `Platform` class the app reads.
// ============================================================================

class Platform {
  const Platform._();

  /// The web build reports a conservative core count.
  static int get numberOfProcessors => 4;

  static bool get isAndroid => false;

  static bool get isIOS => false;

  static bool get isLinux => false;

  static bool get isMacOS => false;

  static bool get isWindows => false;

  static String get operatingSystem => 'web';
}
