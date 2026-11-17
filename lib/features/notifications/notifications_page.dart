// ============================================================================
//  ENNVO — NOTIFICATIONS SCREEN
//
//  The activity screen, ported from `src/pages/Notifications.tsx`.
//
//  The signature interaction is the iOS card-stack accordion: a stack of
//  cards that sits collapsed behind the top card and unrolls into a full
//  list when the banner is tapped. The geometry is taken straight from the
//  web app's CSS:
///
///    .act-stack-deck.is-collapsed .act-card-item:nth-child(1)
///      { margin-top: 0;    transform: translate3d(0, 0, 0)  scale(1);    z-index: 5; opacity: 1 }
///    …nth-child(2)  { margin-top: -54px; translate3d(0, 14px, 0) scale(.95); z-index: 4; opacity: .88 }
///    …nth-child(3)  { margin-top: -54px; translate3d(0, 27px, 0) scale(.89); z-index: 3; opacity: .65 }
///    …nth-child(n+4){ margin-top: -54px; translate3d(0, 38px, 0) scale(.83); z-index: 2; opacity: 0 }
///    .act-stack-deck.is-expanded .act-card-item
///      { margin-top: 10px; transform: translate3d(0, 0, 0) scale(1); opacity: 1 }
//
//  with a 0.52s `var(--ios-spring)` transition and a 0.03s stagger.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/notification.dart';
import '../../shared/icons/lucide_icons.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key, this.modal = false});

  /// True when the page is opened from the inbox: the back button goes
  /// home instead of pushing a new route.
  final bool modal;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with SingleTickerProviderStateMixin {
  /// 0 = Activity, 1 = Followers.
  int _activeTab = 0;

  bool _activityExpanded = false;
  bool _followersExpanded = false;

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
                    onTap: () => ref.read(navControllerProvider).backPage(),
                    child: const LucideIcon(
                      LucideIcons.chevronLeft,
                      size: 24,
                      strokeWidth: 2.6,
                      color: Colors.black,
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
                    child: LucideIcon(
                      ref.watch(themeModeProvider) == ThemeMode.dark
                          ? LucideIcons.sun
                          : LucideIcons.moon,
                      size: 18,
                      strokeWidth: 2.2,
                      color: act.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- the two panes --------------------------------------------
          Positioned.fill(
            top: top + 56,
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Transform.translate(
                  // The web app slides a 200% wide track by half its width.
                  offset: Offset(-_activeTab * 0.5 * _trackWidth(context), 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _trackWidth(context),
                        child: _ActivityPane(
                          notifications: notifications,
                          expanded: _activityExpanded,
                          onToggleExpand: () => setState(
                            () => _activityExpanded = !_activityExpanded,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: _trackWidth(context),
                        child: _FollowersPane(
                          expanded: _followersExpanded,
                          onToggleExpand: () => setState(
                            () => _followersExpanded = !_followersExpanded,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                onChanged: (index) {
                  _tabController.animateTo(
                    1.0,
                    duration: EnnvoDurations.dropdownAlt,
                    curve: EnnvoCurves.iosSpring,
                  );
                  setState(() => _activeTab = index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _trackWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

  late final AnimationController _tabController = AnimationController(
    vsync: this,
    duration: EnnvoDurations.dropdownAlt,
    value: 0,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ============================================================================
//  Activity pane
// ============================================================================
class _ActivityPane extends StatelessWidget {
  const _ActivityPane({
    required this.notifications,
    required this.expanded,
    required this.onToggleExpand,
  });

  final AsyncValue<List<AppNotification>> notifications;
  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final act = context.act;

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

        // The web app shows the two most recent activities on their own,
        // then collapses the rest into the accordion stack.
        final top = items.take(2).toList();
        final rest = items.skip(2).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            Text(
              'RECENT ACTIVITY',
              style: EnnvoText.overline.copyWith(color: act.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final item in top)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityCard(notification: item),
              ),
            if (rest.isNotEmpty)
              _StackDeck(
                items: rest,
                expanded: expanded,
                onToggle: onToggleExpand,
                builder: (item, index) => _ActivityCard(notification: item),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
//  Followers pane
// ============================================================================
class _FollowersPane extends StatelessWidget {
  const _FollowersPane({required this.expanded, required this.onToggleExpand});

  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final act = context.act;

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
//  The card-stack accordion
// ============================================================================
class _StackDeck extends StatelessWidget {
  const _StackDeck({
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.builder,
  });

  final List<AppNotification> items;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget Function(AppNotification item, int index) builder;

  /// The collapsed offsets, matching the CSS exactly.
  static const List<double> _collapsedOffsets = [0, 14, 27, 38];
  static const List<double> _collapsedScales = [1, 0.95, 0.89, 0.83];
  static const List<double> _collapsedOpacity = [1, 0.88, 0.65, 0];

  @override
  Widget build(BuildContext context) {
    final act = context.act;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- the banner handle ----------------------------------------
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
                    color: act.textSecondary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      'EARLIER',
                      style: EnnvoText.overline.copyWith(
                        color: act.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 400),
                      curve: EnnvoCurves.iosSpring,
                      child: LucideIcon(
                        LucideIcons.chevronDown,
                        size: 18,
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

        // --- the deck --------------------------------------------------
        Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = items.length - 1; i >= 0; i--)
              _StackCard(
                key: ValueKey(items[i].hashCode),
                item: items[i],
                index: i,
                expanded: expanded,
                builder: builder,
              ),
          ],
        ),
        SizedBox(height: expanded ? 0 : 60),
      ],
    );
  }
}

class _StackCard extends StatelessWidget {
  const _StackCard({
    super.key,
    required this.item,
    required this.index,
    required this.expanded,
    required this.builder,
  });

  final AppNotification item;
  final int index;
  final bool expanded;
  final Widget Function(AppNotification item, int index) builder;

  @override
  Widget build(BuildContext context) {
    final act = context.act;

    // The CSS `:nth-child(n+4)` rule hides everything past the third card.
    final depth = index.clamp(0, 3);

    final offset = expanded ? 0.0 : _StackDeck._collapsedOffsets[depth];
    final scale = expanded ? 1.0 : _StackDeck._collapsedScales[depth];
    final opacity = expanded
        ? 1.0
        : (index >= 3
              ? 0.0
              : _StackDeck._collapsedOpacity[depth]);

    // The 0.03s stagger.
    final delay = Duration(milliseconds: 30 * index);

    return AnimatedSlide(
      offset: Offset(0, expanded ? 0 : offset / 100),
      duration: EnnvoDurations.dropdown + delay,
      curve: EnnvoCurves.iosSpring,
      child: AnimatedScale(
        scale: scale,
        duration: EnnvoDurations.dropdown + delay,
        curve: EnnvoCurves.iosSpring,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 350),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: act.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(color: act.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: act.cardShine.withValues(alpha: 0.4),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: builder(item, index),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One activity card
// ============================================================================
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final act = context.act;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: act.cardBackground,
            image: notification.actorAvatar.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(notification.actorAvatar),
                    fit: BoxFit.cover,
                  ),
          ),
          child: notification.actorAvatar.isEmpty
              ? Center(
                  child: Text(
                    notification.actorName.isEmpty
                        ? '?'
                        : notification.actorName.characters.first.toUpperCase(),
                    style: EnnvoText.bodySemi.copyWith(color: act.textSecondary),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: notification.actorName,
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
                Text(
                  _relativeTime(notification.createdAt!),
                  style: EnnvoText.tiny.copyWith(
                    color: act.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (notification.postMedia != null && notification.postMedia!.isNotEmpty)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              image: DecorationImage(
                image: NetworkImage(notification.postMedia!),
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }

  static String _relativeTime(DateTime time) {
    final delta = DateTime.now().difference(time);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    return '${delta.inDays ~/ 7}w';
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
                // --- the sliding capsule --------------------------------
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: EnnvoCurves.iosBounce,
                  left: itemWidth * activeIndex,
                  top: 0,
                  bottom: 0,
                  width: itemWidth - 5,
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
                // --- the two buttons ------------------------------------
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
