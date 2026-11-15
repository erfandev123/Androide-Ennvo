// ============================================================================
//  ENNVO — REEL COMMENT SHEET
//
//  The comments of a reel.
//
//  The sheet is the one from the reels prototype: a night surface, a grab
//  handle, a centred header with the count, the list of the comments and —
//  at the very bottom — a round composer.
//
//  The composer is the part that used to go missing. The sheet lifts its
//  lower edge by the height of the keyboard, so the input is always on
//  screen, and the sheet itself never grows past the room that is left.
//
//    • a tap on a comment asks for a reply
//    • the reply banner sits right above the composer
//    • the sticker tray slides in under the list
//    • the send button lights up as soon as there is something to send
// ============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../models/reel_comment.dart';

/// The night surface of the sheet — the one the prototype uses.
const Color _sheet = Color(0xFF18162B);
const Color _sheetRaised = Color(0xFF221F3A);
const Color _sheetBorder = Color(0x1FFFFFFF);
const Color _dim = Color(0x8CFFFFFF);
const Color _faint = Color(0x59FFFFFF);

/// The emoji the sticker tray offers.
const List<String> kStickerEmoji = [
  '😂', '😍', '😮', '😢', '🔥', '👏',
  '🎉', '💯', '❤️', '😎', '🤔', '🙌',
  '👍', '👀', '✨', '🚀', '💪', '🫶',
  '🤯', '🥳', '😴', '🤝', '🙏', '💖',
];

class ReelCommentsSheet extends StatefulWidget {
  const ReelCommentsSheet({
    super.key,
    required this.comments,
    required this.onSubmit,
    required this.onToggleLike,
    required this.onDelete,
    this.onLoadMore,
    this.replierName = '',
  });

  final List<ReelComment> comments;
  final Future<void> Function(String text, ReelComment? replyTo) onSubmit;
  final void Function(ReelComment comment) onToggleLike;
  final void Function(ReelComment comment) onDelete;
  final VoidCallback? onLoadMore;
  final String replierName;

  @override
  State<ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<ReelCommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  ReelComment? _replyingTo;
  bool _showStickers = false;
  bool _sending = false;
  String? _stickerText;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isFocused => _focus.hasFocus;

  bool get _canSend => _input.text.trim().isNotEmpty || _stickerText != null;

