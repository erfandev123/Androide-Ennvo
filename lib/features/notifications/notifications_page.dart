// ============================================================================
//  ENNVO — NOTIFICATIONS SCREEN
//
//  Activity & Followers screen with glass capsule navigation, PageView swipe,
//  clean expandable earlier-activity deck, type badges, and follower search.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/notification.dart';
import '../../data/models/user.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/user_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../messages/messages_page.dart' show ChatScreen;

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key, this.modal = false});

  /// True when the page is opened from the inbox: the back button pops
  /// back to the inbox instead of switching shell page.
  final bool modal;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  /// 0 = Activity, 1 = Followers.
  int _activeTab = 0;

  bool _activityExpanded = false;
  late final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authControllerProvider).user?.uid ?? '';
      if (uid.isNotEmpty) {
        NotificationService.markAllRead(uid);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_activeTab == index && _pageController.hasClients) return;
    setState(() => _activeTab = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: EnnvoDurations.dropdownAlt,
        curve: EnnvoCurves.iosSpring,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final act = context.act;
    final notifications = ref.watch(notificationsProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: act.background,
      body: Stack(
        children: [
          // --- ambient glow ---------------------------------------------
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 0.9,
                    colors: [
                      act.accentGlow,
                      act.accentGlow.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- header ---------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, top + 12, 14, 8),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (widget.modal) {
                        Navigator.of(context).maybePop();
                      } else {
                        ref.read(navControllerProvider).backPage();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: LucideIcon(
                        LucideIcons.chevronLeft,
                        size: 24,
                        strokeWidth: 2.6,
                        color: act.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _activeTab == 0 ? 'Activity' : 'Followers',
                      style: EnnvoText.titleMd.copyWith(
                        color: act.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final prefs = ref.read(prefsProvider);
                      prefs.setDarkTheme(!prefs.isDarkTheme);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: act.cardBackground,
                        shape: BoxShape.circle,
                        border: Border.all(color: act.cardBorder),
                      ),
                      alignment: Alignment.center,
                      child: LucideIcon(
                        ref.watch(themeModeProvider) == ThemeMode.dark
                            ? LucideIcons.sun
                            : LucideIcons.moon,
                        size: 17,
                        strokeWidth: 2.2,
                        color: act.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- the two swipeable panes ----------------------------------
          Positioned.fill(
            top: top + 58,
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (_activeTab != index) {
                  setState(() => _activeTab = index);
                }
              },
              children: [
                _ActivityPane(
                  notifications: notifications,
                  expanded: _activityExpanded,
                  onToggleExpand: () => setState(
                    () => _activityExpanded = !_activityExpanded,
                  ),
                ),
                const _FollowersPane(),
              ],
            ),
          ),

          // --- floating glass navigation --------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: Center(
              child: _GlassCapsuleNav(
                activeIndex: _activeTab,
                onChanged: _switchTab,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Activity pane
// ============================================================================
class _ActivityPane extends ConsumerWidget {
  const _ActivityPane({
    required this.notifications,
    required this.expanded,
    required this.onToggleExpand,
  });

  final AsyncValue<List<AppNotification>> notifications;
  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final act = context.act;
    final me = ref.watch(authControllerProvider).user;

    return notifications.when(
      loading: () => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
      error: (_, __) => _EmptyActivity(act: act),
      data: (items) {
        if (items.isEmpty) return _EmptyActivity(act: act);

        final top = items.take(2).toList();
        final rest = items.skip(2).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            Row(
              children: [
                Text(
                  'RECENT ACTIVITY',
                  style: EnnvoText.overline.copyWith(color: act.textSecondary),
                ),
                const Spacer(),
                if (items.any((n) => !n.isRead) && me != null)
                  GestureDetector(
                    onTap: () => NotificationService.markAllRead(me.uid),
                    child: Text(
                      'Mark all read',
                      style: EnnvoText.caption.copyWith(
                        color: const Color(0xFF0095F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in top)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityCardContainer(notification: item),
              ),
            if (rest.isNotEmpty)
              _StackDeck(
                items: rest,
                expanded: expanded,
                onToggle: onToggleExpand,
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
//  Followers pane with live search
// ============================================================================
class _FollowersPane extends ConsumerStatefulWidget {
  const _FollowersPane();

  @override
  ConsumerState<_FollowersPane> createState() => _FollowersPaneState();
}

class _FollowersPaneState extends ConsumerState<_FollowersPane> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final act = context.act;
    final me = ref.watch(authControllerProvider).user;
    final followersAsync = ref.watch(followersProvider);
    final following =
        ref.watch(followingProvider).value ?? const <AppUser>[];
    final followingIds = following.map((u) => u.uid).toSet();

    return followersAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
      error: (_, __) => _empty(act),
      data: (followers) {
        if (followers.isEmpty) return _empty(act);

        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? followers
            : followers
                .where(
                  (u) =>
                      u.name.toLowerCase().contains(q) ||
                      u.username.toLowerCase().contains(q),
                )
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: act.cardBackground,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: act.cardBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: act.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        style: EnnvoText.body.copyWith(
                          color: act.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search followers...',
                          hintStyle: EnnvoText.body.copyWith(
                            color: act.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: act.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching followers',
                        style: EnnvoText.body.copyWith(
                          color: act.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        final isFollowing = followingIds.contains(person.uid);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: act.cardBackground,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            border: Border.all(color: act.cardBorder),
                          ),
                          child: Row(
                            children: [
                              _ActAvatar(
                                url: person.avatar,
                                name: person.name,
                                size: 42,
                                act: act,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name.isEmpty
                                          ? 'Ennvo User'
                                          : person.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: EnnvoText.bodySemi.copyWith(
                                        color: act.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (person.username.isNotEmpty)
                                      Text(
                                        '@${person.username}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: EnnvoText.caption.copyWith(
                                          color: act.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (me != null) ...[
                                TextButton(
                                  onPressed: () {
                                    if (isFollowing) {
                                      UserService.unfollow(
                                        myId: me.uid,
                                        otherId: person.uid,
                                      );
                                    } else {
                                      UserService.follow(me: me, other: person);
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Colors.transparent
                                        : const Color(0xFF0095F6),
                                    foregroundColor: isFollowing
                                        ? act.textSecondary
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: isFollowing
                                          ? BorderSide(color: act.cardBorder)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Text(
                                    isFollowing ? 'Following' : 'Follow back',
                                    style: EnnvoText.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Message',
                                  onPressed: () async {
                                    final id =
                                        await ChatService.createConversation(
                                      currentUserId: me.uid,
                                      otherUserId: person.uid,
                                      otherUserName: person.name,
                                      otherUserAvatar: person.avatar,
                                      currentUserName: me.name,
                                      currentUserAvatar: me.avatar,
                                    );
                                    if (!context.mounted) return;
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ChatScreen(
                                          conversationId: id,
                                          title: person.name.isEmpty
                                              ? 'Chat'
                                              : person.name,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                    color: act.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(ActTokens act) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              LucideIcons.userPlus,
              size: 48,
              strokeWidth: 1.6,
              color: act.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'No new followers yet',
              textAlign: TextAlign.center,
              style: EnnvoText.titleMd.copyWith(color: act.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'When someone new follows you they will show up here.',
              textAlign: TextAlign.center,
              style: EnnvoText.body.copyWith(color: act.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  Expandable Earlier Activity Deck (zero text overlap)
// ============================================================================
class _StackDeck extends StatelessWidget {
  const _StackDeck({
    required this.items,
    required this.expanded,
    required this.onToggle,
  });

  final List<AppNotification> items;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final act = context.act;
    final hiddenCount = items.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: act.textSecondary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      'EARLIER (${items.length})',
                      style: EnnvoText.overline.copyWith(
                        color: act.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      expanded ? 'Collapse' : 'Show all',
                      style: EnnvoText.caption.copyWith(
                        color: act.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: EnnvoCurves.iosSpring,
                      child: LucideIcon(
                        LucideIcons.chevronDown,
                        size: 17,
                        strokeWidth: 2.2,
                        color: act.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Column(
            children: [
              _ActivityCardContainer(notification: items.first),
              if (hiddenCount > 0)
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: act.cardBackground.withValues(alpha: 0.72),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.xl),
                      ),
                      border: Border(
                        left: BorderSide(color: act.cardBorder),
                        right: BorderSide(color: act.cardBorder),
                        bottom: BorderSide(color: act.cardBorder),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'View $hiddenCount earlier ${hiddenCount == 1 ? 'notification' : 'notifications'}',
                      style: EnnvoText.caption.copyWith(
                        color: act.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          secondChild: Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityCardContainer(notification: item),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityCardContainer extends ConsumerWidget {
  const _ActivityCardContainer({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final act = context.act;
    final me = ref.watch(authControllerProvider).user;

    final fetched = notification.actorId.isNotEmpty &&
            (notification.actorName.isEmpty ||
                notification.actorAvatar.isEmpty)
        ? ref.watch(userProfileProvider(notification.actorId)).value
        : null;

    final displayName = notification.actorName.isNotEmpty
        ? notification.actorName
        : (fetched?.name.isNotEmpty == true ? fetched!.name : 'Ennvo User');
    final displayAvatar = notification.actorAvatar.isNotEmpty
        ? notification.actorAvatar
        : (fetched?.avatar ?? '');

    return GestureDetector(
      onTap: me == null || notification.actorId.isEmpty
          ? null
          : () async {
              final convId = await ChatService.createConversation(
                currentUserId: me.uid,
                otherUserId: notification.actorId,
                otherUserName: displayName,
                otherUserAvatar: displayAvatar,
                currentUserName: me.name,
                currentUserAvatar: me.avatar,
              );
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    conversationId: convId,
                    title: displayName,
                  ),
                ),
              );
            },
      child: Container(
        decoration: BoxDecoration(
          color: act.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: notification.isRead
                ? act.cardBorder
                : const Color(0xFF0095F6).withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: act.cardShine.withValues(alpha: 0.35),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: _ActivityCard(
          notification: notification,
          displayName: displayName,
          displayAvatar: displayAvatar,
        ),
      ),
    );
  }
}

// ============================================================================
//  One activity card with type badge & Web-safe image rendering
// ============================================================================
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.notification,
    required this.displayName,
    required this.displayAvatar,
  });

  final AppNotification notification;
  final String displayName;
  final String displayAvatar;

  @override
  Widget build(BuildContext context) {
    final act = context.act;
    final badge = _badgeStyle(notification.type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _ActAvatar(
              url: displayAvatar,
              name: displayName,
              size: 42,
              act: act,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: badge.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: act.background, width: 1.8),
                ),
                alignment: Alignment.center,
                child: Icon(badge.icon, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: displayName,
                  style: EnnvoText.bodySemi.copyWith(
                    color: act.textPrimary,
                    fontSize: 13.5,
                  ),
                  children: [
                    TextSpan(
                      text: ' ${notification.activityText}',
                      style: EnnvoText.body.copyWith(
                        color: act.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.createdAt != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _relativeTime(notification.createdAt!),
                      style: EnnvoText.tiny.copyWith(
                        color: act.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0095F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        if (notification.postMedia != null &&
            notification.postMedia!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                notification.postMedia!,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 42,
                  height: 42,
                  color: act.cardBackground,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: act.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static _BadgeStyle _badgeStyle(NotificationType type) => switch (type) {
    NotificationType.like || NotificationType.commentLike =>
      const _BadgeStyle(Icons.favorite_rounded, Color(0xFFFE2C55)),
    NotificationType.comment || NotificationType.reply =>
      const _BadgeStyle(Icons.mode_comment_rounded, Color(0xFF0095F6)),
    NotificationType.follow =>
      const _BadgeStyle(Icons.person_add_rounded, Color(0xFF8B5CF6)),
    NotificationType.repost =>
      const _BadgeStyle(Icons.repeat_rounded, Color(0xFF10B981)),
    NotificationType.favorite =>
      const _BadgeStyle(Icons.bookmark_rounded, Color(0xFFF59E0B)),
    NotificationType.mention =>
      const _BadgeStyle(Icons.alternate_email_rounded, Color(0xFF6366F1)),
  };

  static String _relativeTime(DateTime time) {
    final delta = DateTime.now().difference(time);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    return '${delta.inDays ~/ 7}w';
  }
}

class _BadgeStyle {
  const _BadgeStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}

class _ActAvatar extends StatelessWidget {
  const _ActAvatar({
    required this.url,
    required this.name,
    required this.size,
    required this.act,
  });

  final String url;
  final String name;
  final double size;
  final ActTokens act;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: act.cardBackground,
        border: Border.all(color: act.cardBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: EnnvoText.bodySemi.copyWith(color: act.textSecondary),
      ),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

// ============================================================================
//  Empty state
// ============================================================================
class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.act});

  final ActTokens act;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              LucideIcons.bell,
              size: 44,
              strokeWidth: 1.6,
              color: act.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'No activity yet',
              textAlign: TextAlign.center,
              style: EnnvoText.titleMd.copyWith(color: act.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Likes, comments and new followers will appear here.',
              textAlign: TextAlign.center,
              style: EnnvoText.body.copyWith(color: act.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The floating glass capsule navigation
// ============================================================================
class _GlassCapsuleNav extends StatelessWidget {
  const _GlassCapsuleNav({required this.activeIndex, required this.onChanged});

  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final act = context.act;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: act.glassNavBackground,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: act.glassNavBorder,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 45, offset: Offset(0, 18)),
        ],
      ),
      child: SizedBox(
        width: 260,
        height: 44,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 2;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: EnnvoCurves.iosBounce,
                  left: itemWidth * activeIndex,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: act.pillActiveBackground,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _CapsuleButton(
                      label: 'Activity',
                      isActive: activeIndex == 0,
                      act: act,
                      onTap: () => onChanged(0),
                    ),
                    _CapsuleButton(
                      label: 'Followers',
                      isActive: activeIndex == 1,
                      act: act,
                      onTap: () => onChanged(1),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.label,
    required this.isActive,
    required this.act,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final ActTokens act;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: EnnvoDurations.dropdown,
            style: EnnvoText.bodySemi.copyWith(
              color: isActive ? act.pillActiveText : act.pillInactiveText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
