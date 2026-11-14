// ============================================================================
//  ENNVO — REELS SCREEN
//
//  The app's home screen: a full screen vertical short-video feed.
//
//  The behaviour comes from the reels prototype and the Ennvo web app:
//
//    • a vertical snap feed built on a [PageView]
//    • only a small window around the active reel is built, so the number of
//      live video decoders stays bounded on a weak phone
//    • the neighbour is prepared (paused) and the rest is released
//    • a progress bar tracks the active reel
//    • "Following" and "For You" tabs with a sliding underline
//    • a welcome card for new users that dismisses itself
//    • the comments and share portals open as bottom sheets
//    • a reel counts as seen after 2500ms of dwell time, and the seen list
//      feeds the ranking
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/post.dart';
import '../../data/services/reels_service.dart';
import '../../shared/icons/lucide_icons.dart';
import 'demo_reels.dart';
import 'models/reel_comment.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/reel_card.dart';
import 'widgets/reel_preloader.dart';
import 'widgets/share_sheet.dart';

class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});

  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;

  int _activeIndex = 0;
  double _progress = 0;
  bool _muted = true;
  bool _showWelcome = true;
  String _tab = 'forYou';

  final Set<String> _liked = <String>{};
  final Set<String> _saved = <String>{};
  final Set<String> _reposted = <String>{};
  final Set<String> _following = <String>{};
  final Set<String> _seen = <String>{};

  /// The comments of each reel, kept locally so the sheet is instant.
  final Map<String, List<ReelComment>> _comments = <String, List<ReelComment>>{};

  Timer? _dwellTimer;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);

    _seen.addAll(ref.read(prefsProvider).seenReels);

    // The welcome card dismisses itself after 4200ms.
    _welcomeTimer = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _welcomeTimer?.cancel();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _dwellTimer?.cancel();
  }

  List<AppPost> _currentReels = const [];

  void _onPageChanged(int index, List<AppPost> reels) {
    _dwellTimer?.cancel();
    setState(() {
      _activeIndex = index;
      _progress = 0;
    });

    if (index >= reels.length) return;
    final reel = reels[index];

    // Warm the connections to the videos that are about to be shown, so the
    // swipe lands on an already warm path.
    final upcoming = <String?>[];
    for (var i = index + 1; i <= index + 3 && i < reels.length; i++) {
      final next = reels[i];
      final nextDemo = demoReelFor(next.id);
      upcoming.add(nextDemo == null ? _videoUrlOf(next) : null);
    }
    ReelPreloader.warmAll(upcoming, count: 2);

    // The reel counts as seen after 2500ms of dwell time.
    _dwellTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (_seen.add(reel.id)) {
        ref.read(prefsProvider).markReelSeen(reel.id);
      }
    });

    // Near the end of the feed the next page is fetched, so the feed never
    // runs out.
    if (index >= reels.length - 3) {
      unawaited(_loadMore(reels));
    }
  }

  /// The video URL of a post.
  static String? _videoUrlOf(AppPost post) =>
      post.media.isNotEmpty ? post.media.first : null;

  /// The reels that are on screen, including the pages that were loaded
  /// while the user was scrolling.
  final List<AppPost> _extraReels = <AppPost>[];

  bool _loadingMore = false;
  bool _hasMore = true;

  /// Loads the next page of reels when the user nears the end.
  Future<void> _loadMore(List<AppPost> current) async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;

    final oldest = current
        .where((r) => r.createdAt != null)
        .fold<AppPost?>(null, (a, b) => a == null || b.createdAt!.isBefore(a.createdAt!) ? b : a);

    if (oldest?.createdAt == null) {
      _loadingMore = false;
      _hasMore = false;
      return;
    }

    final more = await ReelsService.fetchMore(before: oldest!.createdAt!);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (more.isEmpty) {
        _hasMore = false;
      } else {
        final known = {...current.map((r) => r.id), ..._extraReels.map((r) => r.id)};
        _extraReels.addAll(more.where((r) => !known.contains(r.id)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncReels = _tab == 'following'
        ? ref.watch(followingReelsProvider)
        : ref.watch(reelsProvider);

    return asyncReels.when(
      loading: () => const _ReelsLoading(),
      error: (_, __) => _buildFeed(context, demoReelsAsPosts()),
      data: (items) {
        final base = items.isEmpty ? demoReelsAsPosts() : items;
        return _buildFeed(context, [...base, ..._extraReels]);
      },
    );
  }

  Widget _buildFeed(BuildContext context, List<AppPost> reels) {
    _currentReels = reels;
    final device = ref.watch(deviceProfileProvider);
    final window = device.reelWindow;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // --- the vertical snap feed --------------------------------
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const PageScrollPhysics(),
            onPageChanged: (index) => _onPageChanged(index, reels),
            itemCount: reels.length,
            itemBuilder: (context, index) {
              // Only a small window around the active reel is built.
              if ((index - _activeIndex).abs() > window) {
                return const ColoredBox(color: Colors.black);
              }
              final post = reels[index];
              final demo = demoReelFor(post.id);

              return RepaintBoundary(
                child: ReelCard(
                  post: post,
                  isActive: index == _activeIndex,
                  isNear: (index - _activeIndex).abs() <= 1,
                  isLiked: _liked.contains(post.id),
                  isSaved: _saved.contains(post.id),
                  isReposted: _reposted.contains(post.id),
                  isFollowing: _following.contains(post.authorId),
                  likesCount:
                      (post.likesCount) + (_liked.contains(post.id) ? 1 : 0),
                  commentsCount: post.commentsCount,
                  favouritesCount:
                      post.favoritesCount + (_saved.contains(post.id) ? 1 : 0),
                  sharesCount:
                      post.repostsCount + (_reposted.contains(post.id) ? 1 : 0),
                  muted: _muted,
                  onProgress: (value) {
                    if (index != _activeIndex || !mounted) return;
                    setState(() => _progress = value);
                  },
                  onToggleLike: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (!_liked.remove(post.id)) _liked.add(post.id);
                    });
                  },
                  onToggleSave: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (!_saved.remove(post.id)) _saved.add(post.id);
                    });
                  },
                  onToggleRepost: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (!_reposted.remove(post.id)) _reposted.add(post.id);
                    });
                  },
                  onToggleFollow: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (!_following.remove(post.authorId)) {
                        _following.add(post.authorId);
                      }
                    });
                  },
                  onToggleMute: () {
                    setState(() => _muted = !_muted);
                  },
                  onOpenComments: () => _openComments(post),
                  onOpenShare: () => _openShare(post),
                ),
              );
            },
          ),

          // --- the tabs ----------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopTabs(
              active: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),

          // --- the search button --------------------------------------
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            right: 6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(navControllerProvider).pushPage(AppPage.search),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: LucideIcon(
                  LucideIcons.search,
                  size: 24,
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // --- the progress bar --------------------------------------
          Positioned(
            left: 16,
            right: 16,
            // Just above the black navigation bar.
            bottom: MediaQuery.paddingOf(context).bottom + 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),

          // --- the PC up / down controller ----------------------------
          if (MediaQuery.sizeOf(context).width >= 900)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: _VerticalPager(
                  canGoUp: _activeIndex > 0,
                  canGoDown: _activeIndex < reels.length - 1,
                  onUp: () => _goTo(_activeIndex - 1),
                  onDown: () => _goTo(_activeIndex + 1),
                ),
              ),
            ),

          // --- the welcome card ---------------------------------------
          if (_showWelcome)
            Positioned.fill(
              child: IgnorePointer(
                child: _WelcomeOverlay(
                  onDismiss: () => setState(() => _showWelcome = false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _goTo(int index) {
    if (!_pageController.hasClients) return;
    if (index < 0 || index >= _currentReels.length) return;
    unawaited(
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: EnnvoCurves.iosSpring,
      ),
    );
  }

  void _openComments(AppPost post) {
    final comments = _comments.putIfAbsent(
      post.id,
      () => demoComments(post.id),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => ReelCommentsSheet(
        comments: comments,
        replierName: post.authorName,
        onSubmit: (text, replyTo) async {
          final comment = ReelComment(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            authorId: 'me',
            authorName: 'You',
            authorAvatar: '',
            kind: CommentKind.text,
            text: text,
            createdAt: DateTime.now(),
            likesCount: 0,
            isOwn: true,
            replyToId: replyTo?.id,
            replyToName: replyTo?.authorName,
          );
          setState(() {
            if (replyTo != null) {
              _comments[post.id] = [
                for (final existing in comments)
                  if (existing.id == replyTo.id)
                    existing.copyWith(
                      replies: [...existing.replies, comment],
                    )
                  else
                    existing,
              ];
            } else {
              _comments[post.id] = [comment, ...comments];
            }
          });
        },
        onToggleLike: (comment) {
          setState(() {
            _comments[post.id] = [
              for (final existing in comments)
                if (existing.id == comment.id)
                  existing.copyWith(
                    isLiked: !existing.isLiked,
                    likesCount:
                        existing.likesCount + (existing.isLiked ? -1 : 1),
                  )
                else
                  existing,
            ];
          });
        },
        onDelete: (comment) {
          setState(() {
            _comments[post.id] = [
              for (final existing in comments)
                if (existing.id != comment.id) existing,
            ];
          });
        },
      ),
    );
  }

  void _openShare(AppPost post) {
    const targets = [
      ShareTarget(id: '1', name: 'Arif Hasan', isOnline: true),
      ShareTarget(id: '2', name: 'Tania Akter'),
      ShareTarget(id: '3', name: 'Rafi Ahmed'),
      ShareTarget(id: '4', name: 'Mim', isOnline: true),
      ShareTarget(id: '5', name: 'Sakib'),
      ShareTarget(id: '6', name: 'Nabila'),
      ShareTarget(id: '7', name: 'Tuhin'),
      ShareTarget(id: '8', name: 'Ritu'),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => ReelShareSheet(
        targets: targets,
        onSend: (selected) async {},
        onRepost: () {},
        onSave: () {},
        onCopyLink: () async {
          await Clipboard.setData(
            ClipboardData(text: 'https://ennvo.app/reel/${post.id}'),
          );
        },
        onAddStory: () {},
      ),
    );
  }
}

// ============================================================================
//  The "Following" / "For You" tabs
// ============================================================================
class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.active, required this.onChanged});

  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TabButton(
            label: 'Following',
            isActive: active == 'following',
            onTap: () => onChanged('following'),
          ),
          const SizedBox(width: 18),
          _TabButton(
            label: 'For you',
            isActive: active == 'forYou',
            onTap: () => onChanged('forYou'),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The prototype animates the opacity and the scale together.
          AnimatedScale(
            scale: isActive ? 1 : 0.84,
            duration: const Duration(milliseconds: 450),
            curve: EnnvoCurves.iosSpring,
            child: AnimatedSlide(
              offset: isActive ? Offset.zero : const Offset(0, 0.12),
              duration: const Duration(milliseconds: 450),
              curve: EnnvoCurves.iosSpring,
              child: AnimatedOpacity(
                opacity: isActive ? 1 : 0.6,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  label,
                  style: EnnvoText.bodySemi.copyWith(
                    color: Colors.white,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // The underline grows from the centre with a scaleX.
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: EnnvoCurves.iosSpring,
            width: 18,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
            foregroundDecoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
            transform: Matrix4.identity()..scale(
              isActive ? 1.0 : 0.0,
              1.0,
              1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The PC up / down controller
// ============================================================================
class _VerticalPager extends StatelessWidget {
  const _VerticalPager({
    required this.canGoUp,
    required this.canGoDown,
    required this.onUp,
    required this.onDown,
  });

  final bool canGoUp;
  final bool canGoDown;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PagerButton(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: canGoUp,
            onTap: onUp,
          ),
          Container(
            width: 16,
            height: 1,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          _PagerButton(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: canGoDown,
            onTap: onDown,
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 22,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ============================================================================
//  The welcome card
// ============================================================================
class _WelcomeOverlay extends StatelessWidget {
  const _WelcomeOverlay({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: EnnvoDurations.welcomeOverlay,
          curve: EnnvoCurves.iosSpring,
          builder: (context, value, child) {
            final scale = 0.92 + (0.08 * value);
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xE60B101E),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: AppShadows.welcomeCard,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.iconRing,
                        boxShadow: AppShadows.iconRing,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0A0F1D),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'e',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: const LucideIcon(
                        LucideIcons.sparkles,
                        size: 20,
                        strokeWidth: 1.8,
                        color: Color(0xFFFCD34D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1A0EA5E9),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: const Color(0x400EA5E9)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Welcome to Ennvo',
                        style: EnnvoText.tiny.copyWith(
                          color: const Color(0xFF7DD3FC),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your feed, ready',
                  textAlign: TextAlign.center,
                  style: EnnvoText.pageHero,
                ),
                const SizedBox(height: 10),
                Text(
                  'Reels, stories and the people you follow — all in one place.',
                  textAlign: TextAlign.center,
                  style: EnnvoText.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0EA5E9),
                        Color(0xFF2563EB),
                        Color(0xFF4F46E5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.ctaSky,
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Start watching',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelsLoading extends StatelessWidget {
  const _ReelsLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Colors.white24),
          ),
        ),
      ),
    );
  }
}

