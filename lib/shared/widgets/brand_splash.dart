// ============================================================================
//  ENNVO — BRAND SPLASH
//
//  The mark of the app: the Ennvo logo on the black the app opens on.
//
//  It is used in two places, and both of them used to look like a loading
//  screen the user had to sit through:
//
//    • the launch screen, while the persisted session is restored
//    • the reels placeholder, while the first video is being prepared
//
//  The mark breathes gently instead of spinning, which reads as "the app is
//  alive" rather than "something is loading".
// ============================================================================

import 'package:flutter/material.dart';

/// The path of the brand mark inside the asset bundle.
const String kEnnvoLogoAsset = 'assets/brand/ennvo_logo.png';

class EnnvoBrandMark extends StatefulWidget {
  const EnnvoBrandMark({
    super.key,
    this.size = 96,
    this.pulse = true,
    this.glow = true,
  });

  /// The width and the height of the mark.
  final double size;

  /// Whether the mark breathes.
  final bool pulse;

  /// Whether a soft halo sits behind the mark.
  final bool glow;

  @override
  State<EnnvoBrandMark> createState() => _EnnvoBrandMarkState();
}

class _EnnvoBrandMarkState extends State<EnnvoBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant EnnvoBrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        kEnnvoLogoAsset,
        fit: BoxFit.contain,
        // A missing asset must never break the launch screen.
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.pulse ? _controller.value : 0.0;
          return Transform.scale(
            scale: 0.96 + (0.06 * t),
            child: Opacity(
              opacity: 0.78 + (0.22 * t),
              child: child,
            ),
          );
        },
        child: widget.glow
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.size / 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                      blurRadius: widget.size * 0.42,
                      spreadRadius: widget.size * 0.04,
                    ),
                  ],
                ),
                child: mark,
              )
            : mark,
      ),
    );
  }
}
