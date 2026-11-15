// ============================================================================
//  ENNVO — SONG MARQUEE
//
//  The name of the song under a post or a reel.
//
//  The name is measured, drawn twice and moved from one side to the other,
//  and the whole thing is clipped and faded at both edges. Without the clip
//  the name runs out of its pill and all the way across the screen, which
//  is what the old version did.
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../icons/lucide_icons.dart';

class EnnvoSongMarquee extends StatefulWidget {
  const EnnvoSongMarquee({
    super.key,
    required this.title,
    this.artist = '',
    this.width = 150,
    this.textColor = Colors.white,
    this.background,
    this.borderColor,
    this.iconColor,
    this.showIcon = true,
    this.duration = const Duration(seconds: 9),
  });

  /// The name of the song.
  final String title;

  /// The artist, when the song has one.
  final String artist;

  /// How much of the name is on screen at once.
  final double width;

  final Color textColor;
  final Color? background;
  final Color? borderColor;
  final Color? iconColor;
  final bool showIcon;

  /// How long one pass of the name takes.
  final Duration duration;

  /// `title · artist`, the way the web app writes it.
  String get label => artist.isEmpty ? title : '$title · $artist';

  @override
  State<EnnvoSongMarquee> createState() => _EnnvoSongMarqueeState();
}

class _EnnvoSongMarqueeState extends State<EnnvoSongMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  /// The space between the two copies of the name.
  static const double _gap = 32;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    if (label.isEmpty) return const SizedBox.shrink();

    final style = EnnvoText.caption.copyWith(
      color: widget.textColor,
      fontSize: 12.5,
    );

    // The width of the name decides how far it travels.
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final textWidth = painter.width;
    painter.dispose();

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 16, 7),
      decoration: BoxDecoration(
        color: widget.background ?? Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: widget.borderColor ?? Colors.white.withValues(alpha: 0.6),
          width: 1.25,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon) ...[
            LucideIcon(
              LucideIcons.music,
              size: 15,
              strokeWidth: 1.7,
              color: widget.iconColor ?? widget.textColor,
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: widget.width,
            height: 18,
            child: ClipRect(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0, 0.08, 0.92, 1],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    // The two copies move together, so the pass loops
                    // without a jump.
                    final dx = -(textWidth + _gap) * _controller.value;
                    return Stack(
                      children: [
                        Positioned(
                          left: dx,
                          top: 0,
                          child: Text(label, style: style),
                        ),
                        Positioned(
                          left: dx + textWidth + _gap,
                          top: 0,
                          child: Text(label, style: style),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
