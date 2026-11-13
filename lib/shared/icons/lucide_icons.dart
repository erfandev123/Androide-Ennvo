// ============================================================================
//  ENNVO — LUCIDE ICONS
//
//  GENERATED FILE — do not edit by hand.
//
//  Source: the exact `lucide-react@0.546.0` package that the Ennvo web app
//  depends on, extracted from its published SVG outlines. Every icon the web
//  app imports is reproduced here with the same path data, the same 24x24
//  viewBox, the same round caps and joins, and the same default stroke
//  width of 2 — so the native build and the web build draw identical
//  glyphs.
//
//  Regenerate with:  node tools/generate_lucide_icons.js
// ============================================================================

import 'package:flutter/material.dart';

/// One drawing instruction of a Lucide icon.
sealed class LucideSegment {
  const LucideSegment();
}

/// A `d="…"` outline.
class LucidePath extends LucideSegment {
  const LucidePath(this.d);
  final String d;
}

/// A `<circle>`.
class LucideCircle extends LucideSegment {
  const LucideCircle(this.cx, this.cy, this.r);
  final double cx;
  final double cy;
  final double r;
}

/// A `<line>`.
class LucideLine extends LucideSegment {
  const LucideLine(this.x1, this.y1, this.x2, this.y2);
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

/// A `<rect>`.
class LucideRect extends LucideSegment {
  const LucideRect(this.x, this.y, this.width, this.height, this.rx, this.ry);
  final double x;
  final double y;
  final double width;
  final double height;
  final double rx;
  final double ry;
}

/// An `<ellipse>`.
class LucideEllipse extends LucideSegment {
  const LucideEllipse(this.cx, this.cy, this.rx, this.ry);
  final double cx;
  final double cy;
  final double rx;
  final double ry;
}

/// A `<polyline>`.
class LucidePolyline extends LucideSegment {
  const LucidePolyline(this.values);
  final List<double> values;
}

/// A `<polygon>`.
class LucidePolygon extends LucideSegment {
  const LucidePolygon(this.values);
  final List<double> values;
}

/// The drawing instructions of one icon.
class LucideIconData {
  const LucideIconData(this.segments);

  final List<LucideSegment> segments;
}

/// Renders a Lucide icon.
///
/// [strokeWidth] defaults to 2, which is what the web app uses everywhere.
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.data, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.filled = false,
    this.semanticLabel,
  });

  final LucideIconData data;
  final double size;
  final Color? color;
  final double strokeWidth;

  /// Fills the outline with [color] before stroking it. The web app does
  /// this with `fill-rose-500` on a stroked icon, for example the like
  /// button and the saved bookmark.
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? const Color(0xFF111827);

    Widget icon = SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LucidePainter(
            data: data,
            color: effectiveColor,
            strokeWidth: strokeWidth,
            filled: filled,
          ),
        ),
      ),
    );

    if (semanticLabel != null) {
      icon = Semantics(label: semanticLabel, child: icon);
    }
    return icon;
  }
}

class _LucidePainter extends CustomPainter {
  const _LucidePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });

  final LucideIconData data;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final segment in data.segments) {
      switch (segment) {
        case LucidePath(:final d):
          final path = Path.parseSvgPathData(d);
          if (path != null) {
            if (filled) canvas.drawPath(path, fillPaint);
            canvas.drawPath(path, paint);
          }
        case LucideCircle(:final cx, :final cy, :final r):
          if (filled) canvas.drawCircle(Offset(cx, cy), r, fillPaint);
          canvas.drawCircle(Offset(cx, cy), r, paint);
        case LucideLine(:final x1, :final y1, :final x2, :final y2):
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        case LucideRect(:final x, :final y, :final width, :final height, :final rx, :final ry):
          canvas.drawRRect(
            RRect.fromLTRBR(
              x,
              y,
              x + width,
              y + height,
              Radius.elliptical(rx, ry),
            ),
            paint,
          );
        case LucideEllipse(:final cx, :final cy, :final rx, :final ry):
          canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), paint);
        case LucidePolyline(:final values):
          final path = Path();
          for (var i = 0; i + 1 < values.length; i += 2) {
            if (i == 0) {
              path.moveTo(values[i], values[i + 1]);
            } else {
              path.lineTo(values[i], values[i + 1]);
            }
          }
          canvas.drawPath(path, paint);
        case LucidePolygon(:final values):
          final path = Path();
          for (var i = 0; i + 1 < values.length; i += 2) {
            if (i == 0) {
              path.moveTo(values[i], values[i + 1]);
            } else {
              path.lineTo(values[i], values[i + 1]);
            }
          }
          if (values.length >= 4) path.close();
          canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LucidePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled ||
        oldDelegate.data != data;
  }
}

/// The icon set used by the Ennvo app.
abstract final class LucideIcons {
  /// Source: `lucide-react` `activity`
  static const LucideIconData activity = LucideIconData([
      LucidePath("M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2"),
  ]);

