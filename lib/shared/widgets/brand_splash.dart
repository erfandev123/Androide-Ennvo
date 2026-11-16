// ============================================================================
//  ENNVO �?" BRAND SPLASH
//
//  The screen the app opens on.
//
//  It is the Ennvo purple with the mark in the middle, and it exists for
//  exactly as long as the session is being restored.
//
//  Two rules shaped it:
//
//    �?� the mark is seen **once**. The Android window carries the same
//      purple and no logo at all, so the hand over from the launcher to
//      Flutter is invisible and the logo never appears twice.
//    �?� nothing animates in. The splash is on screen in the very first
//      frame and it leaves as soon as the app knows who the user is.
// ============================================================================

import 'package:flutter/material.dart';

/// The path of the transparent brand mark inside the asset bundle.
const String kEnnvoLogoAsset = 'assets/brand/ennvo_logo.png';

/// The path of the brand mark on its black tile.
///
/// The splash shows the mark as an opaque tile: a transparent PNG over the
/// purple would let the purple bleed through the strokes of the mark.
const String kEnnvoLogoOnBlackAsset = 'assets/brand/ennvo_logo_on_black.png';

/// The Ennvo purple - the background of the splash and of the app icon.
const Color kEnnvoPurple = Color(0xFF5B21B6);

/// The lighter purple of the halo behind the mark.
const Color kEnnvoPurpleLight = Color(0xFF7C3AED);

/// The mark of the app, on its black tile.
///
/// It is the picture the launcher shows and the picture the splash shows,
/// so it is drawn from the same file in both places.
class EnnvoBrandMark extends StatelessWidget {
  const EnnvoBrandMark({
    super.key,
    this.size = 96,
    this.radius = 0.26,
    this.glow = true,
    this.shadow = true,
  });

  /// The width and the height of the tile.
  final double size;

  /// The corner radius of the tile, as a share of its side.
  final double radius;

  /// Whether a soft halo sits behind the tile.
  final bool glow;

  /// Whether the tile casts a shadow.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(size * radius),
      child: Image.asset(
        kEnnvoLogoOnBlackAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A missing asset must never break the launch screen.
        errorBuilder: (_, __, ___) => ColoredBox(
          color: Colors.black,
          child: SizedBox(width: size, height: size),
        ),
      ),
    );

    if (!glow && !shadow) return tile;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * radius),
        boxShadow: [
          if (shadow)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: size * 0.28,
              offset: Offset(0, size * 0.10),
            ),
          if (glow)
            BoxShadow(
              color: kEnnvoPurpleLight.withValues(alpha: 0.55),
              blurRadius: size * 0.55,
              spreadRadius: size * 0.04,
            ),
        ],
      ),
      child: tile,
    );
  }
}

/// The whole splash: the purple, the mark and the name.
class EnnvoSplash extends StatelessWidget {
  const EnnvoSplash({super.key, this.markSize = 112});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kEnnvoPurple,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A soft halo behind the mark, so the purple is not flat.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.85,
                  colors: [
                    kEnnvoPurpleLight.withValues(alpha: 0.55),
                    kEnnvoPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EnnvoBrandMark(size: markSize),
                SizedBox(height: markSize * 0.18),
                Text(
                  'Ennvo',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: markSize * 0.19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white.withValues(alpha: 0.92),
                    shadows: const [
                      Shadow(color: Color(0x40000000), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
