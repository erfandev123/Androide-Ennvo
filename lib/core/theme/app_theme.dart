// ============================================================================
//  ENNVO — APP THEME
//
//  The web app is Tailwind based and has no Material design system, so the
//  Flutter theme is deliberately neutral: every surface colour comes from
//  [EnnvoTokens], and Material's own ripples / hovers are switched off so
//  the native app matches the web build pixel for pixel.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'tokens.dart';
import 'typography.dart';

class EnnvoTheme {
  const EnnvoTheme._();

  /// The border colour of the pill inputs — the web app uses a visible
  /// light grey outline.
  static Color _inputBorder(EnnvoTokens t) =>
      t.isDark ? const Color(0x33FFFFFF) : const Color(0xFFD6DEE8);

  static ThemeData light() => _build(EnnvoTokens.light, Brightness.light);

  static ThemeData dark() => _build(EnnvoTokens.dark, Brightness.dark);

  static ThemeData _build(EnnvoTokens t, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.isDark ? const Color(0xFF04222E) : Colors.white,
      secondary: t.brand,
      onSecondary: Colors.white,
      error: t.danger,
      onError: Colors.white,
      surface: t.surface,
      onSurface: t.textPrimary,
      surfaceContainerHighest: t.surfaceAlt,
      onSurfaceVariant: t.textSecondary,
      outline: t.borderStrong,
      outlineVariant: t.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      fontFamily: EnnvoFonts.ui,
      textTheme: buildEnnvoTextTheme(t.textPrimary, t.textSecondary),
      extensions: <ThemeExtension<dynamic>>[
        t,
        t.isDark ? ActTokens.dark : ActTokens.light,
      ],

      // --- Material's own interaction feedback is disabled -------------
      // The web app hard-disables `:active` styling; a Flutter ripple or
      // highlight would break visual parity.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,

      // --- Buttons ------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: EnnvoText.bodySemi,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.borderStrong),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          textStyle: EnnvoText.bodySemi,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          textStyle: EnnvoText.bodySemi,
        ),
      ),

      // --- Inputs -------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.isDark ? const Color(0xFF12121A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        hintStyle: EnnvoText.body.copyWith(color: t.textTertiary),
        labelStyle: EnnvoText.label.copyWith(color: t.textSecondary),
        // A fully rounded outline — the web app's pill shaped inputs.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: _inputBorder(t)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: _inputBorder(t)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: t.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: t.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: t.danger, width: 1.4),
        ),
      ),

      // --- Bottom sheets ------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),

      // --- Misc ---------------------------------------------------------
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceAlt,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.isDark ? const Color(0xFF121824) : Colors.white,
        contentTextStyle: EnnvoText.body.copyWith(color: t.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _EnnvoPageTransitionBuilder(),
          TargetPlatform.iOS: _EnnvoPageTransitionBuilder(),
          TargetPlatform.linux: _EnnvoPageTransitionBuilder(),
          TargetPlatform.macOS: _EnnvoPageTransitionBuilder(),
          TargetPlatform.windows: _EnnvoPageTransitionBuilder(),
        },
      ),
    );
  }
}

/// The web app has no route-level page transitions — pages are toggled with
/// `display:none`. A very short fade keeps the native app feeling instant
/// while still reading as a real screen change.
class _EnnvoPageTransitionBuilder extends PageTransitionsBuilder {
  const _EnnvoPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: EnnvoCurves.iosSpring,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Android edge-to-edge + transparent system bars, matching the Capacitor
/// shell which overlays the WebView and publishes the notch insets.
const SystemUiOverlayStyle ennvoSystemUiOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
);