  /// Source: `lucide-react` `alert-circle`
  static const LucideIconData alertCircle = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `alert-triangle`
  static const LucideIconData alertTriangle = LucideIconData([
      LucidePath("m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"),
      LucidePath("M12 9v4"),
      LucidePath("M12 17h.01"),
  ]);

  /// Source: `lucide-react` `align-left`
  static const LucideIconData alignLeft = LucideIconData([
      LucidePath("M21 5H3"),
      LucidePath("M15 12H3"),
      LucidePath("M17 19H3"),
  ]);

  /// Source: `lucide-react` `arrow-down`
  static const LucideIconData arrowDown = LucideIconData([
      LucidePath("M12 5v14"),
      LucidePath("m19 12-7 7-7-7"),
  ]);

  /// Source: `lucide-react` `arrow-down-circle`
  static const LucideIconData arrowDownCircle = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M12 8v8"),
      LucidePath("m8 12 4 4 4-4"),
  ]);

  /// Source: `lucide-react` `arrow-left`
  static const LucideIconData arrowLeft = LucideIconData([
      LucidePath("m12 19-7-7 7-7"),
      LucidePath("M19 12H5"),
  ]);

  /// Source: `lucide-react` `arrow-up-right`
  static const LucideIconData arrowUpRight = LucideIconData([
      LucidePath("M7 7h10v10"),
      LucidePath("M7 17 17 7"),
  ]);

  /// Source: `lucide-react` `at-sign`
  static const LucideIconData atSign = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8"),
  ]);

  /// Source: `lucide-react` `badge-check`
  static const LucideIconData badgeCheck = LucideIconData([
      LucidePath("M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"),
      LucidePath("m9 12 2 2 4-4"),
  ]);

  /// Source: `lucide-react` `bar-chart-2`
  static const LucideIconData barChart2 = LucideIconData([
      LucidePath("M5 21v-6"),
      LucidePath("M12 21V3"),
      LucidePath("M19 21V9"),
  ]);

  /// Source: `lucide-react` `bell`
  static const LucideIconData bell = LucideIconData([
      LucidePath("M10.268 21a2 2 0 0 0 3.464 0"),
      LucidePath("M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"),
  ]);

  /// Source: `lucide-react` `bell-off`
  static const LucideIconData bellOff = LucideIconData([
      LucidePath("M10.268 21a2 2 0 0 0 3.464 0"),
      LucidePath("M17 17H4a1 1 0 0 1-.74-1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 .258-1.742"),
      LucidePath("m2 2 20 20"),
      LucidePath("M8.668 3.01A6 6 0 0 1 18 8c0 2.687.77 4.653 1.707 6.05"),
  ]);

  /// Source: `lucide-react` `bold`
  static const LucideIconData bold = LucideIconData([
      LucidePath("M6 12h9a4 4 0 0 1 0 8H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h7a4 4 0 0 1 0 8"),
  ]);

  /// Source: `lucide-react` `bookmark`
  static const LucideIconData bookmark = LucideIconData([
      LucidePath("m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"),
  ]);

  /// Source: `lucide-react` `brush`
  static const LucideIconData brush = LucideIconData([
      LucidePath("m11 10 3 3"),
      LucidePath("M6.5 21A3.5 3.5 0 1 0 3 17.5a2.62 2.62 0 0 1-.708 1.792A1 1 0 0 0 3 21z"),
      LucidePath("M9.969 17.031 21.378 5.624a1 1 0 0 0-3.002-3.002L6.967 14.031"),
  ]);

  /// Source: `lucide-react` `cake`
  static const LucideIconData cake = LucideIconData([
      LucidePath("M20 21v-8a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8"),
      LucidePath("M4 16s.5-1 2-1 2.5 2 4 2 2.5-2 4-2 2.5 2 4 2 2-1 2-1"),
      LucidePath("M2 21h20"),
      LucidePath("M7 8v3"),
      LucidePath("M12 8v3"),
      LucidePath("M17 8v3"),
      LucidePath("M7 4h.01"),
      LucidePath("M12 4h.01"),
      LucidePath("M17 4h.01"),
  ]);

  /// Source: `lucide-react` `calendar`
  static const LucideIconData calendar = LucideIconData([
      LucidePath("M8 2v4"),
      LucidePath("M16 2v4"),
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M3 10h18"),
  ]);

  /// Source: `lucide-react` `camera`
  static const LucideIconData camera = LucideIconData([
      LucidePath("M13.997 4a2 2 0 0 1 1.76 1.05l.486.9A2 2 0 0 0 18.003 7H20a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h1.997a2 2 0 0 0 1.759-1.048l.489-.904A2 2 0 0 1 10.004 4z"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `check`
  static const LucideIconData check = LucideIconData([
      LucidePath("M20 6 9 17l-5-5"),
  ]);

  /// Source: `lucide-react` `check-check`
  static const LucideIconData checkCheck = LucideIconData([
      LucidePath("M18 6 7 17l-5-5"),
      LucidePath("m22 10-7.5 7.5L13 16"),
  ]);

  /// Source: `lucide-react` `check-circle-2`
  static const LucideIconData checkCircle2 = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("m9 12 2 2 4-4"),
  ]);

  /// Source: `lucide-react` `chevron-down`
  static const LucideIconData chevronDown = LucideIconData([
      LucidePath("m6 9 6 6 6-6"),
  ]);

  /// Source: `lucide-react` `chevron-left`
  static const LucideIconData chevronLeft = LucideIconData([
      LucidePath("m15 18-6-6 6-6"),
  ]);

  /// Source: `lucide-react` `chevron-right`
  static const LucideIconData chevronRight = LucideIconData([
      LucidePath("m9 18 6-6-6-6"),
  ]);

  /// Source: `lucide-react` `chevron-up`
  static const LucideIconData chevronUp = LucideIconData([
      LucidePath("m18 15-6-6-6 6"),
  ]);

  /// Source: `lucide-react` `clock`
  static const LucideIconData clock = LucideIconData([
      LucidePath("M12 6v6l4 2"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `compass`
  static const LucideIconData compass = LucideIconData([
      LucidePath("m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `copy`
  static const LucideIconData copy = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"),
  ]);

  /// Source: `lucide-react` `crop`
  static const LucideIconData crop = LucideIconData([
      LucidePath("M6 2v14a2 2 0 0 0 2 2h14"),
      LucidePath("M18 22V8a2 2 0 0 0-2-2H2"),
  ]);

  /// Source: `lucide-react` `download`
  static const LucideIconData download = LucideIconData([
      LucidePath("M12 15V3"),
      LucidePath("M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"),
      LucidePath("m7 10 5 5 5-5"),
  ]);

  /// Source: `lucide-react` `download-cloud`
  static const LucideIconData downloadCloud = LucideIconData([
      LucidePath("M12 13v8l-4-4"),
      LucidePath("m12 21 4-4"),
      LucidePath("M4.393 15.269A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.436 8.284"),
  ]);

  /// Source: `lucide-react` `edit-2`
  static const LucideIconData edit2 = LucideIconData([
      LucidePath("M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"),
  ]);

  /// Source: `lucide-react` `edit-3`
  static const LucideIconData edit3 = LucideIconData([
      LucidePath("M13 21h8"),
      LucidePath("M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"),
  ]);

  /// Source: `lucide-react` `eraser`
  static const LucideIconData eraser = LucideIconData([
      LucidePath("M21 21H8a2 2 0 0 1-1.42-.587l-3.994-3.999a2 2 0 0 1 0-2.828l10-10a2 2 0 0 1 2.829 0l5.999 6a2 2 0 0 1 0 2.828L12.834 21"),
      LucidePath("m5.082 11.09 8.828 8.828"),
  ]);

  /// Source: `lucide-react` `external-link`
  static const LucideIconData externalLink = LucideIconData([
      LucidePath("M15 3h6v6"),
      LucidePath("M10 14 21 3"),
      LucidePath("M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"),
  ]);

  /// Source: `lucide-react` `eye`
  static const LucideIconData eye = LucideIconData([
      LucidePath("M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `eye-off`
  static const LucideIconData eyeOff = LucideIconData([
      LucidePath("M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49"),
      LucidePath("M14.084 14.158a3 3 0 0 1-4.242-4.242"),
      LucidePath("M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143"),
      LucidePath("m2 2 20 20"),
  ]);

  /// Source: `lucide-react` `file-text`
  static const LucideIconData fileText = LucideIconData([
      LucidePath("M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"),
      LucidePath("M14 2v4a2 2 0 0 0 2 2h4"),
      LucidePath("M10 9H8"),
      LucidePath("M16 13H8"),
      LucidePath("M16 17H8"),
  ]);

  /// Source: `lucide-react` `film`
  static const LucideIconData film = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M7 3v18"),
      LucidePath("M3 7.5h4"),
      LucidePath("M3 12h18"),
      LucidePath("M3 16.5h4"),
      LucidePath("M17 3v18"),
      LucidePath("M17 7.5h4"),
      LucidePath("M17 16.5h4"),
  ]);

  /// Source: `lucide-react` `fingerprint`
  static const LucideIconData fingerprint = LucideIconData([
      LucidePath("M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4"),
      LucidePath("M14 13.12c0 2.38 0 6.38-1 8.88"),
      LucidePath("M17.29 21.02c.12-.6.43-2.3.5-3.02"),
      LucidePath("M2 12a10 10 0 0 1 18-6"),
      LucidePath("M2 16h.01"),
      LucidePath("M21.8 16c.2-2 .131-5.354 0-6"),
      LucidePath("M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2"),
      LucidePath("M8.65 22c.21-.66.45-1.32.57-2"),
      LucidePath("M9 6.8a6 6 0 0 1 9 5.2v2"),
  ]);

  /// Source: `lucide-react` `flag`
  static const LucideIconData flag = LucideIconData([
      LucidePath("M4 22V4a1 1 0 0 1 .4-.8A6 6 0 0 1 8 2c3 0 5 2 7.333 2q2 0 3.067-.8A1 1 0 0 1 20 4v10a1 1 0 0 1-.4.8A6 6 0 0 1 16 16c-3 0-5-2-8-2a6 6 0 0 0-4 1.528"),
  ]);

  /// Source: `lucide-react` `flame`
  static const LucideIconData flame = LucideIconData([
      LucidePath("M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4"),
  ]);

  /// Source: `lucide-react` `flip-horizontal`
  static const LucideIconData flipHorizontal = LucideIconData([
      LucidePath("M8 3H5a2 2 0 0 0-2 2v14c0 1.1.9 2 2 2h3"),
      LucidePath("M16 3h3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-3"),
      LucidePath("M12 20v2"),
      LucidePath("M12 14v2"),
      LucidePath("M12 8v2"),
      LucidePath("M12 2v2"),
  ]);

  /// Source: `lucide-react` `globe`
  static const LucideIconData globe = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"),
      LucidePath("M2 12h20"),
  ]);

  /// Source: `lucide-react` `grid`
  static const LucideIconData grid = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M3 9h18"),
      LucidePath("M3 15h18"),
      LucidePath("M9 3v18"),
      LucidePath("M15 3v18"),
  ]);

  /// Source: `lucide-react` `hammer`
  static const LucideIconData hammer = LucideIconData([
      LucidePath("m15 12-9.373 9.373a1 1 0 0 1-3.001-3L12 9"),
      LucidePath("m18 15 4-4"),
      LucidePath("m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172v-.344a2 2 0 0 0-.586-1.414l-1.657-1.657A6 6 0 0 0 12.516 3H9l1.243 1.243A6 6 0 0 1 12 8.485V10l2 2h1.172a2 2 0 0 1 1.414.586L18.5 14.5"),
  ]);

  /// Source: `lucide-react` `hard-drive`
  static const LucideIconData hardDrive = LucideIconData([
      LucideLine(0, 0, 0, 0),
      LucidePath("M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `headphones`
  static const LucideIconData headphones = LucideIconData([
      LucidePath("M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"),
  ]);

  /// Source: `lucide-react` `heart`
  static const LucideIconData heart = LucideIconData([
      LucidePath("M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"),
  ]);

  /// Source: `lucide-react` `image`
  static const LucideIconData image = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideCircle(0, 0, 0),
      LucidePath("m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"),
  ]);

  /// Source: `lucide-react` `image`
  static const LucideIconData imageIcon = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideCircle(0, 0, 0),
      LucidePath("m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"),
  ]);

  /// Source: `lucide-react` `info`
  static const LucideIconData info = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M12 16v-4"),
      LucidePath("M12 8h.01"),
  ]);

  /// Source: `lucide-react` `italic`
  static const LucideIconData italic = LucideIconData([
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `key-round`
  static const LucideIconData keyRound = LucideIconData([
      LucidePath("M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `laptop`
  static const LucideIconData laptop = LucideIconData([
      LucidePath("M18 5a2 2 0 0 1 2 2v8.526a2 2 0 0 0 .212.897l1.068 2.127a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45l1.068-2.127A2 2 0 0 0 4 15.526V7a2 2 0 0 1 2-2z"),
      LucidePath("M20.054 15.987H3.946"),
  ]);

  /// Source: `lucide-react` `layers`
  static const LucideIconData layers = LucideIconData([
      LucidePath("M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z"),
      LucidePath("M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12"),
      LucidePath("M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17"),
  ]);

  /// Source: `lucide-react` `link`
  static const LucideIconData link = LucideIconData([
      LucidePath("M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"),
      LucidePath("M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"),
  ]);

  /// Source: `lucide-react` `loader-2`
  static const LucideIconData loader2 = LucideIconData([
      LucidePath("M21 12a9 9 0 1 1-6.219-8.56"),
  ]);

  /// Source: `lucide-react` `lock`
  static const LucideIconData lock = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M7 11V7a5 5 0 0 1 10 0v4"),
  ]);

  /// Source: `lucide-react` `mail`
  static const LucideIconData mail = LucideIconData([
      LucidePath("m22 7-8.991 5.727a2 2 0 0 1-2.009 0L2 7"),
      LucideRect(0, 0, 0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `map-pin`
  static const LucideIconData mapPin = LucideIconData([
      LucidePath("M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `maximize-2`
  static const LucideIconData maximize2 = LucideIconData([
      LucidePath("M15 3h6v6"),
      LucidePath("m21 3-7 7"),
      LucidePath("m3 21 7-7"),
      LucidePath("M9 21H3v-6"),
  ]);

  /// Source: `lucide-react` `message-circle`
  static const LucideIconData messageCircle = LucideIconData([
      LucidePath("M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719"),
  ]);

  /// Source: `lucide-react` `message-square`
  static const LucideIconData messageSquare = LucideIconData([
      LucidePath("M22 17a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 21.286V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2z"),
  ]);

  /// Source: `lucide-react` `mic`
  static const LucideIconData mic = LucideIconData([
      LucidePath("M12 19v3"),
      LucidePath("M19 10v2a7 7 0 0 1-14 0v-2"),
      LucideRect(0, 0, 0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `mic-off`
  static const LucideIconData micOff = LucideIconData([
      LucidePath("M12 19v3"),
      LucidePath("M15 9.34V5a3 3 0 0 0-5.68-1.33"),
      LucidePath("M16.95 16.95A7 7 0 0 1 5 12v-2"),
      LucidePath("M18.89 13.23A7 7 0 0 0 19 12v-2"),
      LucidePath("m2 2 20 20"),
      LucidePath("M9 9v3a3 3 0 0 0 5.12 2.12"),
  ]);

  /// Source: `lucide-react` `minimize-2`
  static const LucideIconData minimize2 = LucideIconData([
      LucidePath("m14 10 7-7"),
      LucidePath("M20 10h-6V4"),
      LucidePath("m3 21 7-7"),
      LucidePath("M4 14h6v6"),
  ]);

  /// Source: `lucide-react` `moon`
  static const LucideIconData moon = LucideIconData([
      LucidePath("M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401"),
  ]);

  /// Source: `lucide-react` `more-horizontal`
  static const LucideIconData moreHorizontal = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `more-vertical`
  static const LucideIconData moreVertical = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `music`
  static const LucideIconData music = LucideIconData([
      LucidePath("M9 18V5l12-2v13"),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `navigation`
  static const LucideIconData navigation = LucideIconData([
      LucidePolygon(3, 11, 22, 2, 13, 21, 11, 13, 3, 11),
  ]);

  /// Source: `lucide-react` `paintbrush`
  static const LucideIconData paintbrush = LucideIconData([
      LucidePath("m14.622 17.897-10.68-2.913"),
      LucidePath("M18.376 2.622a1 1 0 1 1 3.002 3.002L17.36 9.643a.5.5 0 0 0 0 .707l.944.944a2.41 2.41 0 0 1 0 3.408l-.944.944a.5.5 0 0 1-.707 0L8.354 7.348a.5.5 0 0 1 0-.707l.944-.944a2.41 2.41 0 0 1 3.408 0l.944.944a.5.5 0 0 0 .707 0z"),
      LucidePath("M9 8c-1.804 2.71-3.97 3.46-6.583 3.948a.507.507 0 0 0-.302.819l7.32 8.883a1 1 0 0 0 1.185.204C12.735 20.405 16 16.792 16 15"),
  ]);

  /// Source: `lucide-react` `palette`
  static const LucideIconData palette = LucideIconData([
      LucidePath("M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z"),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `paperclip`
  static const LucideIconData paperclip = LucideIconData([
      LucidePath("m16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551"),
  ]);

  /// Source: `lucide-react` `pause`
  static const LucideIconData pause = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideRect(0, 0, 0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `pause-circle`
  static const LucideIconData pauseCircle = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `pencil`
  static const LucideIconData pencil = LucideIconData([
      LucidePath("M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"),
      LucidePath("m15 5 4 4"),
  ]);

  /// Source: `lucide-react` `phone`
  static const LucideIconData phone = LucideIconData([
      LucidePath("M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384"),
  ]);

  /// Source: `lucide-react` `phone-call`
  static const LucideIconData phoneCall = LucideIconData([
      LucidePath("M13 2a9 9 0 0 1 9 9"),
      LucidePath("M13 6a5 5 0 0 1 5 5"),
      LucidePath("M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384"),
  ]);

  /// Source: `lucide-react` `phone-off`
  static const LucideIconData phoneOff = LucideIconData([
      LucidePath("M10.1 13.9a14 14 0 0 0 3.732 2.668 1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2 18 18 0 0 1-12.728-5.272"),
      LucidePath("M22 2 2 22"),
      LucidePath("M4.76 13.582A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 .244.473"),
  ]);

  /// Source: `lucide-react` `pie-chart`
  static const LucideIconData pieChart = LucideIconData([
      LucidePath("M21 12c.552 0 1.005-.449.95-.998a10 10 0 0 0-8.953-8.951c-.55-.055-.998.398-.998.95v8a1 1 0 0 0 1 1z"),
      LucidePath("M21.21 15.89A10 10 0 1 1 8 2.83"),
  ]);

  /// Source: `lucide-react` `pin`
  static const LucideIconData pin = LucideIconData([
      LucidePath("M12 17v5"),
      LucidePath("M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"),
  ]);

  /// Source: `lucide-react` `pipette`
  static const LucideIconData pipette = LucideIconData([
      LucidePath("m12 9-8.414 8.414A2 2 0 0 0 3 18.828v1.344a2 2 0 0 1-.586 1.414A2 2 0 0 1 3.828 21h1.344a2 2 0 0 0 1.414-.586L15 12"),
      LucidePath("m18 9 .4.4a1 1 0 1 1-3 3l-3.8-3.8a1 1 0 1 1 3-3l.4.4 3.4-3.4a1 1 0 1 1 3 3z"),
      LucidePath("m2 22 .414-.414"),
  ]);

  /// Source: `lucide-react` `play`
  static const LucideIconData play = LucideIconData([
      LucidePath("M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z"),
  ]);

  /// Source: `lucide-react` `play-square`
  static const LucideIconData playSquare = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M9 9.003a1 1 0 0 1 1.517-.859l4.997 2.997a1 1 0 0 1 0 1.718l-4.997 2.997A1 1 0 0 1 9 14.996z"),
  ]);

  /// Source: `lucide-react` `plus`
  static const LucideIconData plus = LucideIconData([
      LucidePath("M5 12h14"),
      LucidePath("M12 5v14"),
  ]);

  /// Source: `lucide-react` `plus-circle`
  static const LucideIconData plusCircle = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M8 12h8"),
      LucidePath("M12 8v8"),
  ]);

  /// Source: `lucide-react` `plus-square`
  static const LucideIconData plusSquare = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M8 12h8"),
      LucidePath("M12 8v8"),
  ]);

  /// Source: `lucide-react` `printer`
  static const LucideIconData printer = LucideIconData([
      LucidePath("M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"),
      LucidePath("M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"),
      LucideRect(0, 0, 0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `qr-code`
  static const LucideIconData qrCode = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M21 16h-3a2 2 0 0 0-2 2v3"),
      LucidePath("M21 21v.01"),
      LucidePath("M12 7v3a2 2 0 0 1-2 2H7"),
      LucidePath("M3 12h.01"),
      LucidePath("M12 3h.01"),
      LucidePath("M12 16v.01"),
      LucidePath("M16 12h1"),
      LucidePath("M21 12v.01"),
      LucidePath("M12 21v-1"),
  ]);

  /// Source: `lucide-react` `quote`
  static const LucideIconData quote = LucideIconData([
      LucidePath("M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z"),
      LucidePath("M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z"),
  ]);

  /// Source: `lucide-react` `radio`
  static const LucideIconData radio = LucideIconData([
      LucidePath("M16.247 7.761a6 6 0 0 1 0 8.478"),
      LucidePath("M19.075 4.933a10 10 0 0 1 0 14.134"),
      LucidePath("M4.925 19.067a10 10 0 0 1 0-14.134"),
      LucidePath("M7.753 16.239a6 6 0 0 1 0-8.478"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `refresh-cw`
  static const LucideIconData refreshCw = LucideIconData([
      LucidePath("M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"),
      LucidePath("M21 3v5h-5"),
      LucidePath("M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"),
      LucidePath("M8 16H3v5"),
  ]);

  /// Source: `lucide-react` `repeat`
  static const LucideIconData repeat = LucideIconData([
      LucidePath("m17 2 4 4-4 4"),
      LucidePath("M3 11v-1a4 4 0 0 1 4-4h14"),
      LucidePath("m7 22-4-4 4-4"),
      LucidePath("M21 13v1a4 4 0 0 1-4 4H3"),
  ]);

  /// Source: `lucide-react` `repeat-2`
  static const LucideIconData repeat2 = LucideIconData([
      LucidePath("m2 9 3-3 3 3"),
      LucidePath("M13 18H7a2 2 0 0 1-2-2V6"),
      LucidePath("m22 15-3 3-3-3"),
      LucidePath("M11 6h6a2 2 0 0 1 2 2v10"),
  ]);

  /// Source: `lucide-react` `reply`
  static const LucideIconData reply = LucideIconData([
      LucidePath("M20 18v-2a4 4 0 0 0-4-4H4"),
      LucidePath("m9 17-5-5 5-5"),
  ]);

  /// Source: `lucide-react` `rotate-ccw`
  static const LucideIconData rotateCcw = LucideIconData([
      LucidePath("M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"),
      LucidePath("M3 3v5h5"),
  ]);

  /// Source: `lucide-react` `rotate-cw`
  static const LucideIconData rotateCw = LucideIconData([
      LucidePath("M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"),
      LucidePath("M21 3v5h-5"),
  ]);

  /// Source: `lucide-react` `scissors`
  static const LucideIconData scissors = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M8.12 8.12 12 12"),
      LucidePath("M20 4 8.12 15.88"),
      LucideCircle(0, 0, 0),
      LucidePath("M14.8 14.8 20 20"),
  ]);

  /// Source: `lucide-react` `search`
  static const LucideIconData search = LucideIconData([
      LucidePath("m21 21-4.34-4.34"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `send`
  static const LucideIconData send = LucideIconData([
      LucidePath("M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z"),
      LucidePath("m21.854 2.147-10.94 10.939"),
  ]);

  /// Source: `lucide-react` `send-horizontal`
  static const LucideIconData sendHorizontal = LucideIconData([
      LucidePath("M3.714 3.048a.498.498 0 0 0-.683.627l2.843 7.627a2 2 0 0 1 0 1.396l-2.842 7.627a.498.498 0 0 0 .682.627l18-8.5a.5.5 0 0 0 0-.904z"),
      LucidePath("M6 12h16"),
  ]);

  /// Source: `lucide-react` `server`
  static const LucideIconData server = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `settings`
  static const LucideIconData settings = LucideIconData([
      LucidePath("M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `settings-2`
  static const LucideIconData settings2 = LucideIconData([
      LucidePath("M14 17H5"),
      LucidePath("M19 7h-9"),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `share`
  static const LucideIconData share = LucideIconData([
      LucidePath("M12 2v13"),
      LucidePath("m16 6-4-4-4 4"),
      LucidePath("M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"),
  ]);

  /// Source: `lucide-react` `share-2`
  static const LucideIconData share2 = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `shield`
  static const LucideIconData shield = LucideIconData([
      LucidePath("M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"),
  ]);

  /// Source: `lucide-react` `shield-alert`
  static const LucideIconData shieldAlert = LucideIconData([
      LucidePath("M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"),
      LucidePath("M12 8v4"),
      LucidePath("M12 16h.01"),
  ]);

  /// Source: `lucide-react` `shield-check`
  static const LucideIconData shieldCheck = LucideIconData([
      LucidePath("M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"),
      LucidePath("m9 12 2 2 4-4"),
  ]);

  /// Source: `lucide-react` `sliders`
  static const LucideIconData sliders = LucideIconData([
      LucidePath("M10 8h4"),
      LucidePath("M12 21v-9"),
      LucidePath("M12 8V3"),
      LucidePath("M17 16h4"),
      LucidePath("M19 12V3"),
      LucidePath("M19 21v-5"),
      LucidePath("M3 14h4"),
      LucidePath("M5 10V3"),
      LucidePath("M5 21v-7"),
  ]);

  /// Source: `lucide-react` `smartphone`
  static const LucideIconData smartphone = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucidePath("M12 18h.01"),
  ]);

  /// Source: `lucide-react` `smile`
  static const LucideIconData smile = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M8 14s1.5 2 4 2 4-2 4-2"),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `sparkles`
  static const LucideIconData sparkles = LucideIconData([
      LucidePath("M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z"),
      LucidePath("M20 2v4"),
      LucidePath("M22 4h-4"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `star`
  static const LucideIconData star = LucideIconData([
      LucidePath("M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"),
  ]);

  /// Source: `lucide-react` `sticker`
  static const LucideIconData sticker = LucideIconData([
      LucidePath("M15.5 3H5a2 2 0 0 0-2 2v14c0 1.1.9 2 2 2h14a2 2 0 0 0 2-2V8.5L15.5 3Z"),
      LucidePath("M14 3v4a2 2 0 0 0 2 2h4"),
      LucidePath("M8 13h.01"),
      LucidePath("M16 13h.01"),
      LucidePath("M10 16s.8 1 2 1c1.3 0 2-1 2-1"),
  ]);

  /// Source: `lucide-react` `strikethrough`
  static const LucideIconData strikethrough = LucideIconData([
      LucidePath("M16 4H9a3 3 0 0 0-2.83 4"),
      LucidePath("M14 12a4 4 0 0 1 0 8H6"),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `sun`
  static const LucideIconData sun = LucideIconData([
      LucideCircle(0, 0, 0),
      LucidePath("M12 2v2"),
      LucidePath("M12 20v2"),
      LucidePath("m4.93 4.93 1.41 1.41"),
      LucidePath("m17.66 17.66 1.41 1.41"),
      LucidePath("M2 12h2"),
      LucidePath("M20 12h2"),
      LucidePath("m6.34 17.66-1.41 1.41"),
      LucidePath("m19.07 4.93-1.41 1.41"),
  ]);

  /// Source: `lucide-react` `switch-camera`
  static const LucideIconData switchCamera = LucideIconData([
      LucidePath("M11 19H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h5"),
      LucidePath("M13 5h7a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-5"),
      LucideCircle(0, 0, 0),
      LucidePath("m18 22-3-3 3-3"),
      LucidePath("m6 2 3 3-3 3"),
  ]);

  /// Source: `lucide-react` `trash-2`
  static const LucideIconData trash2 = LucideIconData([
      LucidePath("M10 11v6"),
      LucidePath("M14 11v6"),
      LucidePath("M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"),
      LucidePath("M3 6h18"),
      LucidePath("M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"),
  ]);

  /// Source: `lucide-react` `trending-up`
  static const LucideIconData trendingUp = LucideIconData([
      LucidePath("M16 7h6v6"),
      LucidePath("m22 7-8.5 8.5-5-5L2 17"),
  ]);

  /// Source: `lucide-react` `type`
  static const LucideIconData type = LucideIconData([
      LucidePath("M12 4v16"),
      LucidePath("M4 7V5a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v2"),
      LucidePath("M9 20h6"),
  ]);

  /// Source: `lucide-react` `underline`
  static const LucideIconData underline = LucideIconData([
      LucidePath("M6 4v6a6 6 0 0 0 12 0V4"),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `undo-2`
  static const LucideIconData undo2 = LucideIconData([
      LucidePath("M9 14 4 9l5-5"),
      LucidePath("M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11"),
  ]);

  /// Source: `lucide-react` `upload`
  static const LucideIconData upload = LucideIconData([
      LucidePath("M12 3v12"),
      LucidePath("m17 8-5-5-5 5"),
      LucidePath("M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"),
  ]);

  /// Source: `lucide-react` `upload-cloud`
  static const LucideIconData uploadCloud = LucideIconData([
      LucidePath("M12 13v8"),
      LucidePath("M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"),
      LucidePath("m8 17 4-4 4 4"),
  ]);

  /// Source: `lucide-react` `user`
  static const LucideIconData user = LucideIconData([
      LucidePath("M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `user-check`
  static const LucideIconData userCheck = LucideIconData([
      LucidePath("m16 11 2 2 4-4"),
      LucidePath("M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `user-minus`
  static const LucideIconData userMinus = LucideIconData([
      LucidePath("M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"),
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `user-plus`
  static const LucideIconData userPlus = LucideIconData([
      LucidePath("M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"),
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `user-square`
  static const LucideIconData userSquare = LucideIconData([
      LucideRect(0, 0, 0, 0, 0, 0),
      LucideCircle(0, 0, 0),
      LucidePath("M7 21v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2"),
  ]);

  /// Source: `lucide-react` `user-x`
  static const LucideIconData userX = LucideIconData([
      LucidePath("M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"),
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `users`
  static const LucideIconData users = LucideIconData([
      LucidePath("M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"),
      LucidePath("M16 3.128a4 4 0 0 1 0 7.744"),
      LucidePath("M22 21v-2a4 4 0 0 0-3-3.87"),
      LucideCircle(0, 0, 0),
  ]);

  /// Source: `lucide-react` `video`
  static const LucideIconData video = LucideIconData([
      LucidePath("m16 13 5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5"),
      LucideRect(0, 0, 0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `video-off`
  static const LucideIconData videoOff = LucideIconData([
      LucidePath("M10.66 6H14a2 2 0 0 1 2 2v2.5l5.248-3.062A.5.5 0 0 1 22 7.87v8.196"),
      LucidePath("M16 16a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2"),
      LucidePath("m2 2 20 20"),
  ]);

  /// Source: `lucide-react` `volume-2`
  static const LucideIconData volume2 = LucideIconData([
      LucidePath("M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"),
      LucidePath("M16 9a5 5 0 0 1 0 6"),
      LucidePath("M19.364 18.364a9 9 0 0 0 0-12.728"),
  ]);

  /// Source: `lucide-react` `volume-x`
  static const LucideIconData volumeX = LucideIconData([
      LucidePath("M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `wand-2`
  static const LucideIconData wand2 = LucideIconData([
      LucidePath("m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72"),
      LucidePath("m14 7 3 3"),
      LucidePath("M5 6v4"),
      LucidePath("M19 14v4"),
      LucidePath("M10 2v2"),
      LucidePath("M7 8H3"),
      LucidePath("M21 16h-4"),
      LucidePath("M11 3H9"),
  ]);

  /// Source: `lucide-react` `x`
  static const LucideIconData x = LucideIconData([
      LucidePath("M18 6 6 18"),
      LucidePath("m6 6 12 12"),
  ]);

  /// Source: `lucide-react` `zap`
  static const LucideIconData zap = LucideIconData([
      LucidePath("M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"),
  ]);

  /// Source: `lucide-react` `zap-off`
  static const LucideIconData zapOff = LucideIconData([
      LucidePath("M10.513 4.856 13.12 2.17a.5.5 0 0 1 .86.46l-1.377 4.317"),
      LucidePath("M15.656 10H20a1 1 0 0 1 .78 1.63l-1.72 1.773"),
      LucidePath("M16.273 16.273 10.88 21.83a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14H4a1 1 0 0 1-.78-1.63l4.507-4.643"),
      LucidePath("m2 2 20 20"),
  ]);

  /// Source: `lucide-react` `zoom-in`
  static const LucideIconData zoomIn = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);

  /// Source: `lucide-react` `zoom-out`
  static const LucideIconData zoomOut = LucideIconData([
      LucideCircle(0, 0, 0),
      LucideLine(0, 0, 0, 0),
      LucideLine(0, 0, 0, 0),
  ]);
}
