// ============================================================================
//  ENNVO — CUSTOM NAVIGATION ICONS
//
//  The web app ships eight hand-drawn SVG navigation icons in
//  `src/components/NavIcons.tsx` (not Lucide — these were matched against
//  Flaticon references). The path data below is copied verbatim from that
//  file so the native bottom navigation is pixel-identical to the web build.
//
//  Rendering is done with a [CustomPainter] over cached [Path] objects
//  instead of an SVG package: the bottom navigation rebuilds on every tab
//  change, and eight cached paths cost nothing to paint.
// ============================================================================

import 'package:flutter/material.dart';

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

class EnnvoNavIconPainter extends CustomPainter {
  const EnnvoNavIconPainter({
    required this.icon,
    required this.color,
    required this.filled,
    this.strokeWidth = 2.2,
  });

  final EnnvoNavIcon icon;
  final Color color;
  final bool filled;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale * scale // stroke scales with the icon
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (icon) {
      case EnnvoNavIcon.home:
        _paintHome(canvas, paint);
      case EnnvoNavIcon.feed:
        _paintFeed(canvas, paint);
      case EnnvoNavIcon.message:
        _paintMessage(canvas, paint);
      case EnnvoNavIcon.create:
        _paintCreate(canvas, paint);
      case EnnvoNavIcon.search:
        _paintSearch(canvas, paint);
      case EnnvoNavIcon.notification:
        _paintNotification(canvas, paint);
      case EnnvoNavIcon.profile:
        _paintProfile(canvas, paint);
      case EnnvoNavIcon.settings:
        _paintSettings(canvas, paint);
    }

