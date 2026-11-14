// ============================================================================
//  ENNVO — CHAT COMPOSER
//
//  The message input, ported from the composer of `src/pages/Messages.tsx`.
//
//    • a floating pill that lifts above the keyboard
//    • an attach button that rotates 45° when the menu is open
//    • an auto-growing text field
//    • a sticker button and a photo button
//    • a send button that swaps with a mic button
//    • a recording state with a live level meter
//    • a media tray and a reply preview above the pill
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/message.dart';
import '../../../shared/icons/lucide_icons.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.onTyping,
    this.replyTo,
    this.onCancelReply,
    this.avatarUrl = '',
    this.enabled = true,
  });

  final Future<void> Function(String text, AppMessage? replyTo) onSend;
  final ValueChanged<bool>? onTyping;
  final AppMessage? replyTo;
  final VoidCallback? onCancelReply;
  final String avatarUrl;
  final bool enabled;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final TextEditingController _heightController = TextEditingController();

  bool _showAttachMenu = false;
  bool _recording = false;
  bool _sending = false;
  int _recordingSeconds = 0;
  Timer? _recordTimer;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    widget.onTyping?.call(_controller.text.trim().isNotEmpty);

    // The typing flag is cleared after three seconds of silence.
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 3000), () {
      widget.onTyping?.call(false);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final replyTo = widget.replyTo;
    _controller.clear();
    widget.onTyping?.call(false);
    widget.onCancelReply?.call();

    await widget.onSend(text, replyTo);
    if (mounted) setState(() => _sending = false);
    _focus.requestFocus();
  }

  void _toggleRecording() {
    if (_recording) {
      _recordTimer?.cancel();
      setState(() {
        _recording = false;
        _recordingSeconds = 0;
      });
      return;
    }
    setState(() {
      _recording = true;
      _recordingSeconds = 0;
    });
    HapticFeedback.mediumImpact();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom > 0
            ? MediaQuery.viewInsetsOf(context).bottom
            : MediaQuery.paddingOf(context).bottom + 8,
      ),
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0xFF0B0B0E) : Colors.white,
        border: Border(
          top: BorderSide(color: t.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- the reply preview -------------------------------------
          if (widget.replyTo != null)
            _ReplyPreview(
              reply: widget.replyTo!,
              onClose: widget.onCancelReply,
            ),

          // --- the attach menu ---------------------------------------
          if (_showAttachMenu)
            _AttachMenu(
              onPick: (kind) {
                setState(() => _showAttachMenu = false);
              },
            ),

          // --- the composer row --------------------------------------
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // --- the attach / cancel button ---
                _RoundIconButton(
                  icon: _recording ? LucideIcons.x : LucideIcons.paperclip,
                  size: 40,
                  iconSize: _recording ? 18 : 16,
                  background: _recording
                      ? const Color(0x26F43F5E)
                      : const Color(0x1A0EA5E9),
                  foreground: _recording
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF0284C7),
                  rotation: _showAttachMenu ? 0.785398 : 0,
                  onTap: () {
                    if (_recording) {
                      _toggleRecording();
                      return;
                    }
                    setState(() => _showAttachMenu = !_showAttachMenu);
                  },
                  semanticLabel: _recording ? 'Cancel recording' : 'Attach',
                ),
                const SizedBox(width: 4),

                // --- the text field -------------------------------------
                Expanded(
                  child: _recording
                      ? _RecordingBar(seconds: _recordingSeconds)
                      : ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            minLines: 1,
                            maxLines: 5,
                            enabled: widget.enabled,
                            style: EnnvoText.body.copyWith(
                              color: const Color(0xFF111827),
                              fontSize: 16,
                            ),
                            cursorColor: const Color(0xFF0EA5E9),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: EnnvoText.body.copyWith(
                                color: const Color(0xFF737373),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                ),
                const SizedBox(width: 4),

                // --- the sticker button --------------------------------
                _RoundIconButton(
                  icon: LucideIcons.smile,
                  size: 40,
                  iconSize: 18,
                  background: Colors.transparent,
                  foreground: const Color(0xFF525252),
                  onTap: () {},
                  semanticLabel: 'Sticker',
                ),

                // --- the send / mic button ----------------------------
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The mic.
                      IgnorePointer(
                        ignoring: hasText,
                        child: AnimatedOpacity(
                          opacity: hasText ? 0 : 1,
                          duration: const Duration(milliseconds: 100),
                          child: AnimatedScale(
                            scale: hasText ? 0.5 : 1,
                            duration: const Duration(milliseconds: 100),
                            child: _RoundIconButton(
                              icon: LucideIcons.mic,
                              size: 40,
                              iconSize: 18,
                              background: const Color(0x1A0EA5E9),
                              foreground: const Color(0xFF0284C7),
                              onTap: _toggleRecording,
                              semanticLabel: 'Voice message',
                            ),
                          ),
                        ),
                      ),
                      // The send button.
                      IgnorePointer(
                        ignoring: !hasText,
                        child: AnimatedOpacity(
                          opacity: hasText ? 1 : 0,
                          duration: const Duration(milliseconds: 100),
                          child: AnimatedScale(
                            scale: hasText ? 1 : 0.5,
                            duration: const Duration(milliseconds: 100),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _send,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0A84FF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const LucideIcon(
                                  LucideIcons.send,
                                  size: 18,
                                  strokeWidth: 2.2,
                                  color: Colors.white,
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
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The attach menu
// ============================================================================
class _AttachMenu extends StatelessWidget {
  const _AttachMenu({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttachItem(
              icon: LucideIcons.image,
              label: 'Photos & Videos',
              tile: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              onTap: () => onPick('media'),
            ),
            _AttachItem(
              icon: LucideIcons.fileText,
              label: 'Document',
              tile: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF2563EB),
              onTap: () => onPick('document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachItem extends StatelessWidget {
  const _AttachItem({
    required this.icon,
    required this.label,
    required this.tile,
    required this.iconColor,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color tile;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: tile, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: LucideIcon(
                icon,
                size: 16,
                strokeWidth: 2,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: EnnvoText.caption.copyWith(
                color: const Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The recording state
// ============================================================================
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // The ping dot.
          SizedBox(
            width: 10,
            height: 10,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0x99EF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // The live level meter.
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 20; i++)
                  Container(
                    width: 2.5,
                    height: 6 + ((i * 7 + seconds * 3) % 18),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
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
//  The reply preview above the composer
// ============================================================================
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.reply, required this.onClose});

  final AppMessage reply;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0x99E9D5FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${reply.senderId == 'me' ? 'yourself' : 'them'}',
                  style: EnnvoText.tiny.copyWith(
                    color: const Color(0xFF9333EA),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  reply.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EnnvoText.caption.copyWith(
                    color: const Color(0xFF1F2937),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: LucideIcon(
                LucideIcons.x,
                size: 14,
                strokeWidth: 2.5,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  A round icon button
// ============================================================================
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.semanticLabel,
    this.rotation = 0,
  });

  final String icon;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final String semanticLabel;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: rotation,
            child: LucideIcon(
              icon,
              size: iconSize,
              strokeWidth: 2.2,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
