// ============================================================================
//  ENNVO — DESIGN TOKENS
//  Ported 1:1 from the Ennvo web app (src/index.css + Tailwind v4 usage).
//
//  The web app styles dark mode with a large CSS override block instead of
//  token swapping. Flutter gets the real thing: a ThemeExtension that swaps
//  semantic tokens per brightness, plus the two deliberate exceptions the web
//  app keeps light in dark mode (chat view + profile page).
// ============================================================================

import 'package:flutter/material.dart';

/// Ennvo's semantic colour / radius / shadow tokens.
///
/// Use with `Theme.of(context).extension<EnnvoTokens>()!` or the shorter
/// `context.tokens`.
@immutable
class EnnvoTokens extends ThemeExtension<EnnvoTokens> {
  const EnnvoTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.overlay,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.brand,
    required this.brandSoft,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.warning,
    required this.chatBubbleMine,
    required this.chatBubbleTheirs,
    required this.chatTextMine,
    required this.chatTextTheirs,
    required this.chatBackground,
    required this.profileBackground,
    required this.scrim,
    required this.isDark,
  });

  final Brightness brightness;

  /// Page background. Light: `#FFFFFF`, Dark: `#000000`.
  final Color background;

  /// Card / sheet background. Light: `#FFFFFF`, Dark: `#0B0B0E`.
  final Color surface;

  /// Slightly raised surface (inputs, chips). Light: `#F2F4F7`.
  final Color surfaceAlt;

  /// Sunken / muted surface. Light: `#F4F8FF` (settings), Dark: `#090A0F`.
  final Color surfaceSunken;

  /// Dialog / modal scrim behind content.
  final Color overlay;

  /// Hairline border. Light: `rgba(0,0,0,.06)`, Dark: `rgba(255,255,255,.10)`.
  final Color border;

  /// Stronger border for inputs and outlined controls.
  final Color borderStrong;

  /// Body text. Light: `#111827`, Dark: `#FFFFFF`.
  final Color textPrimary;

  /// Secondary text. Light: `#6B7280`, Dark: `#94A3B8`.
  final Color textSecondary;

  /// Tertiary / placeholder text. Light: `#9CA3AF`, Dark: `#64748B`.
  final Color textTertiary;

  /// Disabled label text.
  final Color textDisabled;

  /// Text on a saturated brand surface.
  final Color textInverse;

  /// Primary brand accent — the Ennvo / Instagram-style red `#FE2C55`.
  final Color brand;

  /// Tinted brand background (10–18% alpha).
  final Color brandSoft;

  /// Interaction accent — sky / royal blue `#0EA5E9` → `#2563EB`.
  final Color accent;

  /// Tinted accent background.
  final Color accentSoft;

  final Color success;
  final Color danger;
  final Color warning;

  /// Chat bubble sent by me. Sky fill, white text.
  final Color chatBubbleMine;

  /// Chat bubble received. Light `#F2F4F7`, Dark `#27272A`.
  final Color chatBubbleTheirs;

  final Color chatTextMine;
  final Color chatTextTheirs;

  /// Chat page background. The web app keeps the chat view light in dark
  /// mode — so does this one.
  final Color chatBackground;

  /// Profile page gradient bottom. The profile page is always light.
  final Color profileBackground;

  /// Full screen scrim behind modals.
  final Color scrim;

  final bool isDark;

  // ---------------------------------------------------------------------
  //  Light
  // ---------------------------------------------------------------------
  static const EnnvoTokens light = EnnvoTokens(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF2F4F7),
    surfaceSunken: Color(0xFFF4F8FF),
    overlay: Color(0x66000000),
    border: Color(0x14000000),
    borderStrong: Color(0x1F000000),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    textDisabled: Color(0xFFD1D5DB),
    textInverse: Color(0xFFFFFFFF),
    brand: Color(0xFFFE2C55),
    brandSoft: Color(0x1FFE2C55),
    accent: Color(0xFF0EA5E9),
    accentSoft: Color(0x1A0EA5E9),
    success: Color(0xFF10B981),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFF59E0B),
    chatBubbleMine: Color(0xFF0EA5E9),
    chatBubbleTheirs: Color(0xFFF2F4F7),
    chatTextMine: Color(0xFFFFFFFF),
    chatTextTheirs: Color(0xFF111827),
    chatBackground: Color(0xFFFFFFFF),
    profileBackground: Color(0xFFFAF5FF),
    scrim: Color(0x66000000),
    isDark: false,
  );

  // ---------------------------------------------------------------------
  //  Dark
  // ---------------------------------------------------------------------
  static const EnnvoTokens dark = EnnvoTokens(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF0B0B0E),
    surfaceAlt: Color(0xFF15161C),
    surfaceSunken: Color(0xFF090A0F),
    overlay: Color(0x99000000),
    border: Color(0x1AFFFFFF),
    borderStrong: Color(0x33FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textDisabled: Color(0xFF4B5563),
    textInverse: Color(0xFF111827),
    brand: Color(0xFFFE2C55),
    brandSoft: Color(0x26FE2C55),
    accent: Color(0xFF38BDF8),
    accentSoft: Color(0x2638BDF8),
    success: Color(0xFF34D399),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    chatBubbleMine: Color(0xFF38BDF8),
    chatBubbleTheirs: Color(0xFF27272A),
    chatTextMine: Color(0xFF111827),
    chatTextTheirs: Color(0xFFFFFFFF),
    chatBackground: Color(0xFFFFFFFF),
    profileBackground: Color(0xFFFAF5FF),
    scrim: Color(0x99000000),
    isDark: true,
  );

  @override
  EnnvoTokens copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? overlay,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textInverse,
    Color? brand,
    Color? brandSoft,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? danger,
    Color? warning,
    Color? chatBubbleMine,
    Color? chatBubbleTheirs,
    Color? chatTextMine,
    Color? chatTextTheirs,
    Color? chatBackground,
    Color? profileBackground,
    Color? scrim,
    bool? isDark,
  }) {
    return EnnvoTokens(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      overlay: overlay ?? this.overlay,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      chatBubbleMine: chatBubbleMine ?? this.chatBubbleMine,
      chatBubbleTheirs: chatBubbleTheirs ?? this.chatBubbleTheirs,
      chatTextMine: chatTextMine ?? this.chatTextMine,
      chatTextTheirs: chatTextTheirs ?? this.chatTextTheirs,
      chatBackground: chatBackground ?? this.chatBackground,
      profileBackground: profileBackground ?? this.profileBackground,
      scrim: scrim ?? this.scrim,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  EnnvoTokens lerp(ThemeExtension<EnnvoTokens>? other, double t) {
    if (other is! EnnvoTokens) return this;
    return EnnvoTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      chatBubbleMine: Color.lerp(chatBubbleMine, other.chatBubbleMine, t)!,
      chatBubbleTheirs: Color.lerp(chatBubbleTheirs, other.chatBubbleTheirs, t)!,
      chatTextMine: Color.lerp(chatTextMine, other.chatTextMine, t)!,
      chatTextTheirs: Color.lerp(chatTextTheirs, other.chatTextTheirs, t)!,
      chatBackground: Color.lerp(chatBackground, other.chatBackground, t)!,
      profileBackground: Color.lerp(profileBackground, other.profileBackground, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Shorthand: `context.tokens.brand`.
extension EnnvoTokensX on BuildContext {
  EnnvoTokens get tokens =>
      Theme.of(this).extension<EnnvoTokens>() ?? EnnvoTokens.light;
}

// ============================================================================
//  BRAND CONSTANTS — value is the same in both themes
// ============================================================================

/// The Ennvo brand red. Used for likes, unread badges, the send button and
/// the pull-to-refresh spinner.
const Color kBrand = Color(0xFFFE2C55);

/// The activity "follow back" gradient (`#ff3b5c` → `#ff5376`).
const Color kActivityGradientA = Color(0xFFFF3B5C);
const Color kActivityGradientB = Color(0xFFFF5376);

/// iOS blue used by the activity surface.
const Color kIosBlue = Color(0xFF007AFF);

/// Royal blue — the settings CTA gradient start and the default big-text
/// background colour.
const Color kRoyalBlue = Color(0xFF2563EB);

/// The `theme-color` meta value in the web app.
const Color kThemeColor = Color(0xFF0EA5E9);

/// Profile page gradient (`#e9d5ff` → `#f3e8ff` → `#faf5ff`).
const List<Color> kProfileGradient = [
  Color(0xFFE9D5FF),
  Color(0xFFF3E8FF),
  Color(0xFFFAF5FF),
];

/// Ambient glow behind the reels welcome card and the notifications page.
const List<Color> kAmbientGlow = [
  Color(0x4038BDF8),
  Color(0x26138BEF6),
  Color(0x00000000),
];

// ============================================================================
//  ACTIVITY / NOTIFICATIONS TOKENS
//
//  The web app keeps these in a `:root` block plus a `html.dark` override
//  (`--act-*`). They are reproduced as their own token set because the
//  notifications screen has a very specific iOS look that does not follow
//  the rest of the app's palette.
// ============================================================================

@immutable
class ActTokens extends ThemeExtension<ActTokens> {
  const ActTokens({
    required this.background,
    required this.cardBackground,
    required this.cardBorder,
    required this.cardShine,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentGlow,
    required this.glassNavBackground,
    required this.glassNavBorder,
    required this.pillActiveBackground,
    required this.pillActiveText,
    required this.pillInactiveText,
  });

  final Color background;
  final Color cardBackground;
  final Color cardBorder;
  final Color cardShine;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentGlow;
  final Color glassNavBackground;
  final Color glassNavBorder;
  final Color pillActiveBackground;
  final Color pillActiveText;
  final Color pillInactiveText;

  static const ActTokens light = ActTokens(
    background: Color(0xFFF2F2F7),
    cardBackground: Color(0xE0FFFFFF),
    cardBorder: Color(0x0F000000),
    cardShine: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0x993C3C43),
    accent: Color(0xFF007AFF),
    accentGlow: Color(0x33007AFF),
    glassNavBackground: Color(0xD9FFFFFF),
    glassNavBorder: Color(0xF2FFFFFF),
    pillActiveBackground: Color(0xFF000000),
    pillActiveText: Color(0xFFFFFFFF),
    pillInactiveText: Color(0xFF3C3C43),
  );

  static const ActTokens dark = ActTokens(
    background: Color(0xFF000000),
    cardBackground: Color(0x14FFFFFF),
    cardBorder: Color(0x26FFFFFF),
    cardShine: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0x85FFFFFF),
    accent: Color(0xFF007AFF),
    accentGlow: Color(0x59007AFF),
    glassNavBackground: Color(0xB31A1A20),
    glassNavBorder: Color(0x47FFFFFF),
    pillActiveBackground: Color(0xFFFFFFFF),
    pillActiveText: Color(0xFF000000),
    pillInactiveText: Color(0xB8FFFFFF),
  );

  @override
  ActTokens copyWith({
    Color? background,
    Color? cardBackground,
    Color? cardBorder,
    Color? cardShine,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentGlow,
    Color? glassNavBackground,
    Color? glassNavBorder,
    Color? pillActiveBackground,
    Color? pillActiveText,
    Color? pillInactiveText,
  }) {
    return ActTokens(
      background: background ?? this.background,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShine: cardShine ?? this.cardShine,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentGlow: accentGlow ?? this.accentGlow,
      glassNavBackground: glassNavBackground ?? this.glassNavBackground,
      glassNavBorder: glassNavBorder ?? this.glassNavBorder,
      pillActiveBackground: pillActiveBackground ?? this.pillActiveBackground,
      pillActiveText: pillActiveText ?? this.pillActiveText,
      pillInactiveText: pillInactiveText ?? this.pillInactiveText,
    );
  }

  @override
  ActTokens lerp(ThemeExtension<ActTokens>? other, double t) {
    if (other is! ActTokens) return this;
    return ActTokens(
      background: Color.lerp(background, other.background, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShine: Color.lerp(cardShine, other.cardShine, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      glassNavBackground: Color.lerp(
        glassNavBackground,
        other.glassNavBackground,
        t,
      )!,
      glassNavBorder: Color.lerp(glassNavBorder, other.glassNavBorder, t)!,
      pillActiveBackground: Color.lerp(
        pillActiveBackground,
        other.pillActiveBackground,
        t,
      )!,
      pillActiveText: Color.lerp(pillActiveText, other.pillActiveText, t)!,
      pillInactiveText: Color.lerp(pillInactiveText, other.pillInactiveText, t)!,
    );
  }
}

/// Shorthand: `context.act.textPrimary`.
extension ActTokensX on BuildContext {
  ActTokens get act =>
      Theme.of(this).extension<ActTokens>() ?? ActTokens.light;
}

// ============================================================================
//  RADII — the exact scale used across the web app
// ============================================================================

class AppRadius {
  const AppRadius._();

  static const double sm = 8; // rounded-lg
  static const double md = 12; // rounded-xl
  static const double lg = 16; // rounded-2xl
  static const double xl = 20; // rounded-[20px]
  static const double xxl = 24; // rounded-3xl
  static const double story = 24; // story card, 26 on >=640px
  static const double storyLarge = 26;
  static const double postMedia = 34; // rounded-[34px], 40 on >=640px
  static const double postMediaLarge = 40;
  static const double card = 32; // reels welcome card
  static const double sheet = 34; // bottom sheet top radius
  static const double sheetSmall = 28;
  static const double pill = 999;

  /// Bottom sheet radii vary between 28 / 32 / 34 in the web app. These are
  /// the three that actually ship.
  static const double sheetA = 34;
  static const double sheetB = 32;
  static const double sheetC = 28;
}

// ============================================================================
//  SHADOWS
// ============================================================================

class AppShadows {
  const AppShadows._();

  /// Reels welcome card.
  static const List<BoxShadow> welcomeCard = [
    BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, 25)),
  ];

  /// Primary CTA (sky → indigo).
  static const List<BoxShadow> ctaSky = [
    BoxShadow(color: Color(0x5938BDF8), blurRadius: 25, offset: Offset(0, 10)),
  ];

  /// The gradient app icon ring.
  static const List<BoxShadow> iconRing = [
    BoxShadow(color: Color(0x5938BDF8), blurRadius: 25, offset: Offset(0, 8)),
  ];

  /// In-app toast.
  static const List<BoxShadow> toast = [
    BoxShadow(color: Color(0x2E0EA5E9), blurRadius: 40, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Pull-to-refresh chip.
  static const List<BoxShadow> pullRefresh = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0xF2FFFFFF),
      blurRadius: 2,
      offset: Offset(0, 1.5),
      spreadRadius: -1.5,
    ),
  ];

  /// Double tap heart.
  static const List<BoxShadow> heart = [
    BoxShadow(color: Color(0x80EF4444), blurRadius: 20, offset: Offset(0, 10)),
  ];

  /// Settings active nav item + icon tile.
  static const List<BoxShadow> settingsActive = [
    BoxShadow(color: Color(0x470284C7), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Settings sidebar card.
  static const List<BoxShadow> settingsPanel = [
    BoxShadow(color: Color(0x0F0284C7), blurRadius: 10, offset: Offset(0, 2)),
  ];

  /// Activity stack card.
  static const List<BoxShadow> activityCard = [
    BoxShadow(color: Color(0x14000000), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Chat input container.
  static const List<BoxShadow> chatInput = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 25, offset: Offset(0, 8)),
    BoxShadow(
      color: Color(0xD9FFFFFF),
      blurRadius: 2,
      offset: Offset(0, 1.5),
      spreadRadius: -1.5,
    ),
  ];

  /// Activity glass navigation pill.
  static const List<BoxShadow> glassPill = [
    BoxShadow(color: Color(0x40000000), blurRadius: 45, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x99FFFFFF), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// PC dock.
  static const List<BoxShadow> dock = [
    BoxShadow(color: Color(0x14020623), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

// ============================================================================
//  GRADIENTS
// ============================================================================

class AppGradients {
  const AppGradients._();

  /// Create button — `from-sky-400 via-blue-500 to-indigo-600`.
  static const LinearGradient create = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF3B82F6), Color(0xFF4F46E5)],
  );

  /// App icon ring — `from-sky-400 via-indigo-500 to-pink-500`.
  static const LinearGradient iconRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFFEC4899)],
  );

  /// Settings active nav item — `from-sky-500 to-blue-600`.
  static const LinearGradient settingsActive = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  );

  /// Settings icon tile — `from-sky-500 to-blue-600` (top-left → bottom-right).
  static const LinearGradient settingsTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  );

  /// Reels welcome name — `from-sky-400 via-teal-300 to-pink-400`.
  static const LinearGradient welcomeName = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF5EEAD4), Color(0xFFF472B6)],
  );

  /// Activity pulse dot — `from-rose-500 to-purple-500`.
  static const LinearGradient activityPulse = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFA855F7)],
  );

  /// Reel share buttons — `from-purple-600 to-indigo-600`.
  static const LinearGradient share = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9333EA), Color(0xFF4F46E5)],
  );

  /// The 14 big-text backgrounds offered by the create screen.
  static const Map<String, String> bigTextBackgrounds = {
    'none': '',
    'sky': 'linear-gradient(to top right, #2563eb, #4f46e5, #0ea5e9)',
    'sunset': 'linear-gradient(to top right, #f59e0b, #f43f5e, #9333ea)',
    'violet': 'linear-gradient(to bottom right, #7e22ce, #4f46e5, #2563eb)',
    'cyan': 'linear-gradient(to right, #06b6d4, #14b8a6, #2563eb)',
    'rose': 'linear-gradient(to top right, #e11d48, #db2777, #9333ea)',
    'ocean': 'linear-gradient(to top right, #1d4ed8, #1e293b, #0f172a)',
    'emerald': 'linear-gradient(to right, #10b981, #0d9488, #0e7490)',
    'fire': 'linear-gradient(to top right, #dc2626, #f97316, #f59e0b)',
    'plum': 'linear-gradient(to top right, #0f172a, #2e1065, #312e81)',
    'lavender': 'linear-gradient(to top right, #c026d3, #7c3aed, #4f46e5)',
    'gold': 'linear-gradient(to top right, #fbbf24, #f97316, #e11d48)',
    'dark': '#171717',
    'cobalt': '#2563eb',
  };
}

