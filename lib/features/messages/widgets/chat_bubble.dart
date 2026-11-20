// ============================================================================
//  ENNVO — CHAT BUBBLE
//
//  Every message shape the chat supports, ported from
//  `src/pages/Messages.tsx`.
//
//  Remember: `.chat-view-container` stays light even in dark mode, so
//  received bubbles, reply previews, system chips, and voice bubbles always
//  use high-contrast light-canvas tokens on `#FFFFFF`.
// ============================================================================

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
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
  double _drag = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    // An emoji-only message has no bubble behind it.
    final isEmojiOnly =
        message.type == MessageType.text && _isEmojiOnly(message.content);

    final radius = _radiusFor(
      isMine: widget.isMine,
      isFirst: widget.isFirstInGroup,
      isLast: widget.isLastInGroup,
    );

    final hasReaction =
        message.reaction != null && message.reaction!.trim().isNotEmpty;

    final bubble = Container(
      decoration: BoxDecoration(
        gradient: widget.isMine &&
                !isEmojiOnly &&
                message.type != MessageType.sticker &&
                message.type != MessageType.system
            ? const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              )
            : null,
        color: widget.isMine
            ? null
            : (isEmojiOnly ||
                    message.type == MessageType.sticker ||
                    message.type == MessageType.system
                ? Colors.transparent
                : const Color(0xFFF2F4F7)),
        borderRadius: radius,
      ),
      child: _body(context, isEmojiOnly),
    );

    if (message.type == MessageType.system) {
      return Center(child: _body(context, false));
    }

    return Padding(
      padding: EdgeInsets.only(
        top: widget.isFirstInGroup ? 8 : 2,
        bottom: (widget.isLastInGroup ? 8 : 2) + (hasReaction ? 10 : 0),
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
                      backgroundColor: const Color(0xFFE0F2FE),
                      backgroundImage: widget.avatarUrl.isEmpty
                          ? null
                          : ResizeImage(
                              NetworkImage(widget.avatarUrl),
                              width: 96,
                            ),
                      child: widget.avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 14,
                              color: Color(0xFF0369A1),
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

                // --- reaction pill -------------------------------------
                if (hasReaction)
                  Positioned(
                    right: widget.isMine ? 8 : null,
                    left: widget.isMine ? null : 8,
                    bottom: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message.reaction!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                // --- swipe-to-reply indicator --------------------------
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
    final textColor =
        widget.isMine ? Colors.white : const Color(0xFF111827);

    switch (message.type) {
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: EnnvoText.caption.copyWith(
                color: const Color(0xFF4B5563),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
        return _MediaBubble(message: message);

      case MessageType.video:
        return _VideoBubble(message: message);

      case MessageType.reel:
        return _ReelBubble(message: message);

      case MessageType.sticker:
        return SizedBox(
          width: 156,
          height: 156,
          child: message.stickerUrl == null || message.stickerUrl!.isEmpty
              ? const SizedBox.shrink()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    message.stickerUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
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
            ? Colors.black.withValues(alpha: 0.16)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(
            color: isMine
                ? Colors.white.withValues(alpha: 0.75)
                : const Color(0xFF0EA5E9),
            width: 2.5,
          ),
        ),
      ),
      child: Text(
        reply.content.isEmpty ? 'Attachment' : reply.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EnnvoText.caption.copyWith(
          color: isMine
              ? Colors.white.withValues(alpha: 0.95)
              : const Color(0xFF1F2937),
          fontSize: 11.5,
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
  const _MediaBubble({required this.message});

  final AppMessage message;

  void _openPreview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(dialogContext).top + 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).maybePop(),
                icon: const LucideIcon(
                  LucideIcons.x,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ??
        (message.mediaUrls.isNotEmpty ? message.mediaUrls.first : '');
    if (url.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openPreview(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Image.network(
          url,
          width: 240,
          height: 290,
          fit: BoxFit.cover,
          cacheWidth: 640,
          errorBuilder: (_, __, ___) => Container(
            width: 240,
            height: 290,
            color: const Color(0x14000000),
            alignment: Alignment.center,
            child: const LucideIcon(
              LucideIcons.image,
              size: 28,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
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
    final thumb = message.thumbnailUrl ?? '';

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            width: 220,
            height: 260,
            color: Colors.black,
            child: thumb.isEmpty
                ? null
                : Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    cacheWidth: 640,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
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
    final thumb = message.thumbnailUrl ?? message.mediaUrl ?? '';

    return SizedBox(
      width: 136,
      height: 176,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFF171717),
              child: thumb.isEmpty
                  ? null
                  : Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      cacheWidth: 400,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            ),
            Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.play,
                  size: 16,
                  strokeWidth: 2,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
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
  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  Timer? _fallbackTimer;

  bool _playing = false;
  double _progress = 0;
  Duration _duration = Duration.zero;

  static const List<double> _heights = [
    28, 48, 36, 60, 44, 76, 52, 90, 64, 100, 72, 88, 56, 76, 48, 84,
    60, 92, 52, 76, 44, 68, 32, 80, 40, 72, 36, 64,
  ];

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      _fallbackTimer?.cancel();
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    final url = widget.message.mediaUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      try {
        if (_player == null) {
          final player = AudioPlayer();
          _player = player;
          _durSub = player.onDurationChanged.listen((d) {
            if (mounted && d.inMilliseconds > 0) {
              _duration = d;
            }
          });
          _posSub = player.onPositionChanged.listen((p) {
            if (!mounted) return;
            final totalMs = _duration.inMilliseconds > 0
                ? _duration.inMilliseconds
                : ((widget.message.voiceDuration ?? 5) * 1000);
            if (totalMs > 0) {
              setState(
                () => _progress = (p.inMilliseconds / totalMs).clamp(0.0, 1.0),
              );
            }
          });
          _completeSub = player.onPlayerComplete.listen((_) {
            if (mounted) {
              setState(() {
                _playing = false;
                _progress = 0;
              });
            }
          });
        }
        await _player!.play(UrlSource(url));
        if (mounted) setState(() => _playing = true);
        return;
      } catch (_) {
        // Fallback smoothly if audio plugin/network is unavailable.
      }
    }

    final totalSec = (widget.message.voiceDuration ?? 4).clamp(1, 60);
    setState(() => _playing = true);
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _progress + (0.1 / totalSec);
      if (next >= 1.0) {
        t.cancel();
        setState(() {
          _playing = false;
          _progress = 0;
        });
      } else {
        setState(() => _progress = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.isMine ? Colors.white : const Color(0xFF0EA5E9);
    final empty = widget.isMine
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFD1D5DB);
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
        color: widget.isMine ? null : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMine ? Colors.white : const Color(0xFF0EA5E9),
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) async {
              final next = (details.localPosition.dx / 120).clamp(0.0, 1.0);
              setState(() => _progress = next);
              if (_player != null && _duration.inMilliseconds > 0) {
                await _player!.seek(
                  Duration(
                    milliseconds: (_duration.inMilliseconds * next).round(),
                  ),
                );
              }
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
                          height: (_heights[i] * 0.24).clamp(4.0, 28.0),
                          decoration: BoxDecoration(
                            color: i / _heights.length <= _progress
                                ? filled
                                : empty,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: (_progress * 110).clamp(0.0, 110.0),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: filled,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: filled.withValues(alpha: 0.55),
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
                  ? Colors.white.withValues(alpha: 0.85)
                  : const Color(0xFF6B7280),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
