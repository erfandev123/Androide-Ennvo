// ============================================================================
//  ENNVO — BRAND SPLASH
//
//  The screen the app opens on: full black, and only the white mark of the
//  brand in the middle. No purple, no tile, no circle behind the mark, no
//  animation.
//
//  The Android window behind it is black too, and it carries no logo at all,
//  so the mark is seen **exactly once** and the hand over from the launcher
//  is invisible.
// ============================================================================

import 'package:flutter/material.dart';

/// The icon of the app: the gradient square with the white mark.
const String kEnnvoLogoAsset = 'assets/brand/ennvo_logo.png';

/// The white mark on a transparent canvas — the splash draws this one.
const String kEnnvoMarkAsset = 'assets/brand/ennvo_mark_white.png';

/// The white mark on an opaque black tile. Kept for the places that need a
/// square picture rather than a transparent mark.
const String kEnnvoLogoOnBlackAsset = 'assets/brand/ennvo_logo_on_black.png';

/// The black of the splash. The Android window uses the same colour.
const Color kEnnvoSplashBlack = Color(0xFF000000);

/// The mark of the app, on its black tile.
class EnnvoBrandMark extends StatelessWidget {
  const EnnvoBrandMark({
    super.key,
    this.size = 96,
    this.radius = 0.26,
    this.glow = false,
    this.shadow = false,
  });

  /// The width and the height of the mark.
  final double size;

  /// The corner radius, as a share of the side. The mark is drawn on a
  /// transparent canvas, so the radius only matters when a tile is asked
  /// for.
  final double radius;

  /// Whether a soft halo sits behind the mark.
  final bool glow;

  /// Whether the mark casts a shadow.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      kEnnvoMarkAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // A missing asset must never break the launch screen.
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );

    if (!glow && !shadow) return mark;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (shadow)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.16),
              blurRadius: size * 0.24,
              offset: Offset(0, size * 0.06),
            ),
          if (glow)
            BoxShadow(
              color: const Color(0xFF2AA1FB).withValues(alpha: 0.35),
              blurRadius: size * 0.5,
              spreadRadius: size * 0.02,
            ),
        ],
      ),
      child: mark,
    );
  }
}

/// The whole splash: the black and the mark, nothing else.
class EnnvoSplash extends StatelessWidget {
  const EnnvoSplash({super.key, this.markSize = 132});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kEnnvoSplashBlack,
      child: Center(
        child: Semantics(
          label: 'Ennvo',
          image: true,
          child: EnnvoBrandMark(size: markSize),
        ),
      ),
    );
  }
}
