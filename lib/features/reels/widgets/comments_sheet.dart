// ============================================================================
//  ENNVO �?" REEL COMMENT SHEET
//
//  The comments of a reel.
//
//  The sheet follows the theme of the app: it is white in the light mode and
//  near black in the dark one.
//
//  The composer is the part that matters:
//
//    �?� the input row has the picture of the user on the left and the
//      sticker, the photo and the voice buttons on the right
//    �?� a tap on the input opens the keyboard, and a **separate** input box
//      appears right above it. The sheet does not move and the screen does
//      not go up - only the box floats over the list
//    �?� the send button sits on the right of the box and it lights up as
//      soon as there is something to send
//    �?� every comment has a heart on its right
//    �?� a comment can be answered, and a sticker, a photo or a voice note
//      can be sent
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/services/voice_recorder.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../models/reel_comment.dart';

/// The emoji the sticker tray offers.
const List<String> kStickerEmoji = [
  '❤️', '😂', '😍', '😮', '😢', '👍',
  '🔥', '🎉', '💯', '👏', '🙏', '🤔',
  '😎', '🥰', '😭', '😡', '🤩', '✨',
  '🎨', '🚀', '💪', '🌚', '🐶', '🌈',
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
    this.avatarUrl = '',
    this.userName = '',
    this.onVoice,
    this.onPhoto,
    this.onStickerSelected,
  });

  final List<ReelComment> comments;
  final Future<void> Function(String text, ReelComment? replyTo) onSubmit;
  final void Function(ReelComment comment) onToggleLike;
  final void Function(ReelComment comment) onDelete;
  final VoidCallback? onLoadMore;
  final String replierName;

  /// The picture of the user, on the left of the input row.
  final String avatarUrl;

  /// The name of the user.
  final String userName;

  /// A voice note is sent.
  final Future<void> Function(String path, int durationMs, ReelComment? replyTo)?
  onVoice;

  /// A photo is attached.
  final Future<void> Function(File file, ReelComment? replyTo)? onPhoto;

  /// A sticker is picked.
  final void Function(String sticker)? onStickerSelected;

  @override
  State<ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<ReelCommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final VoiceRecorder _recorder = VoiceRecorder();

  ReelComment? _replyingTo;
  bool _showStickers = false;
  bool _sending = false;

  /// A voice note is being recorded.
  bool _recording = false;

  /// The length of the voice note, in milliseconds.
  int _recordedMs = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _input.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _canSend => _input.text.trim().isNotEmpty;

  // ---------------------------------------------------------------------
  //  Sending
  // ---------------------------------------------------------------------
  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    await widget.onSubmit(text, _replyingTo);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _input.clear();
      _replyingTo = null;
      _showStickers = false;
    });
    _focus.unfocus();
  }

  void _onInputChanged(String value) {
    // The send button lights up as soon as there is something to send.
    setState(() {});
  }

  // ---------------------------------------------------------------------
  //  The sticker tray
  // ---------------------------------------------------------------------
  void _pickSticker(String sticker) {
    setState(() {
      _showStickers = false;
      _input.text = sticker;
      _input.selection = TextSelection.collapsed(offset: sticker.length);
    });
    _focus.requestFocus();
  }

  // ---------------------------------------------------------------------
  //  The photo
  // ---------------------------------------------------------------------
  Future<void> _pickPhoto() async {
    final picked = await _pickImage();
    if (picked == null || !mounted) return;
    await widget.onPhoto?.call(picked, _replyingTo);
  }

  Future<File?> _pickImage() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (photo == null) return null;
      return File(photo.path);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  //  The voice note
  // ---------------------------------------------------------------------
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording(send: true);
      return;
    }

    final started = await _recorder.start();
    if (!started || !mounted) {
      await _recorder.cancel();
      return;
    }

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _recordedMs += 100);
    });

    setState(() {
      _recording = true;
      _recordedMs = 0;
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordedMs;

    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordedMs = 0;
    });

    if (!send || path == null) {
      await VoiceRecorder.remove(path);
      return;
    }
    if (duration < 600) {
      // A tap that was too short is not a note.
      await VoiceRecorder.remove(path);
      return;
    }

    await widget.onVoice?.call(path, duration, _replyingTo);
    if (!mounted) return;
    setState(() => _replyingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final count = widget.comments.length;

    // The sheet never changes its size: the keyboard does not move it, so
    // the screen behind it never goes up.
    final available = media.size.height - media.padding.top;
    final sheetHeight = (available * 0.78).clamp(280.0, available);

    // The box that floats above the keyboard.
    final expanded = keyboard > 0;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Stack(
        children: [
          // --- the sheet itself ---------------------------------------
          Column(
            children: [
              // --- the grab handle -------------------------------------
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: t.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // --- the header ------------------------------------------
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
                              color: t.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              '$count',
                              style: EnnvoText.tiny.copyWith(
                                color: t.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Positioned(
                      right: 4,
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
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- the reply banner ------------------------------------
              if (_replyingTo != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to ${_replyingTo!.authorName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.caption.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _replyingTo = null),
                        child: LucideIcon(
                          LucideIcons.x,
                          size: 14,
                          strokeWidth: 2.4,
                          color: t.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

              // --- the list ---------------------------------------------
              Expanded(
                child: widget.comments.isEmpty
                    ? const _EmptyComments()
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          // The composer floats over the list, and the
                          // keyboard covers the bottom of the sheet.
                          76 + (expanded ? keyboard : 0),
                        ),
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
                                      color: t.textSecondary,
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

              // --- the sticker tray ------------------------------------
              if (_showStickers && !expanded)
                Container(
                  height: 108,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    border: Border(top: BorderSide(color: t.border)),
                  ),
                  child: GridView.count(
                    crossAxisCount: 6,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final emoji in kStickerEmoji)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _pickSticker(emoji),
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
            ],
          ),

          // --- the composer --------------------------------------------
          // It floats: it sits on top of the list, and it lifts above the
          // keyboard when the keyboard is up.
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            child: _Composer(
              controller: _input,
              focusNode: _focus,
              expanded: expanded,
              stickerActive: _showStickers,
              canSend: _canSend,
              sending: _sending,
              recording: _recording,
              recordedMs: _recordedMs,
              avatarUrl: widget.avatarUrl,
              userName: widget.userName,
              onChanged: _onInputChanged,
              onSend: _submit,
              onSticker: () {
                setState(() => _showStickers = !_showStickers);
                if (_showStickers) _focus.unfocus();
              },
              onPhoto: _pickPhoto,
              onMic: _toggleRecording,
              onCancelRecording: () => _stopRecording(send: false),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The composer
//
//  One row: the picture of the user on the left, the input in the middle,
//  the sticker, the photo and the voice buttons and the send button on the
//  right.
//
//  While the keyboard is up the middle buttons go away and the row becomes
//  the separate input box that floats above the keyboard: the input and the
//  send button, nothing else.
// ============================================================================
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.stickerActive,
    required this.canSend,
    required this.sending,
    required this.recording,
    required this.recordedMs,
    required this.avatarUrl,
    required this.userName,
    required this.onChanged,
    required this.onSend,
    required this.onSticker,
    required this.onPhoto,
    required this.onMic,
    required this.onCancelRecording,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The keyboard is up: the row is the separate box above it.
  final bool expanded;
  final bool stickerActive;
  final bool canSend;
  final bool sending;
  final bool recording;
  final int recordedMs;
  final String avatarUrl;
  final String userName;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onSticker;
  final VoidCallback onPhoto;
  final VoidCallback onMic;
  final VoidCallback onCancelRecording;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (recording) {
      return _RecordingBar(
        milliseconds: recordedMs,
        onCancel: onCancelRecording,
        onSend: onMic,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- the picture of the user ------------------------------
          _UserAvatar(url: avatarUrl, name: userName),
          const SizedBox(width: 10),

          // --- the input ---------------------------------------------
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.borderStrong, width: 1.25),
                color: expanded ? t.surfaceAlt : Colors.transparent,
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
                        color: t.textPrimary,
                        fontSize: 14.5,
                      ),
                      cursorColor: t.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Add a comment…',
                        hintStyle: EnnvoText.body.copyWith(
                          color: t.textTertiary,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),

                  // The sticker, the photo and the voice buttons go away
                  // while the keyboard is up: the separate box carries the
                  // input and the send button and nothing else.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: expanded
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // --- the send button ---------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canSend && !sending ? onSend : null,
            child: Opacity(
              opacity: canSend ? 1 : 0.4,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: canSend
                      ? AppGradients.create
                      : const LinearGradient(
                          colors: [Color(0xFFD4D4D8), Color(0xFFA1A1AA)],
                        ),
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.send,
                  size: 19,
                  strokeWidth: 2.2,
                  color: Colors.white,
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
//  The picture of the user, on the left of the input row
// ============================================================================
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceAlt,
        image: url.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
            )
          : null,
    );
  }
}

// ============================================================================
//  The bar that shows while a voice note is being recorded
// ============================================================================
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.milliseconds,
    required this.onCancel,
    required this.onSend,
  });

  final int milliseconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFFF2D55),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$minutes:${(seconds % 60).toString().padLeft(2, '0')}',
            style: EnnvoText.bodySemi.copyWith(
              color: t.textPrimary,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: EnnvoText.label.copyWith(color: t.textSecondary),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.create,
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.send,
                size: 19,
                strokeWidth: 2.2,
                color: Colors.white,
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
    final t = context.tokens;

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
            color: active ? t.surfaceAlt : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            icon,
            size: 20,
            strokeWidth: 1.9,
            color: active ? t.accent : t.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One comment
// ============================================================================
class _CommentRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in [comment, ...comment.replies])
            _CommentLine(
              comment: entry,
              isReply: entry != comment,
              onToggleLike: onToggleLike,
              onDelete: onDelete,
              onReply: onReply,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
//  One line of a comment
//
//  The heart sits on the right of the comment, the way Instagram puts it.
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
    final t = context.tokens;
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
                          color: t.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comment.relativeTime,
                      style: EnnvoText.tiny.copyWith(
                        color: t.textTertiary,
                        fontSize: 11,
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
                          color: t.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: EnnvoText.tiny.copyWith(
                            color: t.textTertiary,
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
                    color: t.textPrimary,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                if (comment.kind == CommentKind.voice ||
                    comment.kind == CommentKind.photo) ...[
                  const SizedBox(height: 6),
                  _CommentMedia(comment: comment),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: EnnvoText.tiny.copyWith(
                          color: t.textSecondary,
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
                            color: t.textTertiary,
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
          const SizedBox(width: 10),

          // --- the heart, on the right of the comment ----------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleLike,
            child: Semantics(
              button: true,
              label: 'Like the comment',
              child: SizedBox(
                width: 32,
                child: Column(
                  children: [
                    LucideIcon(
                      LucideIcons.heart,
                      size: 17,
                      strokeWidth: 1.8,
                      filled: comment.isLiked,
                      color: comment.isLiked
                          ? const Color(0xFFFF2D55)
                          : t.textTertiary,
                    ),
                    if (comment.likesCount > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        formatCount(comment.likesCount),
                        style: EnnvoText.tiny.copyWith(
                          color: t.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
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
//  The picture of the author of a comment
// ============================================================================
class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.comment, required this.size});

  final ReelComment comment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = comment.authorName;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceAlt,
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
              style: EnnvoText.tiny.copyWith(color: t.textSecondary),
            )
          : null,
    );
  }
}

// ============================================================================
//  A voice note or a picture inside a comment
// ============================================================================
class _CommentMedia extends StatelessWidget {
  const _CommentMedia({required this.comment});

  final ReelComment comment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final url = comment.mediaUrl ?? '';

    if (comment.kind == CommentKind.photo && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          url,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          cacheWidth: 480,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    // A voice note: a small pill with the length of the note.
    final seconds = (comment.audioDuration ?? 0) ~/ 1000;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(
            LucideIcons.play,
            size: 13,
            strokeWidth: 2,
            color: t.accent,
          ),
          const SizedBox(width: 8),
          Text(
            '${seconds}s',
            style: EnnvoText.tiny.copyWith(
              color: t.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
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
    final t = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              LucideIcons.messageCircle,
              size: 34,
              strokeWidth: 1.5,
              color: t.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No comments yet',
              style: EnnvoText.body.copyWith(
                color: t.textSecondary,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first one to say something',
              style: EnnvoText.caption.copyWith(
                color: t.textTertiary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
