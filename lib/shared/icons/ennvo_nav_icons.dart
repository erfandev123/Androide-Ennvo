// ============================================================================
//  ENNVO — CUSTOM NAVIGATION ICONS
//
//  The web app ships eight hand-drawn SVG navigation icons in
//  `src/components/NavIcons.tsx` (not Lucide — these were matched against
//  Flaticon references). The markup below is copied verbatim from that file
//  so the native bottom navigation is identical to the web build.
// ============================================================================

import 'package:flutter/material.dart';

import 'svg_icon.dart';

enum EnnvoNavIcon {
  home,
  feed,
  message,
  create,
  search,
  notification,
  profile,
  settings,
}

/// The original markup of the eight navigation icons.
abstract final class EnnvoNavIcons {
  const EnnvoNavIcons._();

  static const String _header =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
      'viewBox="0 0 24 24" fill="none" stroke="currentColor" '
      'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">';

  /// "Rounded house roof with soft curved archway door"
  static const String home =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
      'viewBox="0 0 24 24" fill="none" stroke="currentColor" '
      'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M10.87 2.45c.67-.58 1.59-.58 2.26 0l7.25 6.34c.77.68 1.12 '
      '1.7.92 2.7l-1.3 6.51A3.25 3.25 0 0 1 16.81 21H14.5a1.25 1.25 0 0 1-1.25-1.25'
      'V15.5a1.25 1.25 0 0 0-2.5 0v4.25c0 .69-.56 1.25-1.25 1.25H7.19a3.25 '
      '3.25 0 0 1-3.19-3l-1.3-6.51a3.25 3.25 0 0 1 .92-2.7L10.87 2.45Z"/>'
      '</svg>';

  /// The filled variant — `fillRule="evenodd"`.
  static const String homeFilled =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
      'viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" '
      'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
      '<path fill-rule="evenodd" clip-rule="evenodd" '
      'd="M10.87 2.45c.67-.58 1.59-.58 2.26 0l7.25 6.34c.77.68 1.12 '
      '1.7.92 2.7l-1.3 6.51A3.25 3.25 0 0 1 16.81 21H14.5a1.25 1.25 0 0 1-1.25-1.25'
      'V15.5a1.25 1.25 0 0 0-2.5 0v4.25c0 .69-.56 1.25-1.25 1.25H7.19a3.25 '
      '3.25 0 0 1-3.19-3l-1.3-6.51a3.25 3.25 0 0 1 .92-2.7L10.87 2.45Z"/>'
      '</svg>';

  /// "Modern rounded feed card with top pill tab and inner rounded square"
  static const String feed =
      '$_header'
      '<rect x="3.5" y="2.5" width="17" height="19" rx="5.2"/>'
      '<line x1="7.5" y1="6.8" x2="13" y2="6.8" stroke-width="2.3"/>'
      '<rect x="6.5" y="10.5" width="11" height="8" rx="2.8" stroke-width="2"/>'
      '</svg>';

  /// "Soft rounded direct message paper plane / send arrow"
  static const String message =
      '$_header'
      '<path d="M7.4 6.32l8.49-3.85c3.81-1.72 5.88.36 4.17 4.17l-3.85 8.49c-1.9 '
      '4.21-5.01 4.21-6.91 0l-1.15-2.54-2.54-1.15c-4.2-1.9-4.2-5 0-6.9l1.79'
      '-1.78v.56z"/>'
      '<path d="M8.33 12.18l3.74-3.75"/>'
      '</svg>';

  /// "Soft Rounded Create (+) Icon"
  static const String create =
      '$_header'
      '<rect x="3" y="3" width="18" height="18" rx="6"/>'
      '<line x1="12" y1="8" x2="12" y2="16"/>'
      '<line x1="8" y1="12" x2="16" y2="12"/>'
      '</svg>';

  /// "Soft Rounded Search Icon"
  static const String search =
      '$_header'
      '<circle cx="11" cy="11" r="7.5"/>'
      '<path d="M20.5 20.5L16.3 16.3" stroke-width="2.4"/>'
      '</svg>';

  /// "Soft Rounded Bell (Notifications) Icon"
  static const String notification =
      '$_header'
      '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>'
      '<path d="M13.73 21a2 2 0 0 1-3.46 0"/>'
      '</svg>';

  /// The filled bell.
  static const String notificationFilled =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
      'viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" '
      'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M12 2a6.5 6.5 0 0 0-6.5 6.5v3.2c0 .9-.38 1.77-1.04 2.39L3.4 '
      '15.1c-.96.9-.32 2.5 1 2.5h15.2c1.32 0 1.96-1.6 1-2.5l-1.06-1.01c-.66'
      '-.62-1.04-1.49-1.04-2.39V8.5A6.5 6.5 0 0 0 12 2zm0 20a3 3 0 0 1-2.83-2h5.66'
      'A3 3 0 0 1 12 22z"/>'
      '</svg>';

  /// "Soft Rounded Profile User Icon"
  static const String profile =
      '$_header'
      '<circle cx="12" cy="7.5" r="4.5"/>'
      '<path d="M4.5 20.5c0-3.5 3.36-6.5 7.5-6.5s7.5 3 7.5 6.5"/>'
      '</svg>';

  /// The filled profile.
  static const String profileFilled =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
      'viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" '
      'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2.5c-4.42 0-8 2.24-8 '
      '5v1.25c0 .69.56 1.25 1.25 1.25h13.5c.69 0 1.25-.56 1.25-1.25V19.5c0-2.76'
      '-3.58-5-8-5z"/>'
      '</svg>';

  /// "Soft Rounded Settings Gear Icon"
  static const String settings =
      '$_header'
      '<circle cx="12" cy="12" r="3"/>'
      '<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 '
      '1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 '
      '0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82 '
      '.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 '
      '.33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 '
      '1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 '
      '0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 '
      '2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 '
      '1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 '
      '0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 '
      '1.65 0 0 0-1.51 1z"/>'
      '</svg>';

  /// The markup of an icon.
  static String of(EnnvoNavIcon icon, {bool filled = false}) {
    switch (icon) {
      case EnnvoNavIcon.home:
        return filled ? homeFilled : home;
      case EnnvoNavIcon.feed:
        return feed;
      case EnnvoNavIcon.message:
        return message;
      case EnnvoNavIcon.create:
        return create;
      case EnnvoNavIcon.search:
        return search;
      case EnnvoNavIcon.notification:
        return filled ? notificationFilled : notification;
      case EnnvoNavIcon.profile:
        return filled ? profileFilled : profile;
      case EnnvoNavIcon.settings:
        return settings;
    }
  }
}

/// Renders one of the eight custom navigation icons.
class EnnvoNavIconView extends StatelessWidget {
  const EnnvoNavIconView(
    this.icon, {
    super.key,
    required this.color,
    this.size = 24,
    this.filled = false,
    this.strokeWidth,
  });

  final EnnvoNavIcon icon;
  final Color color;
  final double size;
  final bool filled;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SvgIcon(
      EnnvoNavIcons.of(icon, filled: filled),
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );
  }
}
