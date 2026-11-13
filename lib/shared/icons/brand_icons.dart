// ============================================================================
//  ENNVO — BRAND ICONS
//
//  Inline SVG brand marks used by the auth screen, ported from the web
//  app's inline `<svg>` elements in `src/pages/Auth.tsx`.
// ============================================================================

import 'package:flutter/material.dart';

/// The four colour Google "G".
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(painter: _GoogleLogoPainter()),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale);

    void draw(String d, Color color) {
      final path = Path.parseSvgPathData(d);
      if (path == null) return;
      canvas.drawPath(path, Paint()..color = color);
    }

    draw(
      'M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 '
      '5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z',
      const Color(0xFF4285F4),
    );
    draw(
      'M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 '
      '2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 '
      '15.4 46 24 46z',
      const Color(0xFF34A853),
    );
    draw(
      'M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 '
      '17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z',
      const Color(0xFFFBBC05),
    );
    draw(
      'M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 '
      '15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z',
      const Color(0xFFEA4335),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}

/// The Facebook "f" mark.
class FacebookLogo extends StatelessWidget {
  const FacebookLogo({super.key, this.size = 18, this.color = const Color(0xFF1877F2)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(painter: _FacebookLogoPainter(color)),
      ),
    );
  }
}

class _FacebookLogoPainter extends CustomPainter {
  const _FacebookLogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);
    final path = Path.parseSvgPathData(
      'M22 12.06C22 6.5 17.52 2 12 2S2 6.5 2 12.06C2 17.08 5.66 21.25 10.44 '
      '22v-7.03H7.9v-2.91h2.54V9.85c0-2.52 1.49-3.91 3.77-3.91 1.1 0 2.24.2 '
      '2.24.2v2.47h-1.26c-1.24 0-1.63.78-1.63 1.57v1.88h2.78l-.44 2.91h-2.34V22'
      'C18.34 21.25 22 17.08 22 12.06z',
    );
    if (path != null) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacebookLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The Ennvo app mark — the gradient circle with the "e" glyph.
class EnnvoAppLogo extends StatelessWidget {
  const EnnvoAppLogo({super.key, this.size = 76, this.ring = true});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF2563EB)],
          ),
          boxShadow: ring
              ? [
                  const BoxShadow(
                    color: Color(0x5938BDF8),
                    blurRadius: 25,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            'e',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: size * 0.56,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
        ),
      ),
    );
  }
}
