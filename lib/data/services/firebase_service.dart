// ============================================================================
//  ENNVO — FIREBASE SERVICE
//
//  Thin wrapper around the Firebase SDK. The app reuses the existing Ennvo
//  Firebase project, so authentication, Firestore, Realtime Database,
//  Storage and FCM work out of the box.
//
//  Initialisation never throws: if the SDK cannot start (no network, a
//  missing configuration, a test environment) the app simply runs in
//  offline mode instead of crashing on launch.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase/firebase_options.dart';

class FirebaseService {
  const FirebaseService._();

  static bool _ready = false;
  static String? _lastError;

  static bool get isReady => _ready;

  static String? get lastError => _lastError;

  /// Initialises the default Firebase app. Safe to call more than once.
  static Future<bool> initialize() async {
    if (_ready) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
      _lastError = null;
      return true;
    } catch (error) {
      _ready = false;
      _lastError = '$error';
      return false;
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static FirebaseDatabase get database => FirebaseDatabase.instance;

  static FirebaseStorage get storage => FirebaseStorage.instance;

  static FirebaseMessaging get messaging => FirebaseMessaging.instance;

  /// The default push gateway, the same one the web app uses.
  static const String pushGateway = 'https://ennvo.vercel.app/api/push';

  /// The media host used by the upload service.
  static const String r2PublicDomain =
      'https://pub-320091ef45b945e6a22b05cf96d6b9b9.r2.dev';
}
