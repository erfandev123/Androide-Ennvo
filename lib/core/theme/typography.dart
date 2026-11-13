// ============================================================================
//  ENNVO — TYPOGRAPHY
//
//  The web app loads Outfit (600/700/800/900) and Plus Jakarta Sans
//  (600/700/800/900) from Google Fonts. `--font-sans` declares Inter but
//  Inter is never actually loaded, so the web build falls back to system-ui.
//
//  Flutter binds the real fonts as assets, so the app renders with the faces
//  the brand intended — and with zero network fetch on first paint.
//
//    brand  → Outfit              (.font-brand in the web app)
//    ui     → Plus Jakarta Sans   (body / labels)
// ============================================================================

import 'package:flutter/material.dart';

/// Font family names, kept in one place.
class EnnvoFonts {
  const EnnvoFonts._();

  static const String brand = 'Outfit';
  static const String ui = 'PlusJakartaSans';
}

/// Named text styles used across the app.
///
/// Every value is taken from the web app's Tailwind classes — the pixel
/// sizes, weights and letter spacings match exactly.
class EnnvoText {
  const EnnvoText._();

  static const TextStyle _ui = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 14,
    height: 1.4,
    color: Colors.black,
  );

  // ---------------------------------------------------------------------
  //  Brand
  // ---------------------------------------------------------------------

  /// `.font-brand` — the app wordmark.
  static const TextStyle brand = TextStyle(
    fontFamily: EnnvoFonts.brand,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.11,
  );

  /// `text-3xl font-extrabold tracking-tight` — the 36px hero wordmark.
  static const TextStyle brandHero = TextStyle(
    fontFamily: EnnvoFonts.brand,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.11,
  );

  /// `text-2xl sm:text-3xl` — page hero.
  static const TextStyle pageHero = TextStyle(
    fontFamily: EnnvoFonts.brand,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // ---------------------------------------------------------------------
  //  Titles
  // ---------------------------------------------------------------------

  /// `text-[22px] font-black tracking-tight` — settings title.
  static const TextStyle titleLg = TextStyle(
    fontFamily: EnnvoFonts.brand,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.55,
    height: 1.25,
  );

  /// `text-[1.2rem] font-bold tracking-[-0.4px]` — notifications title.
  static const TextStyle titleMd = TextStyle(
    fontFamily: EnnvoFonts.brand,
    fontSize: 19.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
  );

  /// `text-xl font-normal` — section title.
  static const TextStyle titleSm = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // ---------------------------------------------------------------------
  //  Body
  // ---------------------------------------------------------------------

  /// `text-[13.5px] font-normal` — the default body size in the app.
  static const TextStyle body = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// `text-[13.5px] font-semibold`
  static const TextStyle bodySemi = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// `text-[13px] font-semibold` — like / comment counts.
  static const TextStyle count = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// `text-[12px] font-semibold`
  static const TextStyle label = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// `text-[11.5px]`
  static const TextStyle caption = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// `text-[10.5px] font-black`
  ///
  /// Plus Jakarta Sans has no 900 weight — the browser falls back to the 800
  /// face, so the Flutter port does the same.
  static const TextStyle micro = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// `text-[9px] font-bold`
  static const TextStyle tiny = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// `text-[0.76rem] font-bold uppercase tracking-[0.8px]`
  static const TextStyle overline = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 12.16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
  );

  /// `text-[10.5px] font-bold uppercase tracking-[0.1em]`
  static const TextStyle overlineXs = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.05,
    height: 1.2,
  );

  /// `text-[13.5px]` caption on the reels page.
  static const TextStyle reelCaption = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// `text-[12px] font-semibold` — the "See more..." toggle.
  static const TextStyle seeMore = TextStyle(
    fontFamily: EnnvoFonts.ui,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
}

/// Builds the app [TextTheme] from the named styles.
TextTheme buildEnnvoTextTheme(Color primary, Color secondary) {
  return TextTheme(
    displayLarge: EnnvoText.brandHero.copyWith(color: primary),
    displayMedium: EnnvoText.pageHero.copyWith(color: primary),
    headlineLarge: EnnvoText.titleLg.copyWith(color: primary),
    headlineMedium: EnnvoText.titleMd.copyWith(color: primary),
    headlineSmall: EnnvoText.titleSm.copyWith(color: primary),
    titleLarge: EnnvoText.bodySemi.copyWith(color: primary),
    titleMedium: EnnvoText.label.copyWith(color: primary),
    titleSmall: EnnvoText.caption.copyWith(color: primary),
    bodyLarge: EnnvoText.body.copyWith(color: primary),
    bodyMedium: EnnvoText.body.copyWith(color: primary),
    bodySmall: EnnvoText.caption.copyWith(color: secondary),
    labelLarge: EnnvoText.bodySemi.copyWith(color: primary),
    labelMedium: EnnvoText.label.copyWith(color: primary),
    labelSmall: EnnvoText.micro.copyWith(color: secondary),
  );
}
