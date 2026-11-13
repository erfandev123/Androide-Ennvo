// ============================================================================
//  ENNVO — APP PREFERENCES
//
//  A typed wrapper over SharedPreferences that keeps the web app's
//  localStorage key names, so a value written by the web build and a value
//  written by the native build stay in the same namespace.
//
//    ennvo_theme_mode      → 'light' | 'dark'
//    ennvo_lite            → 'on' | 'off'
//    ennvo_nav_style       → 'classic' | 'glass'
//    ennvo_profile_style   → 'design1' | 'design2'
//    ennvo_reels_style     → 'design1' | 'design2' | 'tiktok'
//    ennvo_seen_reels_v2   → JSON array, capped at 250 ids
//    lastVisitedPage       → the page the app was last on
//    ennvo_new_user_welcome→ the name shown in the reels welcome card
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs extends ChangeNotifier {
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPrefs(prefs);
  }

  // --- Keys -------------------------------------------------------------
  static const String kThemeMode = 'ennvo_theme_mode';
  static const String kLite = 'ennvo_lite';
  static const String kNavStyle = 'ennvo_nav_style';
  static const String kProfileStyle = 'ennvo_profile_style';
  static const String kReelsStyle = 'ennvo_reels_style';
  static const String kSeenReels = 'ennvo_seen_reels_v2';
  static const String kLastVisitedPage = 'lastVisitedPage';
  static const String kNewUserWelcome = 'ennvo_new_user_welcome';
  static const String kBackendUrl = 'ennvo_backend_url';
  static const String kBatteryPromptDone = 'ennvo_battery_prompt_done';
  static const String kUpdateDismissed = 'ennvo_update_dismissed';

  // --- Theme ------------------------------------------------------------
  bool get isDarkTheme => _prefs.getString(kThemeMode) == 'dark';

  Future<void> setDarkTheme(bool dark) async {
    await _prefs.setString(kThemeMode, dark ? 'dark' : 'light');
    notifyListeners();
  }

  // --- Lite mode --------------------------------------------------------
  String? get liteOverride => _prefs.getString(kLite);

  Future<void> setLiteOverride(String? value) async {
    if (value == null) {
      await _prefs.remove(kLite);
    } else {
      await _prefs.setString(kLite, value);
    }
    notifyListeners();
  }

  // --- Navigation style -------------------------------------------------
  /// `'classic'` or `'glass'` — the web app defaults to `'glass'`.
  String get navStyle => _prefs.getString(kNavStyle) ?? 'glass';

  Future<void> setNavStyle(String style) async {
    await _prefs.setString(kNavStyle, style);
    notifyListeners();
  }

  String get profileStyle => _prefs.getString(kProfileStyle) ?? 'design1';

  Future<void> setProfileStyle(String style) async {
    await _prefs.setString(kProfileStyle, style);
    notifyListeners();
  }

  String get reelsStyle => _prefs.getString(kReelsStyle) ?? 'design1';

  Future<void> setReelsStyle(String style) async {
    await _prefs.setString(kReelsStyle, style);
    notifyListeners();
  }

  // --- Seen reels -------------------------------------------------------
  /// The web app stores this in localStorage, capped at the 250 most recent
  /// ids, so the ranking can demote content the user already watched.
  List<String> get seenReels {
    final raw = _prefs.getString(kSeenReels);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Corrupt value — start fresh.
    }
    return const [];
  }

  static const int _seenReelsCap = 250;

  Future<void> markReelSeen(String reelId) async {
    final list = seenReels.toList();
    if (list.remove(reelId)) {
      list.insert(0, reelId);
    } else {
      list.insert(0, reelId);
    }
    if (list.length > _seenReelsCap) {
      list.removeRange(_seenReelsCap, list.length);
    }
    await _prefs.setString(kSeenReels, jsonEncode(list));
  }

  // --- Session ----------------------------------------------------------
  String? get lastVisitedPage => _prefs.getString(kLastVisitedPage);

  Future<void> setLastVisitedPage(String page) async {
    await _prefs.setString(kLastVisitedPage, page);
  }

  String? get newUserWelcomeName => _prefs.getString(kNewUserWelcome);

  Future<void> setNewUserWelcomeName(String? name) async {
    if (name == null) {
      await _prefs.remove(kNewUserWelcome);
    } else {
      await _prefs.setString(kNewUserWelcome, name);
    }
  }

  String? get backendUrl => _prefs.getString(kBackendUrl);

  Future<void> setBackendUrl(String? url) async {
    if (url == null) {
      await _prefs.remove(kBackendUrl);
    } else {
      await _prefs.setString(kBackendUrl, url);
    }
  }

  bool get batteryPromptDone => _prefs.getBool(kBatteryPromptDone) ?? false;

  Future<void> setBatteryPromptDone(bool value) async {
    await _prefs.setBool(kBatteryPromptDone, value);
  }

  bool isUpdateDismissed(int versionCode) =>
      _prefs.getString('$kUpdateDismissed$versionCode') != null;

  Future<void> dismissUpdate(int versionCode) async {
    await _prefs.setString('$kUpdateDismissed$versionCode', '1');
  }
}
