// ============================================================================
//  ENNVO — COMMENTS SHEET
//
//  The comments portal of a reel.
//
//  The composer behaves the way TikTok does:
//
//    • a collapsed pill sits at the bottom of the sheet
//    • tapping it opens the keyboard and a **separate composer appears
//      directly above the keyboard**, while the comment list keeps its place
//    • the sheet grows upward, so the list never jumps
//
//  The list itself carries the nesting: replies are indented, a thread can
//  be expanded, a comment can be liked and a comment of your own can be
//  deleted with a second tap to confirm.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../models/reel_comment.dart';

/// The stickers offered by the tray.
const List<String> kStickerEmoji = [
  '😍', '🔥', '😂', '🥹', '👏', '💖',
  '😎', '🤩', '🙌', '✨', '😭', '🥰',
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
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isFocused => _focus.hasFocus;

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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final count = widget.comments.length;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.86,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.isDark ? const Color(0xFF0C121E) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          border: Border.all(
            color: t.isDark ? const Color(0x400B4A6A) : const Color(0x40BAE6FD),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- the grab handle ---------------------------------------
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: t.isDark
                    ? const Color(0x66224982)
                    : const Color(0xFFBAE6FD),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // --- the header --------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: t.isDark
                        ? const Color(0x260B4A6A)
                        : const Color(0x29BAE6FD),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Comments',
                          style: EnnvoText.bodySemi.copyWith(
                            color: t.textPrimary,
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
                              color: t.isDark
                                  ? const Color(0x330EA5E9)
                                  : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: t.isDark
                                    ? const Color(0x4D0EA5E9)
                                    : const Color(0x4DB3E6FD),
                              ),
                            ),
                            child: Text(
                              '$count',
                              style: EnnvoText.tiny.copyWith(
                                color: t.isDark
                                    ? const Color(0xFF7DD3FC)
                                    : const Color(0xFF0284C7),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: t.isDark
                            ? const Color(0x330EA5E9)
                            : const Color(0xFFF0F9FF),
                        shape: BoxShape.circle,
                      ),
                      child: LucideIcon(
                        LucideIcons.x,
                        size: 16,
                        strokeWidth: 2.2,
                        color: t.isDark
                            ? const Color(0xFF7DD3FC)
                            : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- the list ----------------------------------------------
            Flexible(
              child: widget.comments.isEmpty
                  ? _EmptyComments()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: widget.comments.length + 1,
                      itemBuilder: (context, index) {
                        if (index == widget.comments.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: TextButton(
                                onPressed: widget.onLoadMore,
                                child: Text(
                                  'Load more comments',
                                  style: EnnvoText.label.copyWith(
                                    color: const Color(0xFF0284C7),
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

            // --- the sticker tray --------------------------------------
            if (_showStickers && !_isFocused)
              Container(
                height: 104,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: t.isDark ? const Color(0xFF0A0F19) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: t.isDark
                          ? const Color(0x260B4A6A)
                          : const Color(0x29BAE6FD),
                    ),
                  ),
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

            // --- the reply banner --------------------------------------
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? const Color(0x330EA5E9)
                      : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: t.isDark
                        ? const Color(0x330EA5E9)
                        : const Color(0x40BAE6FD),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_replyingTo!.authorName}',
                        style: EnnvoText.caption.copyWith(
                          color: t.isDark
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _replyingTo = null),
                      child: Text(
                        'Cancel',
                        style: EnnvoText.tiny.copyWith(
                          color: t.isDark
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF0369A1),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // --- the collapsed composer --------------------------------
            if (!_isFocused)
              _CollapsedComposer(
                onTap: () => _focus.requestFocus(),
                onSticker: () => setState(() => _showStickers = !_showStickers),
                stickerActive: _showStickers,
                onPhoto: () {},
              ),

            // --- the focused composer, right above the keyboard ---------
            if (_isFocused)
              _FocusedComposer(
                controller: _input,
                focusNode: _focus,
                sending: _sending,
                onSend: _submit,
                onSticker: () => setState(() => _showStickers = !_showStickers),
                onPhoto: () {},
                onCancelReply: () => setState(() => _replyingTo = null),
                replyingTo: _replyingTo,
              ),

            // --- the keyboard inset -------------------------------------
            // This lifts the whole sheet so the composer sits exactly on
            // top of the keyboard.
            SizedBox(height: keyboard),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The collapsed composer — a pill at the bottom of the list
// ============================================================================
class _CollapsedComposer extends StatelessWidget {
  const _CollapsedComposer({
    required this.onTap,
    required this.onSticker,
    required this.onPhoto,
    this.stickerActive = false,
  });

  final VoidCallback onTap;
  final VoidCallback onSticker;
  final VoidCallback onPhoto;
  final bool stickerActive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: t.isDark ? const Color(0xFF131D31) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: t.isDark
                        ? const Color(0x4D0EA5E9)
                        : const Color(0x4DBAE6FD),
                  ),
                ),
                child: Text(
                  'Add a comment...',
                  style: EnnvoText.body.copyWith(
                    color: t.textTertiary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconAction(
            icon: LucideIcons.smile,
            onTap: onSticker,
            color: stickerActive
                ? const Color(0xFFF59E0B)
                : (t.isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7)),
          ),
          const SizedBox(width: 4),
          _IconAction(
            icon: LucideIcons.image,
            onTap: onPhoto,
            color: t.isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The focused composer — a separate bar right above the keyboard
// ============================================================================
class _FocusedComposer extends StatefulWidget {
  const _FocusedComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onSticker,
    required this.onPhoto,
    required this.onCancelReply,
    this.replyingTo,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onSticker;
  final VoidCallback onPhoto;
  final VoidCallback onCancelReply;
  final ReelComment? replyingTo;

  @override
  State<_FocusedComposer> createState() => _FocusedComposerState();
}

class _FocusedComposerState extends State<_FocusedComposer> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0xFF0C121E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: t.isDark
                ? const Color(0x260B4A6A)
                : const Color(0x29BAE6FD),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${widget.replyingTo!.authorName}',
                      style: EnnvoText.caption.copyWith(
                        color: t.isDark
                            ? const Color(0xFF7DD3FC)
                            : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onCancelReply,
                    child: const LucideIcon(
                      LucideIcons.x,
                      size: 15,
                      strokeWidth: 2.4,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: t.isDark
                        ? const Color(0xFF131D31)
                        : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: t.isDark
                          ? const Color(0x4D0EA5E9)
                          : const Color(0x4DBAE6FD),
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 4,
                    style: EnnvoText.body.copyWith(
                      color: t.textPrimary,
                      fontSize: 14,
                    ),
                    cursorColor: const Color(0xFF0EA5E9),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: widget.replyingTo == null
                          ? 'Add a comment...'
                          : 'Reply to ${widget.replyingTo!.authorName}...',
                      hintStyle: EnnvoText.body.copyWith(
                        color: t.textTertiary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _IconAction(
                icon: LucideIcons.smile,
                onTap: widget.onSticker,
                color: t.isDark
                    ? const Color(0xFF7DD3FC)
                    : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 4),
              _IconAction(
                icon: LucideIcons.image,
                onTap: widget.onPhoto,
                color: t.isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.sending ? null : widget.onSend,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x400EA5E9),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: widget.sending
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const LucideIcon(
                          LucideIcons.send,
                          size: 16,
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final String icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: LucideIcon(icon, size: 19, strokeWidth: 2, color: color),
        ),
      ),
    );
  }
}

// ============================================================================
//  One comment, with its replies
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
  bool _showReplies = false;
  bool _confirmDelete = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final comment = widget.comment;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommentAvatar(
                name: comment.authorName,
                url: comment.authorAvatar,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnnvoText.caption.copyWith(
                              color: t.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${comment.relativeTime}',
                          style: EnnvoText.tiny.copyWith(
                            color: t.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _CommentBody(comment: comment),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onReply,
                          child: Text(
                            'Reply',
                            style: EnnvoText.tiny.copyWith(
                              color: t.textTertiary,
                              fontSize: 10,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!_confirmDelete) {
                              setState(() => _confirmDelete = true);
                              Future.delayed(
                                const Duration(seconds: 3),
                                () {
                                  if (mounted) {
                                    setState(() => _confirmDelete = false);
                                  }
                                },
                              );
                              return;
                            }
                            widget.onDelete();
                          },
                          child: Text(
                            _confirmDelete ? 'Confirm?' : 'Delete',
                            style: EnnvoText.tiny.copyWith(
                              color: _confirmDelete
                                  ? const Color(0xFFE11D48)
                                  : t.textTertiary,
                              fontSize: 10,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggleLike,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LucideIcon(
                      LucideIcons.heart,
                      size: 15,
                      strokeWidth: 1.8,
                      filled: comment.isLiked,
                      color: comment.isLiked
                          ? const Color(0xFFEF4444)
                          : t.textTertiary,
                    ),
                    if (comment.likesCount > 0)
                      Text(
                        '${comment.likesCount}',
                        style: EnnvoText.tiny.copyWith(
                          color: comment.isLiked
                              ? const Color(0xFFEF4444)
                              : t.textTertiary,
                          fontSize: 9.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // --- the replies -------------------------------------------
          if (comment.replies.isNotEmpty) ...[
            if (!_showReplies)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showReplies = true),
                child: Padding(
                  padding: const EdgeInsets.only(left: 42, top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 1,
                        color: t.isDark
                            ? const Color(0x660EA5E9)
                            : const Color(0x667DD3FC),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'See ${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'}...',
                        style: EnnvoText.tiny.copyWith(
                          color: t.isDark
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF2563EB),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final reply in comment.replies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CommentAvatar(
                              name: reply.authorName,
                              url: reply.authorAvatar,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          reply.authorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: EnnvoText.caption.copyWith(
                                            color: t.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${reply.relativeTime}',
                                        style: EnnvoText.tiny.copyWith(
                                          color: t.textTertiary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reply.text,
                                    style: EnnvoText.caption.copyWith(
                                      color: t.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showReplies = false),
                      child: Text(
                        'Hide replies',
                        style: EnnvoText.tiny.copyWith(
                          color: t.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The body of a comment: text, a sticker, a photo or a voice note.
class _CommentBody extends StatelessWidget {
  const _CommentBody({required this.comment});

  final ReelComment comment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    switch (comment.kind) {
      case CommentKind.sticker:
        return Text(comment.text, style: const TextStyle(fontSize: 38));
      case CommentKind.photo:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.network(
            comment.mediaUrl ?? '',
            width: 140,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      case CommentKind.voice:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF1F242D) : const Color(0xFFECEFF3),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                '${comment.audioDuration ?? 0}s',
                style: EnnvoText.tiny.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        );
      case CommentKind.text:
      case CommentKind.video:
      case CommentKind.reel:
        return Text(
          comment.text,
          style: EnnvoText.caption.copyWith(
            color: t.textPrimary,
            fontSize: 13,
            height: 1.45,
          ),
        );
    }
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.name, required this.url, required this.size});

  final String name;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceAlt,
        border: Border.all(
          color: t.isDark ? const Color(0x260B4A6A) : const Color(0x1FB3E6FD),
        ),
        image: url.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: url.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: EnnvoText.tiny.copyWith(color: t.textSecondary),
              ),
            )
          : null,
    );
  }
}

class _EmptyComments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(
            LucideIcons.messageCircle,
            size: 52,
            strokeWidth: 1.4,
            color: t.textTertiary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'No comments yet. Be the first!',
            style: EnnvoText.body.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}
