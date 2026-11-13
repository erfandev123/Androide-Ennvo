// ============================================================================
//  ENNVO — FIREBASE OPTIONS
//
//  The native Android app reuses the *existing* Ennvo Firebase project, so
//  authentication, Firestore, Realtime Database, Storage and FCM all work
//  with no new console setup. These values come straight from the
//  Capacitor project's `android/app/google-services.json`.
//
//  The iOS bundle still has to be registered in the Firebase console; the
//  iOS block below uses the web app's identifiers as a placeholder and must
//  be replaced with the real iOS app id before an iOS build.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, kIsWeb, defaultTargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'Ennvo has no Firebase configuration for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBF6QrSEtyz61W3_02mQ2K3-1133tWSR8M',
    appId: '1:8931913340:android:40740b62d10f13b3e123f9',
    messagingSenderId: '8931913340',
    projectId: 'ennvo-6c01c',
    databaseURL: 'https://ennvo-6c01c-default-rtdb.firebaseio.com',
    storageBucket: 'ennvo-6c01c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDhDRjiwHb5aeC8YJ6-JQDmxlSAVKZQzd0',
    appId: '1:8931913340:web:7c7506d7c2a1ba87e123f9',
    messagingSenderId: '8931913340',
    projectId: 'ennvo-6c01c',
    databaseURL: 'https://ennvo-6c01c-default-rtdb.firebaseio.com',
    storageBucket: 'ennvo-6c01c.firebasestorage.app',
    iosBundleId: 'com.erfan.ennvoapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDhDRjiwHb5aeC8YJ6-JQDmxlSAVKZQzd0',
    appId: '1:8931913340:web:7c7506d7c2a1ba87e123f9',
    messagingSenderId: '8931913340',
    projectId: 'ennvo-6c01c',
    databaseURL: 'https://ennvo-6c01c-default-rtdb.firebaseio.com',
    storageBucket: 'ennvo-6c01c.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDhDRjiwHb5aeC8YJ6-JQDmxlSAVKZQzd0',
    appId: '1:8931913340:web:7c7506d7c2a1ba87e123f9',
    messagingSenderId: '8931913340',
    projectId: 'ennvo-6c01c',
    databaseURL: 'https://ennvo-6c01c-default-rtdb.firebaseio.com',
    storageBucket: 'ennvo-6c01c.firebasestorage.app',
  );
}
