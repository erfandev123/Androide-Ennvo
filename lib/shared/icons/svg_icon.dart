// ============================================================================
//  ENNVO — SVG ICON
//
//  A thin wrapper over `flutter_svg` that renders the original SVG markup
//  of an icon.
//
//  The tint is applied with a `srcIn` colour filter, and the stroke width
//  and the fill are changed by rewriting the root element — which keeps the
//  icons byte identical to the web build apart from the colour.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.svg, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth,
    this.filled = false,
    this.semanticLabel,
  });

  /// The complete SVG markup of the icon.
  final String svg;

  final double size;
  final Color? color;

  /// Overrides the `stroke-width` of the root element.
  final double? strokeWidth;

  /// Fills the outline — the web app does this with `fill-rose-500` on the
  /// like button and on the saved bookmark.
  final bool filled;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF111827);

    Widget icon = SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        _prepare(),
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      ),
    );

    if (semanticLabel != null) {
      icon = Semantics(label: semanticLabel, child: icon);
    }
    return icon;
  }

  String _prepare() {
    var result = svg;
    if (filled) {
      result = result.replaceFirst('fill="none"', 'fill="currentColor"');
    }
    final width = strokeWidth;
    if (width != null) {
      result = result.replaceFirst(
        'stroke-width="2"',
        'stroke-width="${width.toStringAsFixed(2)}"',
      );
    }
    return result;
  }
}

/// Renders one of the generated Lucide icons.
///
/// The Lucide set is drawn with a stroke of 2 and round caps and joins — the
/// same as the web build.
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.svg, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.filled = false,
    this.semanticLabel,
  });

  final String svg;
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgIcon(
      svg,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      filled: filled,
      semanticLabel: semanticLabel,
    );
  }
}
