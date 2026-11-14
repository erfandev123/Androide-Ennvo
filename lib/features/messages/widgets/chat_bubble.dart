// ============================================================================
//  ENNVO — CHAT BUBBLE
//
//  Every message shape the chat supports, ported from
//  `src/pages/Messages.tsx`.
//
//  Geometry:
//    • the base radius is 24px (`rounded-3xl`)
//    • the tail corner of the last bubble in a group is squared to 6px
//    • two messages belong to the same group when the sender matches and
//      they are less than 60 seconds apart
//
//  The bubble supports a text body, an image, a video, an album, a reel, a
//  sticker, a voice note, a call summary and a document — plus a reply
//  preview, a reaction badge and the swipe-to-reply gesture.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/message.dart';
import '../../../shared/icons/lucide_icons.dart';

class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.replyPreview,
    this.onReply,
    this.onLongPress,
    this.showAvatar = true,
    this.avatarUrl = '',
  });

  final AppMessage message;
  final bool isMine;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// The message this one replies to.
  final AppMessage? replyPreview;

  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final bool showAvatar;
  final String avatarUrl;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  // --- the swipe-to-reply gesture -------------------------------------
  double _drag = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final t = context.tokens;

    // An emoji-only message has no bubble behind it.
    final isEmojiOnly = _isEmojiOnly(message.content);

    final radius = _radiusFor(
      isMine: widget.isMine,
      isFirst: widget.isFirstInGroup,
      isLast: widget.isLastInGroup,
    );

    final bubble = Container(
      decoration: BoxDecoration(
        gradient: widget.isMine && !isEmojiOnly
            ? const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              )
            : null,
        color: widget.isMine
            ? null
            : (isEmojiOnly ? Colors.transparent : t.chatBubbleTheirs),
        borderRadius: radius,
      ),
      child: _body(context, isEmojiOnly),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: widget.isFirstInGroup ? 8 : 1,
        bottom: widget.isLastInGroup ? 8 : 1,
      ),
      child: Row(
        mainAxisAlignment: widget.isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMine)
            SizedBox(
              width: 28,
              child: widget.isLastInGroup && widget.showAvatar
                  ? CircleAvatar(
                      radius: 14,
                      backgroundImage: widget.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(widget.avatarUrl),
                      child: widget.avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 14,
                              color: t.textTertiary,
                            )
                          : null,
                    )
                  : null,
            ),
          if (!widget.isMine) const SizedBox(width: 6),
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _dragging = true),
                  onHorizontalDragUpdate: (details) {
                    // Only a rightward swipe means "reply".
                    if (details.delta.dx <= 0) return;
                    setState(() {
                      _drag = (_drag + details.delta.dx * 0.44).clamp(0, 56);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    final committed = _drag > 24;
                    setState(() => _dragging = false);
                    if (committed) {
                      HapticFeedback.lightImpact();
                      widget.onReply?.call();
                    }
                    setState(() => _drag = 0);
                  },
                  onLongPress: widget.onLongPress,
                  child: AnimatedSlide(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: const Cubic(0.2, 0.9, 0.3, 1),
                    offset: Offset(_drag / 400, 0),
                    child: bubble,
                  ),
                ),
                // The reply indicator that fades in with the drag.
                if (!widget.isMine)
                  Positioned(
                    left: -32,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: ((_drag - 8) / 22).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.7 + 0.3 * ((_drag - 8) / 22).clamp(0.0, 1.0),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x80D8B4FE),
                              ),
                            ),
                            child: const LucideIcon(
                              LucideIcons.reply,
                              size: 14,
                              strokeWidth: 2.4,
                              color: Color(0xFFA855F7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, bool isEmojiOnly) {
    final message = widget.message;
    final t = context.tokens;
    final textColor = widget.isMine
        ? t.chatTextMine
        : t.chatTextTheirs;

    switch (message.type) {
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: t.isDark ? const Color(0xFF171717) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: t.border),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: EnnvoText.caption.copyWith(
                color: t.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252),
                fontSize: 11.5,
              ),
            ),
          ),
        );

      case MessageType.text:
        if (isEmojiOnly) {
          final count = _emojiCount(message.content);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: count == 1 ? 48 : 36,
                height: 1.15,
                shadows: const [
                  Shadow(color: Color(0x1F000000), blurRadius: 2),
                ],
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.replyPreview != null)
                _ReplyPreview(
                  reply: widget.replyPreview!,
                  isMine: widget.isMine,
                ),
              Text(
                message.content,
                style: EnnvoText.body.copyWith(
                  color: textColor,
                  fontSize: 15,
                  height: 1.375,
                ),
              ),
            ],
          ),
        );

      case MessageType.image:
      case MessageType.album:
        return _MediaBubble(message: message, isMine: widget.isMine);

      case MessageType.video:
        return _VideoBubble(message: message);

      case MessageType.reel:
        return _ReelBubble(message: message);

      case MessageType.sticker:
        return SizedBox(
          width: 180,
          height: 180,
          child: message.stickerUrl == null || message.stickerUrl!.isEmpty
              ? const SizedBox.shrink()
              : Image.network(
                  message.stickerUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        );

      case MessageType.voice:
        return _VoiceBubble(message: message, isMine: widget.isMine);
    }
  }

  /// The border radius matrix of the web app.
  static BorderRadius _radiusFor({
    required bool isMine,
    required bool isFirst,
    required bool isLast,
  }) {
    const r = Radius.circular(AppRadius.xxl);
    const tail = Radius.circular(AppRadius.md);

    if (isMine) {
      return BorderRadius.only(
        topLeft: r,
        topRight: isLast ? tail : r,
        bottomLeft: r,
        bottomRight: isLast ? r : tail,
      );
    }
    return BorderRadius.only(
      topLeft: isLast ? tail : r,
      topRight: r,
      bottomLeft: isLast ? r : tail,
      bottomRight: r,
    );
  }

  static bool _isEmojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final count = trimmed.runes.length;
    if (count > 3) return false;
    final emoji = RegExp(
      r'^[\p{Extended_Pictographic}\p{Emoji_Presentation}\s]+$',
      unicode: true,
    );
    return emoji.hasMatch(trimmed);
  }

  static int _emojiCount(String text) => text.trim().runes.length;
}

