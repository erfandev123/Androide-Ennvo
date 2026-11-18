// ============================================================================
//  ENNVO — AUTH CONTROLLER
//
//  Ports the behaviour of `src/services/authService.ts`:
//
//    • sign in accepts a *username* or an email address
//    • sign up creates the Firebase Auth user, writes the `users/{uid}`
//      document and stores the username on the auth profile
//    • password reset works with an email address or a username
//
//  Everything degrades gracefully: if Firebase could not start, the
//  controller reports a clear message instead of throwing.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';
import '../../data/services/firebase_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController();

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  bool get isBusy => _busy;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  /// Restores the session from a persisted Firebase Auth token.
  Future<void> restore() async {
    // The SDK may still be booting: the app starts it in parallel with its
    // first frame, so the brand splash is on screen while it comes up.
    await FirebaseService.ensureReady();

    if (!FirebaseService.isReady) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      final firebaseUser = FirebaseService.auth.currentUser;
      if (firebaseUser == null) {
        _status = AuthStatus.signedOut;
      } else {
        _user = await _loadUser(firebaseUser.uid);
        _status = AuthStatus.signedIn;
      }
    } catch (_) {
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<AppUser?> _loadUser(String uid) async {
    try {
      final doc = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc, fallbackId: uid);
    } catch (_) {
      return null;
    }
  }

  /// Finds a user document by username — the web app lets people sign in
  /// with their handle instead of their email.
  Future<String?> _emailForUsername(String username) async {
    try {
      final snapshot = await FirebaseService.firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.get('email') as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isUsernameUnique(String username) async {
    if (!FirebaseService.isReady) return true;
    try {
      final snapshot = await FirebaseService.firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Signs in with a username or an email address.
  Future<bool> signIn(String usernameOrEmail, String password) async {
    _setError(null);
    _setBusy(true);
    try {
      if (!FirebaseService.isReady) {
        _setError('Ennvo could not reach the server. Check your connection.');
        return false;
      }

      var identifier = usernameOrEmail.trim();
      if (!identifier.contains('@')) {
        final email = await _emailForUsername(identifier);
        if (email == null) {
          _setError('No account was found for that username.');
          return false;
        }
        identifier = email;
      }

      final credential = await FirebaseService.auth.signInWithEmailAndPassword(
        email: identifier,
        password: password,
      );

      _user = await _loadUser(credential.user!.uid);
      _status = AuthStatus.signedIn;
      return true;
    } on FirebaseAuthException catch (error) {
      _setError(_friendlyMessage(error));
      return false;
    } catch (_) {
      _setError('Something went wrong while signing in.');
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Creates an account.
  Future<bool> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    _setError(null);
    _setBusy(true);
    try {
      if (!FirebaseService.isReady) {
        _setError('Ennvo could not reach the server. Check your connection.');
        return false;
      }

      if (!await isUsernameUnique(username)) {
        _setError('That username is already taken.');
        return false;
      }

      final credential = await FirebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name);

      await FirebaseService.firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'username': username,
        'email': email,
        'avatar': '',
        'bio': '',
        'followersCount': 0,
        'followingCount': 0,
        'postsCount': 0,
        'isVerified': false,
        'isPrivate': false,
        'notifMode': 'on',
        'authProvider': 'password',
        'hasPassword': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _user = await _loadUser(uid);
      _status = AuthStatus.signedIn;
      return true;
    } on FirebaseAuthException catch (error) {
      _setError(_friendlyMessage(error));
      return false;
    } catch (_) {
      _setError('Something went wrong while creating your account.');
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Sends a password reset link to an email address or a username.
  Future<bool> sendPasswordReset(String emailOrUsername) async {
    _setError(null);
    _setBusy(true);
    try {
      if (!FirebaseService.isReady) {
        _setError('Ennvo could not reach the server. Check your connection.');
        return false;
      }

      var email = emailOrUsername.trim();
      if (!email.contains('@')) {
        final resolved = await _emailForUsername(email);
        if (resolved == null) {
          _setError('No account was found for that username.');
          return false;
        }
        email = resolved;
      }

      await FirebaseService.auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (error) {
      _setError(_friendlyMessage(error));
      return false;
    } catch (_) {
      _setError('Something went wrong while sending the reset link.');
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Turns the private account on or off.
  ///
  /// The web app keeps `isPrivate` on the user document, and this does the
  /// same: the profile is the source of truth for the follow graph, the
  /// share sheet and the profile itself.
  Future<void> setPrivate(bool value) async {
    final current = _user;
    if (current == null || current.isPrivate == value) return;

    _user = current.copyWith(isPrivate: value);
    notifyListeners();

    if (!FirebaseService.isReady) return;
    try {
      await FirebaseService.firestore
          .collection('users')
          .doc(current.uid)
          .set({'isPrivate': value}, SetOptions(merge: true));
    } catch (_) {
      // The document is the truth: a failed write puts the switch back.
      _user = current;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      if (FirebaseService.isReady) {
        await FirebaseService.auth.signOut();
      }
    } catch (_) {
      // Ignore — the local session is cleared either way.
    }
    _user = null;
    _status = AuthStatus.signedOut;
    _error = null;
    notifyListeners();
  }

  static String _friendlyMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong username or password.';
      case 'email-already-in-use':
        return 'An account already uses that email address.';
      case 'weak-password':
        return 'Pick a stronger password — at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a moment.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      default:
        return error.message ?? 'Something went wrong.';
    }
  }
}
