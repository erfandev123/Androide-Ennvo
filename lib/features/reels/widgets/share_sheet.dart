// ============================================================================
//  ENNVO — REEL SHARE SHEET
//
//  Sending a reel to somebody.
//
//  The sheet is the one from the reels prototype: a night surface, a
//  centred header, the row of the people on top and the row of the ways to
//  share below it.
//
//    • a tap on a person picks them, a second tap sends the reel
//    • writing a message swaps the options for an input and a send button
//    • the sheet never covers the screen — it only takes the room it needs
// ============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/typography.dart';
import '../../../shared/icons/lucide_icons.dart';

/// The night surface of the sheet — the one the prototype uses.
const Color _sheet = Color(0xFF18162B);
const Color _sheetBorder = Color(0x1FFFFFFF);
const Color _dim = Color(0x8CFFFFFF);

class ShareTarget {
  const ShareTarget({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool isOnline;
}

class ReelShareSheet extends StatefulWidget {
  const ReelShareSheet({
    super.key,
    required this.targets,
    required this.onSend,
    required this.onRepost,
    required this.onSave,
    required this.onCopyLink,
    required this.onAddStory,
    this.onReport,
    this.onDelete,
    this.isOwner = false,
    this.privacy = 'public',
    this.onPrivacyChanged,
  });

  final List<ShareTarget> targets;
  final Future<void> Function(List<ShareTarget> selected) onSend;
  final VoidCallback onRepost;
  final VoidCallback onSave;
  final VoidCallback onCopyLink;
  final VoidCallback onAddStory;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final bool isOwner;
  final String privacy;
  final ValueChanged<String>? onPrivacyChanged;

  @override
  State<ReelShareSheet> createState() => _ReelShareSheetState();
}

class _ReelShareSheetState extends State<ReelShareSheet> {
  final TextEditingController _message = TextEditingController();

  /// The people that are picked.
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _toggle(ShareTarget target) {
    setState(() {
      if (!_selected.remove(target.id)) _selected.add(target.id);
    });
  }

  Future<void> _send() async {
    final picked = widget.targets
        .where((target) => _selected.contains(target.id))
        .toList();
    if (picked.isEmpty) return;
    await widget.onSend(picked);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final hasMessage = _message.text.trim().isNotEmpty;

    // With the keyboard up the sheet takes the whole room and lifts its
    // lower edge, so the message field stays visible.
    final available = media.size.height - media.padding.top;
    final maxHeight = keyboard > 0 ? available : available * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: _sheetBorder)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
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
                  // The row fills the width of the sheet, so the close
                  // button can sit in the corner without touching the
                  // title.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Send to',
                        style: EnnvoText.bodySemi.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
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

            // --- the people ----------------------------------------------
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                itemCount: widget.targets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final target = widget.targets[index];
                  final isSelected = _selected.contains(target.id);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggle(target),
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF2A2745),
                                image: target.avatarUrl.isEmpty
                                    ? null
                                    : DecorationImage(
                                        image: NetworkImage(target.avatarUrl),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              alignment: Alignment.center,
                              child: target.avatarUrl.isEmpty
                                  ? Text(
                                      target.name.isEmpty
                                          ? '?'
                                          : target.name
                                                .characters
                                                .first
                                                .toUpperCase(),
                                      style: EnnvoText.bodySemi.copyWith(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            target.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnnvoText.tiny.copyWith(
                              color: _dim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1, color: _sheetBorder),

            // --- the options, or the message -----------------------------
            if (hasMessage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0x4DFFFFFF),
                            width: 1.25,
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _message,
                          onChanged: (_) => setState(() {}),
                          style: EnnvoText.body.copyWith(
                            color: Colors.white,
                            fontSize: 14.5,
                          ),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Write a message…',
                            hintStyle: EnnvoText.body.copyWith(
                              color: const Color(0x80FFFFFF),
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _send,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE2DCFB)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Send',
                          style: EnnvoText.bodySemi.copyWith(
                            color: const Color(0xFF2C2B4D),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ShareOption(
                      icon: LucideIcons.plusCircle,
                      label: 'Add story',
                      onTap: widget.onAddStory,
                    ),
                    _ShareOption(
                      icon: LucideIcons.link,
                      label: 'Copy link',
                      onTap: widget.onCopyLink,
                    ),
                    _ShareOption(
                      icon: LucideIcons.messageCircle,
                      label: 'Messenger',
                      onTap: _send,
                    ),
                    _ShareOption(
                      icon: LucideIcons.repeat2,
                      label: 'Repost',
                      onTap: widget.onRepost,
                    ),
                    _ShareOption(
                      icon: LucideIcons.bookmark,
                      label: 'Save',
                      onTap: widget.onSave,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  One of the ways to share
// ============================================================================
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(
                icon,
                size: 26,
                strokeWidth: 1.8,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: EnnvoText.tiny.copyWith(color: _dim, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