  Future<void> _submit() async {
    final text = _input.text.trim();
    final sticker = _stickerText;
    if (text.isEmpty && sticker == null) return;

    setState(() => _sending = true);
    await widget.onSubmit(sticker ?? text, _replyingTo);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _input.clear();
      _stickerText = null;
      _replyingTo = null;
      _showStickers = false;
    });
    _focus.unfocus();
  }

  void _onInputChanged(String value) {
    setState(() {
      if (value.isEmpty) _stickerText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final count = widget.comments.length;

    // The sheet may not grow past the room that is left. When the keyboard is
    // up the sheet takes the whole screen and lifts its lower edge by the
    // height of the keyboard — the composer then always sits right above
    // the keyboard, never behind it.
    final available = media.size.height - media.padding.top;
    final maxHeight = keyboard > 0
        ? available
        : (available * 0.72).clamp(240.0, available);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: _sheetBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- the grab handle -----------------------------------------
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // --- the header ----------------------------------------------
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Comments',
                      style: EnnvoText.bodySemi.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFFFFF),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '$count',
                          style: EnnvoText.tiny.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned(
                  right: 6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: LucideIcon(
                          LucideIcons.x,
                          size: 20,
                          strokeWidth: 2.2,
                          color: Color(0xE6FFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- the reply banner ----------------------------------------
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.authorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnnvoText.caption.copyWith(color: _dim),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _replyingTo = null),
                    child: const LucideIcon(
                      LucideIcons.x,
                      size: 14,
                      strokeWidth: 2.4,
                      color: _dim,
                    ),
                  ),
                ],
              ),
            ),

          // --- the list ------------------------------------------------
          Flexible(
            child: widget.comments.isEmpty
                ? const _EmptyComments()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: widget.comments.length + 1,
                    itemBuilder: (context, index) {
                      if (index == widget.comments.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: TextButton(
                              onPressed: widget.onLoadMore,
                              child: Text(
                                'Load more comments',
                                style: EnnvoText.label.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final comment = widget.comments[index];
                      return _CommentRow(
                        comment: comment,
                        onToggleLike: () => widget.onToggleLike(comment),
                        onDelete: () => widget.onDelete(comment),
                        onReply: () {
                          setState(() => _replyingTo = comment);
                          _focus.requestFocus();
                        },
                      );
                    },
                  ),
          ),

          // --- the sticker tray ----------------------------------------
          if (_showStickers && !_isFocused)
            Container(
              height: 104,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: _sheetRaised,
                border: Border(top: BorderSide(color: _sheetBorder)),
              ),
              child: GridView.count(
                crossAxisCount: 6,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final emoji in kStickerEmoji)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _stickerText = emoji;
                          _input.text = emoji;
                        });
                        _focus.requestFocus();
                      },
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // --- the composer ---------------------------------------------
          // The sheet lifts its lower edge by the height of the keyboard,
          // so the input is never hidden behind it.
          Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: _Composer(
              controller: _input,
              focusNode: _focus,
              stickerActive: _showStickers,
              canSend: _canSend,
              sending: _sending,
              onChanged: _onInputChanged,
              onSend: _submit,
              onSticker: () {
                setState(() => _showStickers = !_showStickers);
                if (_showStickers) _focus.unfocus();
              },
              onPhoto: () {},
              onMic: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The composer — a round input with a round send button next to it
// ============================================================================
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.stickerActive,
    required this.canSend,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onSticker,
    required this.onPhoto,
    required this.onMic,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool stickerActive;
  final bool canSend;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onSticker;
  final VoidCallback onPhoto;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: _sheet,
        border: Border(top: BorderSide(color: _sheetBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- the input -----------------------------------------------
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 16, right: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x4DFFFFFF), width: 1.25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSend(),
                      textInputAction: TextInputAction.send,
                      style: EnnvoText.body.copyWith(
                        color: Colors.white,
                        fontSize: 14.5,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Add a comment…',
                        hintStyle: EnnvoText.body.copyWith(
                          color: const Color(0x80FFFFFF),
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                  _ComposerIcon(
                    icon: LucideIcons.smile,
                    active: stickerActive,
                    onTap: onSticker,
                    semanticLabel: 'Sticker',
                  ),
                  _ComposerIcon(
                    icon: LucideIcons.image,
                    onTap: onPhoto,
                    semanticLabel: 'Photo',
                  ),
                  _ComposerIcon(
                    icon: LucideIcons.mic,
                    onTap: onMic,
                    semanticLabel: 'Voice',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // --- the send button ------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canSend && !sending ? onSend : null,
            child: Opacity(
              opacity: canSend ? 1 : 0.35,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE2DCFB)],
                  ),
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.send,
                  size: 20,
                  strokeWidth: 2.2,
                  color: Color(0xFF2C2B4D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  One of the round buttons inside the input
// ============================================================================
class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.active = false,
  });

  final String icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0x26FFFFFF) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            icon,
            size: 20,
            strokeWidth: 1.9,
            color: active ? Colors.white : const Color(0xB3FFFFFF),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One comment
// ============================================================================
class _CommentRow extends StatefulWidget {
  const _CommentRow({
    required this.comment,
    required this.onToggleLike,
    required this.onDelete,
    required this.onReply,
  });

  final ReelComment comment;
  final VoidCallback onToggleLike;
  final VoidCallback onDelete;
  final VoidCallback onReply;

  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in [comment, ...comment.replies])
            _CommentLine(
              comment: entry,
              isReply: entry != comment,
              onToggleLike: widget.onToggleLike,
              onDelete: widget.onDelete,
              onReply: widget.onReply,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
//  One line of a comment
// ============================================================================
class _CommentLine extends StatelessWidget {
  const _CommentLine({
    required this.comment,
    required this.isReply,
    required this.onToggleLike,
    required this.onDelete,
    required this.onReply,
  });

  final ReelComment comment;
  final bool isReply;
  final VoidCallback onToggleLike;
  final VoidCallback onDelete;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final size = isReply ? 26.0 : 34.0;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 34 : 0, top: isReply ? 6 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentAvatar(comment: comment, size: size),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName.isEmpty
                            ? 'Someone'
                            : comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnnvoText.caption.copyWith(
                          color: _dim,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (comment.isOwn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: EnnvoText.tiny.copyWith(
                            color: _faint,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: EnnvoText.body.copyWith(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // --- the like -----------------------------------------
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleLike,
                      child: Semantics(
                        button: true,
                        label: 'Like the comment',
                        child: Row(
                          children: [
                            LucideIcon(
                              LucideIcons.heart,
                              size: 15,
                              strokeWidth: 1.8,
                              filled: comment.isLiked,
                              color: comment.isLiked
                                  ? const Color(0xFFFF2D55)
                                  : _dim,
                            ),
                            if (comment.likesCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likesCount}',
                                style: EnnvoText.tiny.copyWith(
                                  color: _dim,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: EnnvoText.tiny.copyWith(
                          color: _dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (comment.isOwn) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDelete,
                        child: Text(
                          'Delete',
                          style: EnnvoText.tiny.copyWith(
                            color: _faint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The picture of the author of a comment
// ============================================================================
class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.comment, required this.size});

  final ReelComment comment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A2745),
        image: comment.authorAvatar.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(comment.authorAvatar),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: comment.authorAvatar.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: EnnvoText.tiny.copyWith(color: Colors.white),
            )
          : null,
    );
  }
}

// ============================================================================
//  The empty state
// ============================================================================
class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LucideIcon(
              LucideIcons.messageCircle,
              size: 34,
              strokeWidth: 1.5,
              color: _faint,
            ),
            const SizedBox(height: 12),
            Text(
              'No comments yet',
              style: EnnvoText.body.copyWith(color: _dim, fontSize: 14.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first one to say something',
              style: EnnvoText.caption.copyWith(color: _faint, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
