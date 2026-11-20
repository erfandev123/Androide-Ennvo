// ============================================================================
//  ENNVO — CHAT COMPOSER
//
//  The message input, ported from `src/pages/Messages.tsx`.
//
//  Remember: `.chat-view-container` stays light even in dark mode, so the
//  composer keeps crisp light colors regardless of theme brightness.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/message.dart';
import '../../../data/services/upload_service.dart';
import '../../../data/services/voice_recorder.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../../reels/widgets/comments_sheet.dart' show kStickerEmoji, kStickerGifs;

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.onSendMedia,
    this.onSendVoice,
    this.onSendSticker,
    this.onTyping,
    this.replyTo,
    this.onCancelReply,
    this.avatarUrl = '',
    this.enabled = true,
  });

  final Future<void> Function(String text, AppMessage? replyTo) onSend;
  final Future<void> Function(
    String mediaUrl,
    MessageType type,
    AppMessage? replyTo,
  )? onSendMedia;
  final Future<void> Function(
    String audioUrl,
    int durationSeconds,
    AppMessage? replyTo,
  )? onSendVoice;
  final Future<void> Function(String stickerUrl, AppMessage? replyTo)?
      onSendSticker;
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
  final VoiceRecorder _recorder = VoiceRecorder();

  bool _showAttachMenu = false;
  bool _showStickerTray = false;
  bool _recording = false;
  bool _sending = false;
  bool _uploadingMedia = false;
  int _recordingSeconds = 0;
  Timer? _recordTimer;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _controller.removeListener(_onChanged);
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_focus.hasFocus && (_showAttachMenu || _showStickerTray)) {
      setState(() {
        _showAttachMenu = false;
        _showStickerTray = false;
      });
    } else {
      setState(() {});
    }
  }

  void _onChanged() {
    setState(() {});
    widget.onTyping?.call(_controller.text.trim().isNotEmpty);

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

  Future<void> _pickMedia(String kind) async {
    setState(() => _showAttachMenu = false);
    final picker = ImagePicker();
    XFile? picked;
    MessageType msgType = MessageType.image;

    try {
      if (kind == 'video') {
        msgType = MessageType.video;
        picked = await picker.pickVideo(source: ImageSource.gallery);
      } else if (kind == 'camera') {
        picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 88,
        );
      } else {
        picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 88,
        );
      }
    } catch (_) {
      picked = null;
    }

    if (picked == null || !mounted) return;
    setState(() => _uploadingMedia = true);
    String url = '';
    try {
      final result = await UploadService.uploadXFile(
        file: picked,
        folder: 'chat',
        contentType: kind == 'video' ? 'video/mp4' : null,
      );
      url = result.url;
    } catch (_) {
      url = '';
    }
    if (!mounted) return;
    setState(() => _uploadingMedia = false);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload media. Try again.')),
      );
      return;
    }

    final replyTo = widget.replyTo;
    widget.onCancelReply?.call();
    await widget.onSendMedia?.call(url, msgType, replyTo);
  }

  Future<void> _startRecording() async {
    setState(() {
      _showAttachMenu = false;
      _showStickerTray = false;
    });
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice notes are supported on mobile devices.'),
        ),
      );
      return;
    }
    final started = await _recorder.start();
    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }
    if (!mounted) {
      await _recorder.cancel();
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    _recordTimer?.cancel();
    setState(() {
      _recording = true;
      _recordingSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final duration = _recordingSeconds.clamp(1, 600);
    setState(() {
      _recording = false;
      _recordingSeconds = 0;
    });

    if (!send) {
      await _recorder.cancel();
      return;
    }

    final path = await _recorder.stop();
    if (path == null || path.isEmpty || !mounted) return;

    setState(() => _uploadingMedia = true);
    String url = '';
    try {
      final result = await UploadService.uploadXFile(
        file: XFile(path),
        folder: 'voice',
        contentType: 'audio/mp4',
      );
      url = result.url;
    } catch (_) {
      url = '';
    }
    await VoiceRecorder.remove(path);
    if (!mounted) return;
    setState(() => _uploadingMedia = false);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload voice message.')),
      );
      return;
    }

    final replyTo = widget.replyTo;
    widget.onCancelReply?.call();
    await widget.onSendVoice?.call(url, duration, replyTo);
  }

  Future<void> _insertOrSendSticker(String value, {bool isGif = false}) async {
    if (isGif) {
      setState(() => _showStickerTray = false);
      final replyTo = widget.replyTo;
      widget.onCancelReply?.call();
      await widget.onSendSticker?.call(value, replyTo);
      return;
    }

    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, value);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    final focused = _focus.hasFocus;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: MediaQuery.viewInsetsOf(context).bottom > 0
            ? MediaQuery.viewInsetsOf(context).bottom + 6
            : MediaQuery.paddingOf(context).bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_uploadingMedia)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                color: Color(0xFF0EA5E9),
                backgroundColor: Color(0xFFE0F2FE),
              ),
            ),

          if (widget.replyTo != null)
            _ReplyPreview(
              reply: widget.replyTo!,
              onClose: widget.onCancelReply,
            ),

          if (_showAttachMenu) _AttachMenu(onPick: _pickMedia),

          if (_showStickerTray)
            _StickerTray(
              onSelectEmoji: (e) => _insertOrSendSticker(e),
              onSelectGif: (url) => _insertOrSendSticker(url, isGif: true),
            ),

          // --- the composer pill ---------------------------------------
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: focused ? Colors.white : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: focused
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFFE2E8F0),
                width: focused ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RoundIconButton(
                  icon: _recording ? LucideIcons.x : LucideIcons.paperclip,
                  size: 38,
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
                      _stopRecording(send: false);
                      return;
                    }
                    setState(() {
                      _showAttachMenu = !_showAttachMenu;
                      if (_showAttachMenu) _showStickerTray = false;
                    });
                  },
                  semanticLabel: _recording ? 'Cancel recording' : 'Attach',
                ),
                const SizedBox(width: 4),

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
                            textCapitalization: TextCapitalization.sentences,
                            style: EnnvoText.body.copyWith(
                              color: const Color(0xFF111827),
                              fontSize: 15.5,
                              height: 1.35,
                            ),
                            cursorColor: const Color(0xFF0EA5E9),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: EnnvoText.body.copyWith(
                                color: const Color(0xFF737373),
                                fontSize: 15.5,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 11,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                ),
                const SizedBox(width: 4),

                if (!_recording)
                  _RoundIconButton(
                    icon: LucideIcons.smile,
                    size: 38,
                    iconSize: 18,
                    background: _showStickerTray
                        ? const Color(0x1A0EA5E9)
                        : Colors.transparent,
                    foreground: _showStickerTray
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF525252),
                    onTap: () {
                      setState(() {
                        _showStickerTray = !_showStickerTray;
                        if (_showStickerTray) {
                          _showAttachMenu = false;
                          _focus.unfocus();
                        }
                      });
                    },
                    semanticLabel: 'Sticker',
                  ),

                // --- send / mic button ---------------------------------
                if (_recording)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _stopRecording(send: true),
                    child: Container(
                      width: 38,
                      height: 38,
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
                  )
                else
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                                size: 38,
                                iconSize: 18,
                                background: const Color(0x1A0EA5E9),
                                foreground: const Color(0xFF0284C7),
                                onTap: _startRecording,
                                semanticLabel: 'Voice message',
                              ),
                            ),
                          ),
                        ),
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
                                  width: 38,
                                  height: 38,
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
              label: 'Photo',
              tile: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              onTap: () => onPick('media'),
            ),
            _AttachItem(
              icon: LucideIcons.video,
              label: 'Video',
              tile: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFEF4444),
              onTap: () => onPick('video'),
            ),
            _AttachItem(
              icon: LucideIcons.camera,
              label: 'Camera',
              tile: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              onTap: () => onPick('camera'),
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
        width: 156,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                fontSize: 12.5,
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
//  Emoji & GIF sticker tray
// ============================================================================
class _StickerTray extends StatelessWidget {
  const _StickerTray({
    required this.onSelectEmoji,
    required this.onSelectGif,
  });

  final ValueChanged<String> onSelectEmoji;
  final ValueChanged<String> onSelectGif;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kStickerEmoji.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final emoji = kStickerEmoji[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelectEmoji(emoji),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 21)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kStickerGifs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url = kStickerGifs[index];
                return GestureDetector(
                  onTap: () => onSelectGif(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 96),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
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
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 18; i++)
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
    final previewText = reply.content.isNotEmpty
        ? reply.content
        : switch (reply.type) {
            MessageType.image || MessageType.album => 'Photo',
            MessageType.video => 'Video',
            MessageType.voice => 'Voice message',
            MessageType.sticker => 'Sticker',
            _ => 'Message',
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to message',
                  style: EnnvoText.tiny.copyWith(
                    color: const Color(0xFF0284C7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  previewText,
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
                color: Color(0xFF6B7280),
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
