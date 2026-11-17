// ============================================================================
//  ENNVO — IONICONS
//
//  The high quality icons of the reel rail and the key actions.
//
//  These are the *exact* paths the production web app ships in
//  `src/components/ReelItem.tsx` ("Guaranteed instant-render exact Ionicons
//  SVG paths"). Using them here keeps the native build pixel honest with
//  the web build, and the 32-on-512 stroke reads much better on a phone
//  than a thin 2-on-24 outline.
//
//  Every glyph is a real vector: no emoji, no raster, no blur.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _open =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="32">';
const String _solid =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="currentColor">';

class IonIcons {
  const IonIcons._();

  // --- like ------------------------------------------------------------
  static const String heartOutline = _open +
      '<path d="M352.92 80C288 80 256 144 256 144s-32-64-96.92-64c-52.71 0-95.08 42.7-95.08 95.78 0 102.83 115.54 180.79 192 256.22 76.46-75.43 192-153.39 192-256.22 0-53.08-42.37-95.78-95.08-95.78z"/></svg>';

  static const String heartFilled = _solid +
      '<path d="M256 448l-30.16-27.42C118.8 323.03 48 258.94 48 180.05 48 116.14 98.14 66 162.05 66c36.08 0 70.72 16.79 93.95 43.32C279.23 82.79 313.87 66 349.95 66 413.86 66 464 116.14 464 180.05c0 78.89-70.8 142.98-177.84 240.53L256 448z"/></svg>';

  // --- comment ---------------------------------------------------------
  static const String chatOutline = _open +
      '<path stroke-miterlimit="10" d="M87.49 380c1.19-4.38-1.44-10.47-3.95-14.86a44.86 44.86 0 00-2.54-3.8 199.81 199.81 0 01-33-110C47.65 139.09 140.73 48 255.83 48 356.21 48 440 117.54 459.58 209.85a199 199 0 014.42 41.64c0 112.41-89.49 204.93-204.59 204.93-18.3 0-43-4.6-56.47-8.37s-26.92-8.77-30.39-10.11a31.09 31.09 0 00-11.12-2.07 30.71 30.71 0 00-12.09 2.43l-67.83 24.48a16 16 0 01-4.67 1.22 9.6 9.6 0 01-9.57-9.74 15.85 15.85 0 01.6-3.29z"/></svg>';

  static const String chatFilled = _solid +
      '<path d="M256 448c-26.86 0-51.78-10.74-72.08-30.29L88.64 336H72a24 24 0 01-24-24V136a24 24 0 0124-24h368a24 24 0 0124 24v176a24 24 0 01-24 24h-16.64l-95.28 81.71C307.78 437.26 282.86 448 256 448z"/></svg>';

  // --- repost ----------------------------------------------------------
  static const String repeatOutline = _open +
      '<path d="M320 120l48 48-48 48"/>'
      '<path d="M352 168H144a80.24 80.24 0 00-80 80v16"/>'
      '<path d="M192 392l-48-48 48-48"/>'
      '<path d="M160 344h208a80.24 80.24 0 0080-80v-16"/></svg>';

  // --- favourite -------------------------------------------------------
  static const String bookmarkOutline = _open +
      '<path d="M352 48H160a48 48 0 00-48 48v368l144-128 144 128V96a48 48 0 00-48-48z"/></svg>';

  static const String bookmarkFilled = _solid +
      '<path d="M400 480a16 16 0 01-10.63-4L256 357.41 122.63 476A16 16 0 0196 464V96a64.07 64.07 0 0164-64h192a64.07 64.07 0 0164 64v368a16 16 0 01-16 16z"/></svg>';

  // --- share (the paper plane of the web app) --------------------------
  static const String share = _open +
      '<path d="M448 256L272 88v96C103.57 184 64 304.77 64 424c48.61-62.24 91.6-96 208-96v96z"/></svg>';

  // --- more ------------------------------------------------------------
  static const String more = _solid +
      '<circle cx="256" cy="256" r="32"/>'
      '<circle cx="416" cy="256" r="32"/>'
      '<circle cx="96" cy="256" r="32"/></svg>';

  // --- playback --------------------------------------------------------
  static const String play = _solid +
      '<path d="M120 424V88a24 24 0 0136.56-20.43l252 168a24 24 0 010 40.86l-252 168A24 24 0 01120 424z"/></svg>';

  static const String pause = _solid +
      '<path d="M192 472h-32a24 24 0 01-24-24V64a24 24 0 0124-24h32a24 24 0 0124 24v384a24 24 0 01-24 24z"/>'
      '<path d="M352 472h-32a24 24 0 01-24-24V64a24 24 0 0124-24h32a24 24 0 0124 24v384a24 24 0 01-24 24z"/></svg>';

  // --- camera ----------------------------------------------------------
  static const String camera = _open +
      '<path d="M424 176h-40l-16-48a32 32 0 00-30.21-21.65H174.21A32 32 0 00144 128l-16 48H88a48 48 0 00-48 48v184a48 48 0 0048 48h336a48 48 0 0048-48V224a48 48 0 00-48-48z"/>'
      '<circle cx="256" cy="296" r="72"/></svg>';

  // --- music -----------------------------------------------------------
  static const String music = _solid +
      '<path d="M424 32a8 8 0 00-8.71-7.94l-272 40A8 8 0 00136 72v288.82a80 80 0 1056 76V188l208-30v134.82a80 80 0 1056 76V32z"/></svg>';

  // --- sound -----------------------------------------------------------
  static const String volumeHigh = _open +
      '<path d="M384 192a180 180 0 010 128"/>'
      '<path d="M320 144a96 96 0 010 224"/>'
      '<path d="M256 432a16 16 0 01-10.62-4L150 357.41 64 424V88l86 66.59 95.38-70.59A16 16 0 01256 80z" stroke-linejoin="round"/></svg>';

  static const String volumeOff = _open +
      '<path d="M256 432a16 16 0 01-10.62-4L150 357.41 64 424V88l86 66.59 95.38-70.59A16 16 0 01256 80z" stroke-linejoin="round"/>'
      '<line x1="416" y1="192" x2="496" y2="320"/>'
      '<line x1="496" y1="192" x2="416" y2="320"/></svg>';
}

/// Renders one of the Ionicons above.
///
/// The glyph is a real SVG: it stays sharp at any size and it follows the
/// theme with a single colour filter.
class IonIcon extends StatelessWidget {
  const IonIcon(
    this.svg, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final String svg;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        svg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color ?? IconTheme.of(context).color ?? Colors.white,
          BlendMode.srcIn,
        ),
      ),
    );

    if (semanticLabel != null) {
      child = Semantics(label: semanticLabel, child: child);
    }
    return child;
  }
}
