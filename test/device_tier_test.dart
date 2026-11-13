// ============================================================================
//  ENNVO — DEVICE TIER TESTS
//
//  The lite-mode rule is the single most important performance switch in
//  the app, so it gets its own test.
// ============================================================================

import 'package:ennvo/core/perf/device_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lite mode detection', () {
    test('a 2 GB phone is low tier', () {
      final profile = profileForTesting(ramBytes: 2 * 1024 * 1024 * 1024);
      expect(profile.tier, DeviceTier.low);
      expect(profile.isLite, isTrue);
    });

    test('a 4 core phone is low tier even with plenty of RAM', () {
      // The web app checks `hardwareConcurrency <= 4` as well.
      final profile = profileForTesting(
        ramBytes: 8 * 1024 * 1024 * 1024,
        cores: 4,
      );
      expect(profile.tier, DeviceTier.low);
    });

    test('a modern phone is high tier', () {
      final profile = profileForTesting(
        ramBytes: 8 * 1024 * 1024 * 1024,
        cores: 8,
      );
      expect(profile.tier, DeviceTier.high);
      expect(profile.isLite, isFalse);
    });

    test('a 3 GB phone is medium tier', () {
      final profile = profileForTesting(
        ramBytes: 3 * 1024 * 1024 * 1024,
        cores: 8,
      );
      expect(profile.tier, DeviceTier.medium);
    });

    test('the user override always wins', () {
      final forced = profileForTesting(
        ramBytes: 16 * 1024 * 1024 * 1024,
        cores: 16,
        override: 'on',
      );
      expect(forced.tier, DeviceTier.low);

      final lifted = profileForTesting(
        ramBytes: 1024 * 1024 * 1024,
        cores: 2,
        override: 'off',
      );
      expect(lifted.tier, DeviceTier.medium);
    });
  });

  group('per-tier budgets', () {
    test('a low tier device renders far less at once', () {
      final low = profileForTesting(ramBytes: 1024 * 1024 * 1024);
      final high = profileForTesting(
        ramBytes: 16 * 1024 * 1024 * 1024,
        cores: 12,
      );

      expect(low.reelWindow, lessThan(high.reelWindow));
      expect(low.videoPreloadCount, lessThan(high.videoPreloadCount));
      expect(low.imageCacheBytes, lessThan(high.imageCacheBytes));
      expect(low.diskCacheBytes, lessThan(high.diskCacheBytes));
    });

    test('blurs are disabled on a low tier device', () {
      final low = profileForTesting(ramBytes: 1024 * 1024 * 1024);
      final high = profileForTesting(
        ramBytes: 16 * 1024 * 1024 * 1024,
        cores: 12,
      );

      expect(low.allowBlur, isFalse);
      expect(high.allowBlur, isTrue);
      expect(low.allowShimmer, isFalse);
      expect(high.allowShimmer, isTrue);
    });
  });
}