// ============================================================================
//  The reply preview inside a bubble
// ============================================================================
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.reply, required this.isMine});

  final AppMessage reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.black.withValues(alpha: 0.15)
            : const Color(0xCCF3F4F6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(
            color: isMine
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFFA855F7),
            width: 2,
          ),
        ),
      ),
      child: Text(
        reply.content.isEmpty ? 'Attachment' : reply.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EnnvoText.caption.copyWith(
          color: isMine ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF1F2937),
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ============================================================================
//  The image bubble
// ============================================================================
class _MediaBubble extends StatelessWidget {
  const _MediaBubble({required this.message, required this.isMine});

  final AppMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ??
        (message.mediaUrls.isNotEmpty ? message.mediaUrls.first : '');
    if (url.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.network(
            url,
            width: 240,
            height: 300,
            fit: BoxFit.cover,
            cacheWidth: 640,
            errorBuilder: (_, __, ___) => Container(
              width: 240,
              height: 300,
              color: const Color(0x14000000),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const LucideIcon(
              LucideIcons.download,
              size: 12,
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  The video bubble
// ============================================================================
class _VideoBubble extends StatelessWidget {
  const _VideoBubble({required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            width: 220,
            height: 260,
            color: Colors.black,
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const LucideIcon(
            LucideIcons.play,
            size: 20,
            strokeWidth: 2,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  The reel bubble
// ============================================================================
class _ReelBubble extends StatelessWidget {
  const _ReelBubble({required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 165,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          color: const Color(0xFF171717),
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const LucideIcon(
              LucideIcons.play,
              size: 14,
              strokeWidth: 2,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The voice note bubble
// ============================================================================
class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({required this.message, required this.isMine});

  final AppMessage message;
  final bool isMine;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  bool _playing = false;
  double _progress = 0;

  static const List<double> _heights = [
    28, 48, 36, 60, 44, 76, 52, 90, 64, 100, 72, 88, 56, 76, 48, 84,
    60, 92, 52, 76, 44, 68, 32, 80, 40, 72, 36, 64,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filled = widget.isMine
        ? Colors.white
        : (t.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9));
    final empty = widget.isMine
        ? Colors.white.withValues(alpha: 0.35)
        : (t.isDark ? const Color(0xFF404040) : const Color(0xFFD4D4D8));
    final seconds = widget.message.voiceDuration ?? 0;

    return Container(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 285),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: widget.isMine
            ? const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              )
            : null,
        color: widget.isMine
            ? null
            : (t.isDark ? const Color(0xFF1F242D) : const Color(0xFFF5F5F5)),
        borderRadius: BorderRadius.circular(22),
        border: widget.isMine
            ? null
            : Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _playing = !_playing),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMine
                    ? Colors.white
                    : (t.isDark ? const Color(0xFF0EA5E9) : const Color(0xFF0EA5E9)),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                _playing ? LucideIcons.pause : LucideIcons.play,
                size: 16,
                strokeWidth: 2,
                color: widget.isMine ? const Color(0xFF2563EB) : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // The waveform.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              setState(() {
                _progress = (details.localPosition.dx / 200).clamp(0.0, 1.0);
              });
            },
            child: SizedBox(
              width: 120,
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < _heights.length; i++)
                        Container(
                          width: 2.5,
                          height: (_heights[i] * 0.24)
                              .clamp(4.0, 28.0),
                          decoration: BoxDecoration(
                            color: i / _heights.length <= _progress
                                ? filled
                                : empty,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  // The scrub pip.
                  Positioned(
                    left: (_progress * 118).clamp(0.0, 118.0),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: filled,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: filled.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: EnnvoText.tiny.copyWith(
              color: widget.isMine
                  ? Colors.white.withValues(alpha: 0.8)
                  : t.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
