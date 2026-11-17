// ============================================================================
//  ENNVO — COMMENT ATTACHMENTS
//
//  Photos, live GIF stickers and voice notes inside a comment.
//
//  A voice note really plays: the file is either the R2 address the upload
//  service returned or a data URL the web app wrote into the document.
// ============================================================================

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../models/reel_comment.dart';

class CommentMedia extends StatelessWidget {
  const CommentMedia({required this.comment});

  final ReelComment comment;

  @override
  Widget build(BuildContext context) {
    final url = comment.mediaUrl ?? '';

    if (url.isEmpty) {
      // An emoji sticker lives in the text of the comment.
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(comment.text, style: const TextStyle(fontSize: 34)),
      );
    }

    if (comment.kind == CommentKind.photo ||
        (comment.kind == CommentKind.sticker && !_isGif(url))) {
      return _PhotoAttachment(url: url);
    }

    if (comment.kind == CommentKind.sticker) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          url,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          cacheWidth: 264,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return VoiceNote(url: url, durationMs: comment.audioDuration ?? 0);
  }

  static bool _isGif(String value) =>
      value.toLowerCase().endsWith('.gif') ||
      value.contains('media.giphy.com');
}

// ============================================================================
//  A picture in a comment — tap to open it full screen
// ============================================================================
class _PhotoAttachment extends StatelessWidget {
  const _PhotoAttachment({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        builder: (dialogContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          url,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
          cacheWidth: 480,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ============================================================================
//  A voice note that really plays
// ============================================================================
class VoiceNote extends StatefulWidget {
  const VoiceNote({super.key, required this.url, required this.durationMs});

  final String url;
  final int durationMs;

  @override
  State<VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<VoiceNote> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  static const List<int> _bars = [
    28, 48, 36, 60, 44, 76, 52, 90, 64, 100, 72, 88,
    56, 76, 48, 84, 60, 92, 52, 76, 44, 68, 32,
  ];

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
        return;
      }
      if (widget.url.startsWith('data:')) {
        // The web app stores a data URL; the player needs a real file.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This voice note was made on the web app.'),
          ),
        );
        return;
      }
      await _player.play(UrlSource(widget.url));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = widget.durationMs > 0
        ? widget.durationMs / 1000
        : 1.0;
    final progress = (_position.inMilliseconds / widget.durationMs).clamp(
      0.0,
      1.0,
    );
    final seconds = (_playing ? _position.inSeconds : widget.durationMs ~/ 1000);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                ),
              ),
              alignment: Alignment.center,
              child: _playing
                  ? const Icon(Icons.pause, size: 14, color: Colors.white)
                  : const Icon(Icons.play_arrow, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < _bars.length; i++)
                    Container(
                      width: 2,
                      height: (_bars[i] / 100 * 18).clamp(3.0, 18.0),
                      decoration: BoxDecoration(
                        color: i / _bars.length < progress
                            ? const Color(0xFF38BDF8)
                            : t.textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:${seconds.toString().padLeft(2, '0')}',
              style: EnnvoText.tiny.copyWith(
                color: t.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