    canvas.restore();
  }

  // --- 1. Home -----------------------------------------------------------
  // "Rounded house roof with soft curved archway door"
  static const String _homePath =
      'M10.87 2.45c.67-.58 1.59-.58 2.26 0l7.25 6.34c.77.68 1.12 1.7.92 '
      '2.7l-1.3 6.51A3.25 3.25 0 0 1 16.81 21H14.5a1.25 1.25 0 0 1-1.25-1.25'
      'V15.5a1.25 1.25 0 0 0-2.5 0v4.25c0 .69-.56 1.25-1.25 1.25H7.19a3.25 '
      '3.25 0 0 1-3.19-3l-1.3-6.51a3.25 3.25 0 0 1 .92-2.7L10.87 2.45Z';

  void _paintHome(Canvas canvas, Paint paint) {
    final path = Path.parseSvgPathData(_homePath)!..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  // --- 2. Feed -----------------------------------------------------------
  // "Modern rounded feed card with top pill tab and inner rounded square"
  void _paintFeed(Canvas canvas, Paint paint) {
    final outer = Path()
      ..addRRect(
        RRect.fromLTRBR(3.5, 2.5, 20.5, 21.5, const Radius.circular(5.2)),
      );
    canvas.drawPath(outer, paint);

    final pill = Path()
      ..moveTo(7.5, 6.8)
      ..lineTo(13.0, 6.8);
    canvas.drawPath(
      pill,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = filled ? 2.6 : 2.3,
    );

    final inner = Path()
      ..addRRect(
        RRect.fromLTRBR(6.5, 10.5, 17.5, 18.5, const Radius.circular(2.8)),
      );
    canvas.drawPath(
      inner,
      paint
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = filled ? 1.5 : 2.0,
    );
  }

  // --- 3. Message --------------------------------------------------------
  // "Soft rounded direct message paper plane / send arrow"
  static const String _messagePath =
      'M7.4 6.32l8.49-3.85c3.81-1.72 5.88.36 4.17 4.17l-3.85 8.49c-1.9 '
      '4.21-5.01 4.21-6.91 0l-1.15-2.54-2.54-1.15c-4.2-1.9-4.2-5 0-6.9l1.79'
      '-1.78v.56z';
  static const String _messageInner = 'M8.33 12.18l3.74-3.75';

  void _paintMessage(Canvas canvas, Paint paint) {
    canvas.drawPath(Path.parseSvgPathData(_messagePath)!, paint);
    if (!filled) {
      canvas.drawPath(Path.parseSvgPathData(_messageInner)!, paint);
    }
  }

  // --- 4. Create ---------------------------------------------------------
  void _paintCreate(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..addRRect(
          RRect.fromLTRBR(3, 3, 21, 21, const Radius.circular(6)),
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 8)
        ..lineTo(12, 16),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8, 12)
        ..lineTo(16, 12),
      paint,
    );
  }

  // --- 5. Search ---------------------------------------------------------
  void _paintSearch(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..addOval(const Rect.fromCircle(center: Offset(11, 11), radius: 7.5)),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20.5, 20.5)
        ..lineTo(16.3, 16.3),
      paint
        ..strokeWidth = filled ? 2.8 : 2.4,
    );
  }

  // --- 6. Notification ---------------------------------------------------
  static const String _bellPath =
      'M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9';
  static const String _bellClapper = 'M13.73 21a2 2 0 0 1-3.46 0';
  static const String _bellFilled =
      'M12 2a6.5 6.5 0 0 0-6.5 6.5v3.2c0 .9-.38 1.77-1.04 2.39L3.4 15.1c'
      '-.96.9-.32 2.5 1 2.5h15.2c1.32 0 1.96-1.6 1-2.5l-1.06-1.01c-.66'
      '-.62-1.04-1.49-1.04-2.39V8.5A6.5 6.5 0 0 0 12 2zm0 20a3 3 0 0 1-2.83-2h5.66'
      'A3 3 0 0 1 12 22z';

  void _paintNotification(Canvas canvas, Paint paint) {
    if (filled) {
      canvas.drawPath(Path.parseSvgPathData(_bellFilled)!, paint);
    } else {
      canvas.drawPath(Path.parseSvgPathData(_bellPath)!, paint);
      canvas.drawPath(Path.parseSvgPathData(_bellClapper)!, paint);
    }
  }

  // --- 7. Profile --------------------------------------------------------
  static const String _profileFilled =
      'M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2.5c-4.42 0-8 2.24-8 5v1.25'
      'c0 .69.56 1.25 1.25 1.25h13.5c.69 0 1.25-.56 1.25-1.25V19.5c0-2.76'
      '-3.58-5-8-5z';

  void _paintProfile(Canvas canvas, Paint paint) {
    if (filled) {
      canvas.drawPath(Path.parseSvgPathData(_profileFilled)!, paint);
    } else {
      canvas.drawPath(
        Path()
          ..addOval(const Rect.fromCircle(center: Offset(12, 7.5), radius: 4.5)),
        paint,
      );
      canvas.drawPath(
        Path.parseSvgPathData(
          'M4.5 20.5c0-3.5 3.36-6.5 7.5-6.5s7.5 3 7.5 6.5',
        )!,
        paint,
      );
    }
  }

  // --- 8. Settings -------------------------------------------------------
  static const String _gearPath =
      'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 '
      '0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 '
      '1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82 '
      '.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 '
      '.33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 '
      '1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 '
      '0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 '
      '2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 '
      '1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 '
      '0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 '
      '1.65 0 0 0-1.51 1z';

  void _paintSettings(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..addOval(const Rect.fromCircle(center: Offset(12, 12), radius: 3)),
      paint,
    );
    canvas.drawPath(Path.parseSvgPathData(_gearPath)!, paint);
  }

  @override
  bool shouldRepaint(EnnvoNavIconPainter oldDelegate) {
    return oldDelegate.icon != icon ||
        oldDelegate.color != color ||
        oldDelegate.filled != filled ||
        oldDelegate.strokeWidth != strokeWidth;
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
    this.strokeWidth = 2.2,
  });

  final EnnvoNavIcon icon;
  final Color color;
  final double size;
  final bool filled;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: EnnvoNavIconPainter(
            icon: icon,
            color: color,
            filled: filled,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}
