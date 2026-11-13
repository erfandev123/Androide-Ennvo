// ============================================================================
//  ENNVO — DEVICE TIER / LITE MODE
//
//  The web app enables "lite mode" automatically when the device reports
//  `navigator.deviceMemory <= 2` or `hardwareConcurrency <= 4`:
//
//    src/main.tsx
//      const lowMem = (navigator as any).deviceMemory <= 2;
//      const fewCores = navigator.hardwareConcurrency <= 4;
//      if (lowMem || fewCores) document.documentElement.classList.add('ennvo-lite')
//
//  Lite mode disables every `backdrop-filter`, which is by far the most
//  expensive thing the app does on a weak GPU. The native port does the
//  same thing, but goes further: it also shrinks the image cache, reduces
//  the number of preloaded videos and drops the reel render window.
//
//  The RAM figure comes from the native shell through a small method
//  channel (`ActivityManager.MemoryInfo.totalMem` on Android,
//  `ProcessInfo.processInfo.physicalMemory` on iOS).
// ============================================================================

// The web build cannot use `dart:io`, so the platform lookup is redirected
// to a small stub there.
import 'dart:io'
    if (dart.library.js_interop) 'platform_stub.dart'
    as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DeviceTier {
  /// Plenty of headroom — full effects, larger caches, bigger reel window.
  high,

  /// Mid range — effects on, caches trimmed.
  medium,

  /// Low end — lite mode. No blurs, small caches, minimal video window.
  low,
}

class DeviceProfile {
  const DeviceProfile({
    required this.tier,
    required this.ramBytes,
    required this.cores,
    required this.isLowRamDevice,
    required this.userOverride,
  });

  final DeviceTier tier;
  final int ramBytes;
  final int cores;
  final bool isLowRamDevice;

  /// `'on' | 'off' | null` — the web app's `localStorage['ennvo_lite']`.
  final String? userOverride;

  bool get isLite => tier == DeviceTier.low;

  /// RAM in gigabytes, matching `navigator.deviceMemory`.
  double get ramGb => ramBytes / (1024 * 1024 * 1024);

  /// How many reels stay mounted around the active one.
  ///
  /// The web app uses `REEL_WINDOW = 4`. On a low end device that is far
  /// too many `<video>` elements, so the native port trims it.
  int get reelWindow => switch (tier) {
    DeviceTier.low => 1,
    DeviceTier.medium => 2,
    DeviceTier.high => 3,
  };

  /// How many videos are preloaded ahead of the active one.
  int get videoPreloadCount => switch (tier) {
    DeviceTier.low => 1,
    DeviceTier.medium => 2,
    DeviceTier.high => 3,
  };

  /// Maximum number of decoded images kept in memory.
  int get imageCacheBytes => switch (tier) {
    DeviceTier.low => 24 * 1024 * 1024,
    DeviceTier.medium => 48 * 1024 * 1024,
    DeviceTier.high => 96 * 1024 * 1024,
  };

  /// Maximum disk cache for downloaded media.
  int get diskCacheBytes => switch (tier) {
    DeviceTier.low => 48 * 1024 * 1024,
    DeviceTier.medium => 96 * 1024 * 1024,
    DeviceTier.high => 192 * 1024 * 1024,
  };

  /// Whether `BackdropFilter` blur effects may be used at all.
  bool get allowBlur => tier != DeviceTier.low;

  /// Whether the pull-to-refresh shimmer runs.
  bool get allowShimmer => tier != DeviceTier.low;

  /// Whether the app should request a sustained performance mode.
  bool get requestSustainedPerformance => tier == DeviceTier.high;
}

class DeviceTierService {
  const DeviceTierService._();

  static const MethodChannel _channel = MethodChannel('ennvo/device');

  /// Detects the device profile. Safe to call before `runApp` — it never
  /// throws and falls back to a conservative profile.
  static Future<DeviceProfile> detect({String? userOverride}) async {
    int ramBytes = 0;
    int cores = io.Platform.numberOfProcessors;
    bool lowRam = false;

    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(
        'deviceInfo',
      );
      if (info != null) {
        ramBytes = (info['ramBytes'] as num?)?.toInt() ?? 0;
        cores = (info['cores'] as num?)?.toInt() ?? cores;
        lowRam = info['isLowRam'] as bool? ?? false;
      }
    } on MissingPluginException {
      // Desktop / test — fall through to the heuristic below.
    } catch (_) {
      // Never let detection break startup.
    }

    final ramGb = ramBytes / (1024 * 1024 * 1024);

    // Mirror the web app's rule exactly:
    //   deviceMemory <= 2  ||  hardwareConcurrency <= 4  →  lite
    final webLite = (ramBytes > 0 && ramGb <= 2.0) || cores <= 4;

    DeviceTier tier;
    if (webLite || lowRam) {
      tier = DeviceTier.low;
    } else if (ramBytes > 0 && ramGb <= 4.0) {
      tier = DeviceTier.medium;
    } else {
      tier = DeviceTier.high;
    }

    // The user's explicit choice always wins — same as the web app.
    if (userOverride == 'on') {
      tier = DeviceTier.low;
    } else if (userOverride == 'off' && tier == DeviceTier.low) {
      tier = DeviceTier.medium;
    }

    return DeviceProfile(
      tier: tier,
      ramBytes: ramBytes,
      cores: cores,
      isLowRamDevice: lowRam,
      userOverride: userOverride,
    );
  }

  /// A conservative profile used before detection finishes, and in tests.
  static const DeviceProfile unknown = DeviceProfile(
    tier: DeviceTier.medium,
    ramBytes: 0,
    cores: 4,
    isLowRamDevice: false,
    userOverride: null,
  );
}

/// Requests sustained performance mode on capable Android devices.
///
/// This asks the OS to keep the CPU at full clocks and reduce thermal
/// throttling — useful for a scrolling video feed.
Future<void> requestSustainedPerformance() async {
  if (!io.Platform.isAndroid) return;
  try {
    await const MethodChannel('ennvo/device').invokeMethod(
      'requestSustainedPerformance',
    );
  } catch (_) {
    // Not available on every device — ignore.
  }
}

@visibleForTesting
DeviceProfile profileForTesting({
  int ramBytes = 0,
  int cores = 8,
  bool lowRam = false,
  String? override,
}) {
  final ramGb = ramBytes / (1024 * 1024 * 1024);
  final webLite = (ramBytes > 0 && ramGb <= 2.0) || cores <= 4;
  final tier = override == 'on'
      ? DeviceTier.low
      : override == 'off'
          ? (webLite ? DeviceTier.medium : DeviceTier.high)
          : (webLite || lowRam
              ? DeviceTier.low
              : (ramBytes > 0 && ramGb <= 4.0
                  ? DeviceTier.medium
                  : DeviceTier.high));
  return DeviceProfile(
    tier: tier,
    ramBytes: ramBytes,
    cores: cores,
    isLowRamDevice: lowRam,
    userOverride: override,
  );
}
