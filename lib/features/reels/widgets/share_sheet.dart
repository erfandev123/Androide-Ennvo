// ============================================================================
//  ENNVO — REEL SHARE SHEET
//
//  Sending a reel to somebody.
//
//  The sheet is deliberately small, the way a phone share sheet should be:
//
//    • the people sit in one row on top — their picture and their name
//    • under them the ways to share, in two short rows: download, add to a
//      story, copy the link, message, repost, settings, more, delete
//    • as soon as a friend is picked the ways to share go away and the sheet
//      turns into a composer: a message box and the blue send button
//    • the settings of the reel live in their own small sheet, opened from
//      the settings button — the share sheet itself never carries them
//
//  The blue of every active control is the blue of the brand.
// ============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/icons/lucide_icons.dart';

/// The blue of the brand: the ring of a picked friend and the send button.
const Color _kShareBlue = Color(0xFF2AA1FB);

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

/// The settings of a reel, the ones the share sheet carries.
class ShareSettings {
  const ShareSettings({
    this.privacy = 'public',
    this.commentsDisabled = false,
    this.allowRemix = true,
    this.hideLikes = false,
    this.saveToDevice = false,
  });

  final String privacy;
  final bool commentsDisabled;
  final bool allowRemix;
  final bool hideLikes;
  final bool saveToDevice;

  ShareSettings copyWith({
    String? privacy,
    bool? commentsDisabled,
    bool? allowRemix,
    bool? hideLikes,
    bool? saveToDevice,
  }) {
    return ShareSettings(
      privacy: privacy ?? this.privacy,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      allowRemix: allowRemix ?? this.allowRemix,
      hideLikes: hideLikes ?? this.hideLikes,
      saveToDevice: saveToDevice ?? this.saveToDevice,
    );
  }
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
    this.onMessage,
    this.onReport,
    this.onDelete,
    this.onDownload,
    this.isOwner = false,
    this.hasReposted = false,
    this.settings = const ShareSettings(),
    this.onSettingsChanged,
  });

  final List<ShareTarget> targets;

  /// Sends the reel to the picked people, with the message that was typed.
  final Future<void> Function(List<ShareTarget> selected, String message) onSend;

  final VoidCallback onRepost;
  final VoidCallback onSave;
  final Future<void> Function() onCopyLink;
  final VoidCallback onAddStory;

  /// Opens the messages screen, for the "Message" button.
  final VoidCallback? onMessage;

  final VoidCallback? onReport;
  final VoidCallback? onDelete;

  /// Saves the reel on the phone. Returns when the download has started.
  final Future<void> Function()? onDownload;

  final bool isOwner;
  final bool hasReposted;

  /// The settings of the reel.
  final ShareSettings settings;

  /// A setting was changed.
  final ValueChanged<ShareSettings>? onSettingsChanged;

  @override
  State<ReelShareSheet> createState() => _ReelShareSheetState();
}

class _ReelShareSheetState extends State<ReelShareSheet> {
  final TextEditingController _message = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _messageFocus = FocusNode();

  /// The people that are picked.
  final Set<String> _selected = <String>{};

  ShareSettings _settings = const ShareSettings();

  bool _sending = false;
  bool _copying = false;
  bool _copied = false;
  bool _downloading = false;
  bool _downloaded = false;
  bool _reposted = false;

  /// The friends filtered by the search box.
  List<ShareTarget> get _visibleTargets {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return widget.targets;
    return widget.targets
        .where((target) => target.name.toLowerCase().contains(term))
        .toList();
  }

