// ============================================================================
//  ENNVO — APP ENTRY POINT
//
//  Bootstrap order matters (ported from the web app's `src/main.tsx`):
//    1. read the persisted theme so the very first frame is already dark
//    2. detect the device tier so lite mode is known before the first paint
//    3. configure the image caches for that tier
//    4. start Firebase and restore the session
//    5. render
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/perf/device_tier.dart';
import 'core/providers.dart';
import 'core/storage/app_prefs.dart';
import 'data/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge, transparent system bars — the Capacitor shell overlays
  // the WebView and publishes the notch insets, so the Flutter app does the
  // same.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );

  final prefs = await AppPrefs.load();

  // 1 + 2 — theme first, then the device tier.
  final profile = await DeviceTierService.detect(
    userOverride: prefs.liteOverride,
  );

  // 3 — image cache sized for the device.
  PaintingBinding.instance.imageCache.maximumSizeBytes = profile.imageCacheBytes;

  if (profile.requestSustainedPerformance) {
    unawaited(requestSustainedPerformance());
  }

  // 4 — Firebase. A failure here must never stop the app from starting,
  // so the error is swallowed and the app runs in offline mode.
  await FirebaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWith((ref) => prefs),
        deviceProfileProvider.overrideWithValue(profile),
      ],
      child: const EnnvoApp(),
    ),
  );
}

/// Fire and forget without the `dart:async` import noise.
void unawaited(Future<void> future) {
  future.catchError((Object _) {});
}
