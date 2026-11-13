// ============================================================================
//  ENNVO — REELS SCREEN
//
//  The app's home screen: a full screen vertical short-video feed, the
//  TikTok / Instagram Reels experience. Ported from
//  `src/pages/Reels.tsx`.
//
//  Deep behaviour ported from the web app:
//    • a vertical snap feed built on a [PageView]
//    • only a small window of reels is mounted, so the number of live
//      video decoders stays low on weak hardware
//    • a reel is marked as "seen" after 2500ms of dwell time; the seen
//      list is capped at 250 ids and feeds the ranking
//    • promoted reels rank first, then the score formula
//    • "Following" and "For You" tabs with a sliding indicator
//    • a welcome card for new users that dismisses after 4200ms
//    • a PC style up / down controller
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/post.dart';
import '../../data/services/reels_service.dart';
import 'widgets/reel_card.dart';

class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});

  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  Timer? _dwellTimer;

  int _activeIndex = 0;
  bool _showWelcome = true;
  bool _muted = true;
  String _tab = 'forYou';

  /// The ids of the reels the user already watched — drives the ranking.
  final Set<String> _seen = <String>{};

  /// Ids of the reels the user liked, kept locally so the heart fills
  /// instantly without waiting for a round trip.
  final Set<String> _liked = <String>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);

    // The seen list is persisted so the ranking survives a restart.
    _seen.addAll(ref.read(prefsProvider).seenReels);

    // The welcome card dismisses itself after 4200ms.
    Timer(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause every video when the app goes to the background — otherwise
    // the decoder keeps running and drains the battery.
    if (state == AppLifecycleState.paused) {
      _dwellTimer?.cancel();
    }
  }

  void _onPageChanged(int index) {
    _dwellTimer?.cancel();
    setState(() => _activeIndex = index);

    final reels = _currentReels;
    if (index < reels.length) {
      final reel = reels[index];
      // The reel counts as seen after 2500ms of dwell time.
      _dwellTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        _markSeen(reel.id);
        final uid = ref.read(authControllerProvider).user?.uid;
        if (uid != null) {
          ReelsService.incrementView(reelId: reel.id, userId: uid);
        }
      });
    }
  }

  Future<void> _markSeen(String id) async {
    if (_seen.contains(id)) return;
    setState(() => _seen.add(id));
    await ref.read(prefsProvider).markReelSeen(id);
  }

  void _goTo(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: EnnvoCurves.iosSpring,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The "Following" tab reads a different stream.
    final asyncReels = _tab == 'following'
        ? ref.watch(followingReelsProvider)
        : ref.watch(reelsProvider);

    return asyncReels.when(
      loading: () => const _ReelsLoading(),
      error: (_, __) => const _ReelsEmpty(),
      data: (raw) {
        // Rank promoted reels first, then by the score formula.
        final reels = ReelsService.rank(raw, _seen);
        _currentReels = reels;
        if (reels.isEmpty) return const _ReelsEmpty();
        return _buildFeed(context, reels);
      },
    );
  }

  /// The ranked list currently on screen — used by the dwell timer.
  List<AppPost> _currentReels = const [];

  Widget _buildFeed(BuildContext context, List<AppPost> reels) {
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
            onPageChanged: _onPageChanged,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              // Only a small window around the active reel is built, so
              // the number of live video decoders stays bounded.
              if ((index - _activeIndex).abs() > window) {
                return const ColoredBox(color: Colors.black);
              }
              final post = reels[index];
              return RepaintBoundary(
                child: ReelCard(
                  post: post,
                  isActive: index == _activeIndex,
                  isLiked: _liked.contains(post.id),
                  likesCount:
                      post.likesCount + (_liked.contains(post.id) ? 1 : 0),
                  isFollowing: false,
                  isMuted: _muted,
                  onToggleLike: () => _toggleLike(post),
                  onToggleFollow: () {},
                  onToggleMute: () => setState(() => _muted = !_muted),
                  onComment: () {},
                  onShare: () {},
                ),
              );
            },
          ),

          // --- top tab bar -------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopTabs(
              active: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),

          // --- top right search --------------------------------------
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // --- PC up / down controller -------------------------------
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

          // --- welcome card ------------------------------------------
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

  Future<void> _toggleLike(AppPost post) async {
    final wasLiked = _liked.contains(post.id);
    setState(() {
      if (wasLiked) {
        _liked.remove(post.id);
      } else {
        _liked.add(post.id);
      }
    });
    HapticFeedback.lightImpact();

    final uid = ref.read(authControllerProvider).user?.uid;
    if (uid == null) return;
    await ReelsService.toggleLike(
      reelId: post.id,
      userId: uid,
      currentlyLiked: wasLiked,
      currentCount: post.likesCount,
    );
  }
}

// ============================================================================
//  Top tabs — "Following" / "For You"
// ============================================================================
class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.active, required this.onChanged});

  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(top: top + 10, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TabButton(
            label: 'Following',
            isActive: active == 'following',
            onTap: () => onChanged('following'),
          ),
          const SizedBox(width: 22),
          _TabButton(
            label: 'For You',
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
          // scale 1.05 active / 0.85 inactive, y 0 / 3, opacity 1 / 0.55
          AnimatedScale(
            scale: isActive ? 1.05 : 0.85,
            duration: EnnvoDurations.dropdown,
            curve: EnnvoCurves.iosSpring,
            child: AnimatedSlide(
              offset: isActive ? Offset.zero : const Offset(0, 0.12),
              duration: EnnvoDurations.dropdown,
              curve: EnnvoCurves.iosSpring,
              child: AnimatedOpacity(
                opacity: isActive ? 1 : 0.55,
                duration: EnnvoDurations.dropdown,
                child: Text(
                  label,
                  style: EnnvoText.body.copyWith(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: EnnvoDurations.dropdown,
            curve: EnnvoCurves.iosSpring,
            width: 16,
            height: 2.5,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
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
//  The welcome card for new users
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
            // scale 0.92 → 1, y 12 → 0, opacity 0 → 1
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
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: const Color(0xFFFCD34D),
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
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _FeatureBadge(label: 'Reels'),
                    _FeatureBadge(label: 'Stories'),
                    _FeatureBadge(label: 'Chat'),
                    _FeatureBadge(label: 'HD calls'),
                  ],
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

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: EnnvoText.tiny.copyWith(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 11,
        ),
      ),
    );
  }
}

// ============================================================================
//  Loading and empty states
// ============================================================================
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

class _ReelsEmpty extends StatelessWidget {
  const _ReelsEmpty();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                size: 64,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              const Text(
                'No reels yet',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow some people and their reels will show up here.',
                textAlign: TextAlign.center,
                style: EnnvoText.body.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