  List<ShareTarget> get _picked => widget.targets
      .where((target) => _selected.contains(target.id))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _reposted = widget.hasReposted;
  }

  @override
  void dispose() {
    _message.dispose();
    _search.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  void _toggle(ShareTarget target) {
    setState(() {
      if (!_selected.remove(target.id)) _selected.add(target.id);
    });
  }

  void _updateSettings(ShareSettings settings) {
    setState(() => _settings = settings);
    widget.onSettingsChanged?.call(settings);
  }

  Future<void> _send() async {
    final picked = _picked;
    if (picked.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(picked, _message.text.trim());
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy() async {
    if (_copying) return;
    setState(() {
      _copying = true;
      _copied = false;
    });
    try {
      await widget.onCopyLink();
      if (!mounted) return;
      setState(() => _copied = true);
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _copied = false);
      });
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _download() async {
    final run = widget.onDownload;
    if (run == null || _downloading) return;
    setState(() {
      _downloading = true;
      _downloaded = false;
    });
    try {
      await run();
      if (!mounted) return;
      setState(() => _downloaded = true);
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _downloaded = false);
      });
    } catch (_) {
      if (!mounted) return;
      _toast('Could not save the reel. Try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 2),
        content: Text(
          text,
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Keep the sheet clear of the phone's back / home / overview buttons,
    // which are drawn over the bottom of an edge-to-edge screen.
    final systemBottom = media.padding.bottom;
    final hasSelection = _selected.isNotEmpty;
    final friends = _visibleTargets;

    // The sheet never grows past the room it needs, and it lifts its lower
    // edge when the keyboard is up.
    final available = media.size.height - media.padding.top;
    final maxHeight = (available * 0.7).clamp(280.0, available);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard + systemBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- the grab handle -----------------------------------------
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: t.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // --- the header ----------------------------------------------
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 46),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      child: Text(
                        hasSelection
                            ? _selectionTitle(_picked)
                            : 'Share to',
                        key: ValueKey(hasSelection),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: EnnvoText.bodySemi.copyWith(
                          color: t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.surfaceAlt,
                      ),
                      alignment: Alignment.center,
                      child: LucideIcon(
                        LucideIcons.x,
                        size: 16,
                        strokeWidth: 2.4,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- search the people ---------------------------------------
            if (widget.targets.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      LucideIcon(
                        LucideIcons.search,
                        size: 15,
                        strokeWidth: 2.2,
                        color: t.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: EnnvoText.body.copyWith(
                            color: t.textPrimary,
                            fontSize: 13,
                          ),
                          cursorColor: _kShareBlue,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Search people…',
                            hintStyle: EnnvoText.caption.copyWith(
                              color: t.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // --- the people ----------------------------------------------
            if (friends.isNotEmpty)
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                  itemCount: friends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final target = friends[index];
                    return _FriendTile(
                      target: target,
                      isSelected: _selected.contains(target.id),
                      onTap: () => _toggle(target),
                    );
                  },
                ),
              )
            else if (_search.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Text(
                  'No friends found',
                  style: EnnvoText.caption.copyWith(color: t.textTertiary),
                ),
              ),

            // --- the composer, or the ways to share ----------------------
            AnimatedSize(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: hasSelection
                  ? _composer(context, t)
                  : _actions(context, t),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================================
  //  The composer: a message box and the send button
  // ======================================================================
  Widget _composer(BuildContext context, EnnvoTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.border),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _message,
                focusNode: _messageFocus,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                style: EnnvoText.body.copyWith(
                  color: t.textPrimary,
                  fontSize: 14,
                ),
                cursorColor: _kShareBlue,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Write a message…',
                  hintStyle: EnnvoText.body.copyWith(
                    color: t.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF71D2FD), Color(0xFF2AA1FB), Color(0xFF2563EB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D2AA1FB),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const LucideIcon(
                      LucideIcons.send,
                      size: 19,
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  The ways to share, two short rows that never scroll
  // ======================================================================
  Widget _actions(BuildContext context, EnnvoTokens t) {
    final actions = <Widget>[
      _ShareAction(
        icon: LucideIcons.download,
        label: _downloaded ? 'Saved!' : 'Download',
        busy: _downloading,
        active: _downloaded,
        onTap: widget.onDownload == null ? null : _download,
      ),
      _ShareAction(
        icon: LucideIcons.plusCircle,
        label: 'Add story',
        onTap: widget.onAddStory,
      ),
      _ShareAction(
        icon: LucideIcons.link,
        label: _copied ? 'Copied!' : 'Copy link',
        busy: _copying,
        active: _copied,
        onTap: _copy,
      ),
      _ShareAction(
        icon: LucideIcons.messageCircle,
        label: 'Message',
        onTap: () {
          final openMessages = widget.onMessage;
          if (openMessages == null) {
            if (widget.targets.isEmpty) return;
            _toggle(widget.targets.first);
            _messageFocus.requestFocus();
            return;
          }
          Navigator.of(context).maybePop();
          openMessages();
        },
      ),
      _ShareAction(
        icon: LucideIcons.repeat2,
        label: _reposted ? 'Undo' : 'Repost',
        active: _reposted,
        onTap: () {
          setState(() => _reposted = !_reposted);
          widget.onRepost();
        },
      ),
      _ShareAction(
        icon: LucideIcons.settings,
        label: 'Settings',
        onTap: () => widget.isOwner
            ? _openOwnerSettings(context)
            : _notOwner(context),
      ),
      _ShareAction(
        icon: LucideIcons.moreHorizontal,
        label: 'More',
        onTap: () => _openMore(context),
      ),
      if (widget.isOwner)
        _ShareAction(
          icon: LucideIcons.trash2,
          label: 'Delete',
          danger: true,
          onTap: () => _confirmDelete(context),
        )
      else
        _ShareAction(
          icon: LucideIcons.shieldAlert,
          label: 'Report',
          danger: true,
          onTap: widget.onReport ?? () {},
        ),
    ];

    // Four to a row, so every action is visible without a second gesture.
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 4) {
      final end = (i + 4).clamp(0, actions.length);
      final slice = actions.sublist(i, end);
      rows.add(
        Row(
          children: [
            for (final action in slice) Expanded(child: action),
            // Keep the columns the same width when the last row is short.
            for (var j = slice.length; j < 4; j++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  static String _selectionTitle(List<ShareTarget> picked) {
    if (picked.isEmpty) return 'Share to';
    if (picked.length == 1) return 'Send to ${picked.first.name.split(' ').first}';
    return 'Send to ${picked.length} friends';
  }

  /// Only the owner may open the settings of a reel.
  void _notOwner(BuildContext context) {
    _toast('Only the owner can change these settings.');
  }

  /// Deletes the reel, after the owner confirms it.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text(
          'Delete this reel?',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'It is removed from your profile and from the feeds, for good.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: context.tokens.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).maybePop();
    widget.onDelete?.call();
  }

  /// The settings page of the reel, owner only.
  ///
  /// It is its own sheet: the share sheet stays small, and the settings are
  /// only there when they are asked for.
  void _openOwnerSettings(BuildContext context) {
    final t = context.tokens;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.borderStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    LucideIcon(LucideIcons.lock, size: 18, color: t.accent),
                    const SizedBox(width: 10),
                    Text(
                      'Settings (Privacy)',
                      style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'WHO CAN SEE THIS',
                  style: EnnvoText.overlineXs.copyWith(
                    color: t.textTertiary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final entry in const {
                      'public': 'Public',
                      'followers': 'Friends',
                      'private': 'Only Me',
                    }.entries)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _updateSettings(
                            _settings.copyWith(privacy: entry.key),
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _settings.privacy == entry.key
                                  ? _kShareBlue
                                  : t.surfaceAlt,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              entry.value,
                              style: EnnvoText.caption.copyWith(
                                color: _settings.privacy == entry.key
                                    ? Colors.white
                                    : t.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'MORE SETTINGS',
                  style: EnnvoText.overlineXs.copyWith(
                    color: t.textTertiary,
                    fontSize: 11,
                  ),
                ),
                _SettingsToggle(
                  icon: LucideIcons.messageCircle,
                  label: 'Turn off commenting',
                  value: _settings.commentsDisabled,
                  onChanged: (value) => _updateSettings(
                    _settings.copyWith(commentsDisabled: value),
                  ),
                ),
                _SettingsToggle(
                  icon: LucideIcons.repeat2,
                  label: 'Allow remixes',
                  value: _settings.allowRemix,
                  onChanged: (value) =>
                      _updateSettings(_settings.copyWith(allowRemix: value)),
                ),
                _SettingsToggle(
                  icon: LucideIcons.heart,
                  label: 'Hide like counts',
                  value: _settings.hideLikes,
                  onChanged: (value) =>
                      _updateSettings(_settings.copyWith(hideLikes: value)),
                ),
                _SettingsToggle(
                  icon: LucideIcons.download,
                  label: 'Save to device',
                  value: _settings.saveToDevice,
                  onChanged: (value) => _updateSettings(
                    _settings.copyWith(saveToDevice: value),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppGradients.create,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The "More" menu: the things that do not fit in the row.
  void _openMore(BuildContext context) {
    final t = context.tokens;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 7, bottom: 10),
                decoration: BoxDecoration(
                  color: t.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              _MoreRow(
                icon: LucideIcons.share2,
                label: 'Share to another app',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  _copy();
                },
              ),
              _MoreRow(
                icon: LucideIcons.userPlus,
                label: 'Add to a close friends list',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  widget.onAddStory();
                },
              ),
              _MoreRow(
                icon: LucideIcons.bookmark,
                label: 'Save the reel',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  widget.onSave();
                },
              ),
              if (!widget.isOwner)
                _MoreRow(
                  icon: LucideIcons.flag,
                  label: 'Report the reel',
                  onTap: () {
                    Navigator.of(sheetContext).maybePop();
                    widget.onReport?.call();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One friend in the top row
// ============================================================================
class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.target,
    required this.isSelected,
    required this.onTap,
  });

  final ShareTarget target;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _kShareBlue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  AnimatedScale(
                    scale: isSelected ? 0.94 : 1,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.surfaceAlt,
                        image: target.avatarUrl.isEmpty
                            ? null
                            : DecorationImage(
                                image: NetworkImage(target.avatarUrl),
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: target.avatarUrl.isEmpty
                          ? Text(
                              target.name.isEmpty
                                  ? '?'
                                  : target.name.characters.first.toUpperCase(),
                              style: EnnvoText.bodySemi.copyWith(
                                color: t.textSecondary,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kShareBlue,
                          border: Border.all(color: t.surface, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const LucideIcon(
                          LucideIcons.check,
                          size: 9,
                          strokeWidth: 3.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              target.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: EnnvoText.tiny.copyWith(
                color: isSelected ? _kShareBlue : t.textSecondary,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.active = false,
    this.busy = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = danger
        ? t.danger
        : active
        ? _kShareBlue
        : t.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: active
                    ? _kShareBlue.withValues(alpha: 0.12)
                    : t.surfaceAlt,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: active ? _kShareBlue.withValues(alpha: 0.45) : t.border,
                ),
              ),
              alignment: Alignment.center,
              child: busy
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    )
                  : LucideIcon(
                      icon,
                      size: 21,
                      strokeWidth: 2,
                      color: accent,
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: EnnvoText.tiny.copyWith(
                color: danger
                    ? t.danger
                    : active
                    ? _kShareBlue
                    : t.textSecondary,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  One row of the "More" menu
// ============================================================================
class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            LucideIcon(icon, size: 19, strokeWidth: 1.9, color: t.textPrimary),
            const SizedBox(width: 14),
            Text(
              label,
              style: EnnvoText.body.copyWith(color: t.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          LucideIcon(icon, size: 17, strokeWidth: 1.9, color: t.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: EnnvoText.body.copyWith(color: t.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: t.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: t.borderStrong,
          ),
        ],
      ),
    );
  }
}