// ============================================================================
//  SPACING — 4 / 8 dp rhythm
// ============================================================================

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal page padding used by the feed, notifications and chat.
  static const double pageH = 16;
}

// ============================================================================
//  SIZES
// ============================================================================

class AppSizes {
  const AppSizes._();

  static const double bottomNavHeight = 56;
  static const double bottomNavPillMinWidth = 292;
  static const double bottomNavPillMaxWidth = 340;

  /// The floating pill of the glass skin hovers this far above the system
  /// gesture bar, the way the web app's `bottom-3` does.
  static const double bottomNavGap = 12;

  /// The height of the classic, full width navigation bar.
  static const double bottomNavHeightClassic = 58;

  /// The distance from the bottom of the screen to the top edge of the
  /// floating navigation pill.
  ///
  /// Every page uses it to keep its content clear of the bar — the reels
  /// timeline sits on it, and the messages and the chat scroll behind it.
  static double bottomNavTop(double safeBottom) =>
      safeBottom + bottomNavGap + bottomNavHeight;

  /// The room a page has to keep at the bottom so its content never slides
  /// under the floating navigation bar.
  static double bottomNavClearance(double safeBottom) =>
      bottomNavTop(safeBottom) + 10;

  /// The distance from the bottom of the screen to the top edge of the bar
  /// of the skin in use.
  ///
  /// The classic bar is flush with the bottom of the screen, so the reels
  /// timeline can sit directly on top of it; the glass pill floats and
  /// keeps its gap.
  static double navTopFor(String style, double safeBottom) =>
      style == 'classic'
      ? safeBottom + bottomNavHeightClassic
      : bottomNavTop(safeBottom);

  /// The room a page keeps at the bottom for the bar of the skin in use.
  static double navClearanceFor(String style, double safeBottom) =>
      navTopFor(style, safeBottom) + 10;
  static const double navIconSize = 21;
  static const double navIconSizeClassic = 23;
  static const double createButtonSize = 32;
  static const double createButtonSizeClassic = 38;

  static const double storyCardWidth = 96;
  static const double storyCardHeight = 142;
  static const double storyCardWidthLarge = 110;
  static const double storyCardHeightLarge = 162;

  static const double postMediaHeight = 360;
  static const double postMediaHeightLarge = 420;

  static const double avatarSmall = 32;
  static const double avatarMedium = 44;
  static const double avatarLarge = 96;

  static const double touchTarget = 48; // Android minimum
  static const double touchTargetApple = 44; // iOS minimum
}
