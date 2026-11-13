// ============================================================================
//  ENNVO — CHAT BUBBLE
//
//  Ported from the bubble logic in `src/pages/Messages.tsx`.
//
//  Geometry:
//    • every bubble is `rounded-3xl` (24px)
//    • the last bubble of a group gets a squared tail corner:
//      `rounded-tr-md` for mine, `rounded-tl-md` for theirs
//    • mine  → `bg-sky-500`, white text
//    • theirs → `bg-[#F2F4F7]` in light mode, `bg-[#27272A]` in dark
//
//  The read receipt lives in a *fixed height slot below the list*, not
//  inside the bubble, exactly as the web app does — otherwise the list
//  jumps when the last message changes.
// ============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isLastInGroup,
    this.showReply,
  });

  final AppMessage message;
  final bool isMine;
  final bool isLastInGroup;

  /// The message this one replies to.
  final AppMessage? showReply;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chatText = isMine ? t.chatTextMine : t.chatTextTheirs;
    final chatBackground = isMine ? t.chatBubbleMine : t.chatBubbleTheirs;

    // The tail corner is squared on the last bubble of a group.
    final radius = BorderRadius.only(
      topLeft: Radius.circular(
        !isMine && isLastInGroup ? AppRadius.md : AppRadius.xxl,
      ),
      topRight: Radius.circular(
        isMine && isLastInGroup ? AppRadius.md : AppRadius.xxl,
      ),
      bottomLeft: Radius.circular(AppRadius.xxl),
      bottomRight: Radius.circular(AppRadius.xxl),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 56 : 12,
        right: isMine ? 12 : 56,
        top: 2,
        bottom: isLastInGroup ? 8 : 2,
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showReply != null)
            _ReplyPreview(
              reply: showReply!,
              isMine: isMine,
              textColor: t.textSecondary,
            ),
          Container(
            decoration: BoxDecoration(
              color: chatBackground,
              borderRadius: radius,
            ),
            child: _Content(
              message: message,
              textColor: chatText,
              isMine: isMine,
            ),
          ),
        ],
      ),
    );
  }
}

/// The body of the bubble, switched on the message type.
class _Content extends StatelessWidget {
  const _Content({
    required this.message,
    required this.textColor,
    required this.isMine,
  });

  final AppMessage message;
  final Color textColor;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
      case MessageType.album:
        return _MediaBubble(message: message, isMine: isMine);
      case MessageType.video:
      case MessageType.reel:
        return _MediaBubble(message: message, isMine: isMine);
      case MessageType.sticker:
        return Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 120,
            height: 120,
            child: message.stickerUrl == null || message.stickerUrl!.isEmpty
                ? const SizedBox.shrink()
                : Image.network(
                    message.stickerUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        );
      case MessageType.voice:
        return _VoiceBubble(message: message, textColor: textColor);
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: EnnvoText.caption.copyWith(
              color: const Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
        );
      case MessageType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            message.content,
            style: EnnvoText.body.copyWith(
              color: textColor,
              fontSize: 14.5,
            ),
          ),
        );
    }
  }
}

class _MediaBubble extends StatelessWidget {
  const _MediaBubble({required this.message, required this.isMine});

  final AppMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ??
        (message.mediaUrls.isNotEmpty ? message.mediaUrls.first : '');
    if (url.isEmpty) return const SizedBox(width: 200, height: 200);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Image.network(
        url,
        width: 220,
        height: 220,
        fit: BoxFit.cover,
        cacheWidth: 600,
        errorBuilder: (_, __, ___) => Container(
          width: 220,
          height: 220,
          color: const Color(0xFF1F2937),
          child: const Icon(Icons.broken_image_outlined, color: Colors.white24),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.message, required this.textColor});

  final AppMessage message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final seconds = message.voiceDuration ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.play_arrow_rounded, size: 20, color: textColor),
          ),
          const SizedBox(width: 10),
          // A simple waveform placeholder.
          SizedBox(
            width: 90,
            height: 24,
            child: CustomPaint(painter: _WaveformPainter(color: textColor)),
          ),
          const SizedBox(width: 8),
          Text(
            '${seconds}s',
            style: EnnvoText.caption.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const bars = 18;
    final barWidth = size.width / bars;
    for (var i = 0; i < bars; i++) {
      // A deterministic pseudo waveform.
      final t = (i % 6) / 6.0;
      final height = 6 + (t * (size.height - 6));
      final x = barWidth * i + barWidth / 2;
      canvas.drawLine(
        Offset(x, size.height - height),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => oldDelegate.color != color;
}

/// The reply preview shown above the bubble.
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.reply,
    required this.isMine,
    required this.textColor,
  });

  final AppMessage reply;
  final bool isMine;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0xFF1C1C22) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white70 : t.accent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderId.isEmpty ? 'Message' : 'Reply',
            style: EnnvoText.tiny.copyWith(
              color: isMine ? Colors.white70 : t.accent,
              fontSize: 11,
            ),
          ),
          Text(
            reply.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EnnvoText.tiny.copyWith(color: textColor, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The typing indicator — three bouncing dots
// ============================================================================
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.color});

  final Color? color;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dotColor = widget.color ?? const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: t.chatBubbleTheirs,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Dot(
                    controller: _controller,
                    index: i,
                    color: dotColor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.controller,
    required this.index,
    required this.color,
  });

  final AnimationController controller;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // The web app uses delays of 0, 0.16s and 0.32s.
    final phase = (controller.value - index * 0.128) % 1.0;
    final wave = (0.5 - (phase - 0.5).abs()) * 2;

    return Transform.translate(
      offset: Offset(0, -4 * wave.clamp(0.0, 1.0)),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35 + (0.65 * wave.clamp(0.0, 1.0))),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The read receipt, drawn in a fixed slot below the message list.
class ReadReceipt extends StatelessWidget {
  const ReadReceipt({super.key, required this.status, required this.isMine});

  final MessageStatus status;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (!isMine) return const SizedBox(height: 16);

    final seen = status == MessageStatus.seen;
    final color = seen ? const Color(0xFF38BDF8) : const Color(0xFF9CA3AF);

    return SizedBox(
      height: 16,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              seen ? Icons.done_all_rounded : Icons.done_rounded,
              size: 14,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
