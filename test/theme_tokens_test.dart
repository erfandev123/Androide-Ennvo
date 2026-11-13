// ============================================================================
//  ENNVO — DESIGN TOKEN TESTS
//
//  These lock the native port to the exact values the web app ships.
//  If a token drifts, the test fails instead of the UI silently changing.
// ============================================================================

import 'package:ennvo/core/theme/app_theme.dart';
import 'package:ennvo/core/theme/motion.dart';
import 'package:ennvo/core/theme/tokens.dart';
import 'package:ennvo/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnnvoTokens', () {
    test('light theme matches the web build', () {
      const t = EnnvoTokens.light;
      expect(t.background, const Color(0xFFFFFFFF));
      expect(t.surface, const Color(0xFFFFFFFF));
      expect(t.textPrimary, const Color(0xFF111827));
      expect(t.textSecondary, const Color(0xFF6B7280));
      expect(t.textTertiary, const Color(0xFF9CA3AF));
      expect(t.surfaceAlt, const Color(0xFFF2F4F7));
      expect(t.surfaceSunken, const Color(0xFFF4F8FF));
      expect(t.isDark, isFalse);
    });

    test('dark theme matches the web build', () {
      const t = EnnvoTokens.dark;
      expect(t.background, const Color(0xFF000000));
      expect(t.surface, const Color(0xFF0B0B0E));
      expect(t.textPrimary, const Color(0xFFFFFFFF));
      expect(t.textSecondary, const Color(0xFF94A3B8));
      expect(t.textTertiary, const Color(0xFF64748B));
      expect(t.isDark, isTrue);
    });

    test('the brand red is the same in both themes', () {
      expect(EnnvoTokens.light.brand, const Color(0xFFFE2C55));
      expect(EnnvoTokens.dark.brand, const Color(0xFFFE2C55));
      expect(kBrand, const Color(0xFFFE2C55));
    });

    test('the chat view stays light in dark mode', () {
      // The web app keeps `.chat-view-container` light — the native port
      // reproduces that exception exactly.
      expect(EnnvoTokens.dark.chatBackground, const Color(0xFFFFFFFF));
    });

    test('the profile page stays light in dark mode', () {
      expect(EnnvoTokens.dark.profileBackground, const Color(0xFFFAF5FF));
    });

    test('copyWith and lerp behave', () {
      const base = EnnvoTokens.light;
      final darker = base.copyWith(textPrimary: const Color(0xFF000000));
      expect(darker.textPrimary, const Color(0xFF000000));
      expect(darker.background, base.background);

      final mid = base.lerp(EnnvoTokens.dark, 0.5);
      expect(mid.background, isNot(base.background));
      expect(mid.background, isNot(EnnvoTokens.dark.background));
    });
  });

  group('AppTheme', () {
    test('light and dark themes expose the tokens extension', () {
      for (final theme in [EnnvoTheme.light(), EnnvoTheme.dark()]) {
        expect(theme.extension<EnnvoTokens>(), isNotNull);
      }
    });

    test('Material ripple and hover feedback are disabled', () {
      // The web app hard-disables `:active` styling; a Flutter ripple
      // would break visual parity.
      final theme = EnnvoTheme.light();
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.hoverColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);
    });

    test('the font families are the brand faces', () {
      final theme = EnnvoTheme.light();
      expect(theme.textTheme.bodyLarge?.fontFamily, EnnvoFonts.ui);
      expect(EnnvoText.brand.fontFamily, EnnvoFonts.brand);
      expect(EnnvoFonts.brand, 'Outfit');
      expect(EnnvoFonts.ui, 'PlusJakartaSans');
    });
  });

  group('motion', () {
    test('the springs match the web app numbers', () {
      expect(EnnvoSprings.navPill.stiffness, 520);
      expect(EnnvoSprings.navPill.damping, 38);
      expect(EnnvoSprings.likePop.stiffness, 450);
      expect(EnnvoSprings.likePop.damping, 18);
      expect(EnnvoSprings.toast.mass, 0.6);
      expect(EnnvoSprings.sheet.mass, 0.7);
    });

    test('the iOS curves match the CSS custom properties', () {
      expect(EnnvoCurves.iosSpring, const Cubic(0.16, 1.0, 0.3, 1.0));
      expect(EnnvoCurves.iosBounce, const Cubic(0.34, 1.45, 0.64, 1.0));
      expect(EnnvoCurves.bubbleSwipe, const Cubic(0.2, 0.9, 0.3, 1.0));
      expect(EnnvoCurves.sheetDismiss, const Cubic(0.32, 0.72, 0.0, 1.0));
    });

    test('the durations match the web app', () {
      expect(EnnvoDurations.doubleTapHeart, const Duration(milliseconds: 600));
      expect(EnnvoDurations.storyProgress, const Duration(milliseconds: 1600));
      expect(EnnvoDurations.modal, const Duration(milliseconds: 180));
      expect(EnnvoDurations.sheet, const Duration(milliseconds: 200));
    });
  });
}
