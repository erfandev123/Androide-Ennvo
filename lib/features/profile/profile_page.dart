// ============================================================================
//  ENNVO — PROFILE SCREEN
//
//  Ported from `src/pages/Profile.tsx`.
//
//  Deliberate exceptions from the rest of the app, reproduced exactly:
//    • the profile page is **always light**, even in dark mode
//    • the background is a lavender gradient
//      `linear-gradient(to bottom, #e9d5ff, #f3e8ff, #faf5ff)`
//    • the floating top navigation bar overlaps the banner
//    • the avatar moves to the right when a banner is present
//    • the verified badge sits at the bottom-right of the avatar
//
//  The five tabs — Posts, Reels, Reposts, Saved, Private — share one
//  spring underline (`stiffness 450, damping 34`).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../shared/icons/lucide_icons.dart';

enum ProfileTab { posts, reels, reposts, saved, private }

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  ProfileTab _tab = ProfileTab.posts;

  late final AnimationController _tabController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final posts = ref.watch(userPostsProvider);
    final saved = ref.watch(savedPostsProvider);
    return Scaffold(
      // The profile page stays light in dark mode — the web app's
      // `.profile-page-root` does the same.
      backgroundColor: const Color(0xFFFAF5FF),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    name: user?.name ?? 'Your profile',
                    username: user?.username ?? '',
                    avatarUrl: user?.avatar ?? '',
                    bannerUrl: user?.bannerUrl ?? '',
                    isVerified: user?.isVerified ?? false,
                    bio: user?.bio ?? '',
                    followers: user?.followersCount ?? 0,
                    following: user?.followingCount ?? 0,
                    posts: user?.postsCount ?? 0,
                    highlights: user?.highlights ?? const [],
                    onBack: () =>
                        ref.read(navControllerProvider).backPage(),
                    onShare: () => _shareProfile(context, user),
                    onMenu: () => _openMenu(context),
                    onEditProfile: () =>
                        ref.read(navControllerProvider).pushPage(AppPage.editProfile),
                    onFindFriends: () =>
                        ref.read(navControllerProvider).pushPage(AppPage.search),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProfileTabs(
                    active: _tab,
                    onChanged: (tab) {
                      _tabController.forward(from: 0);
                      setState(() => _tab = tab);
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: posts.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (items) {
                      // The same five tabs the web app shows on a profile.
                      final visible = switch (_tab) {
                        ProfileTab.posts => items
                            .where(
                              (post) =>
                                  post.type != PostType.reel &&
                                  post.privacy != PostPrivacy.private,
                            )
                            .toList(),
                        ProfileTab.reels => items
                            .where(
                              (post) =>
                                  post.type == PostType.reel &&
                                  post.privacy != PostPrivacy.private,
                            )
                            .toList(),
                        ProfileTab.private => items
                            .where(
                              (post) => post.privacy == PostPrivacy.private,
                            )
                            .toList(),
                        ProfileTab.saved => saved.value ?? const <AppPost>[],
                        ProfileTab.reposts => const <AppPost>[],
                      };
                      return _ProfileGrid(posts: visible, tab: _tab);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Copies the public address of the profile, the way the web app's
  /// "Share profile" does.
  Future<void> _shareProfile(BuildContext context, AppUser? user) async {
    final handle = user?.username ?? '';
    final link = handle.isEmpty
        ? 'https://ennvo.app'
        : 'https://ennvo.app/u/$handle';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        content: Text(
          handle.isEmpty
              ? 'Your Ennvo link is copied'
              : 'ennvo.app/u/$handle is copied',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// The menu of the top bar: settings, edit profile, sign out.
  Future<void> _openMenu(BuildContext context) async {
    final nav = ref.read(navControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: AppShadows.settingsPanel,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _MenuRow(
                icon: LucideIcons.settings,
                label: 'Settings',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  nav.pushPage(AppPage.settings);
                },
              ),
              _MenuRow(
                icon: LucideIcons.user,
                label: 'Edit profile',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  nav.pushPage(AppPage.editProfile);
                },
              ),
              _MenuRow(
                icon: LucideIcons.logOut,
                label: 'Sign out',
                danger: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(authControllerProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the profile menu.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF0F172A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            LucideIcon(icon, size: 19, strokeWidth: 2.2, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: EnnvoText.bodySemi.copyWith(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  Header
// ============================================================================
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.isVerified,
    required this.bio,
    required this.followers,
    required this.following,
    required this.posts,
    required this.highlights,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
    required this.onEditProfile,
    required this.onFindFriends,
  });

  final String name;
  final String username;
  final String avatarUrl;
  final String bannerUrl;
  final bool isVerified;
  final String bio;
  final int followers;
  final int following;
  final int posts;
  final List<String> highlights;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMenu;
  final VoidCallback onEditProfile;
  final VoidCallback onFindFriends;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- banner ----------------------------------------------------
        SizedBox(
          height: 148,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bannerUrl.isNotEmpty)
                Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  errorBuilder: (_, __, ___) => const _BannerFallback(),
                )
              else
                const _BannerFallback(),

              // The banner fades into the page background.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFFFAF5FF), Color(0x00FAF5FF)],
                    ),
                  ),
                ),
              ),

              // --- floating top bar ------------------------------------
              Positioned(
                top: top + 6,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const LucideIcon(
                        LucideIcons.chevronLeft,
                        size: 24,
                        strokeWidth: 2.4,
                        color: textPrimary,
                      ),
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onShare,
                      icon: const LucideIcon(
                        LucideIcons.share2,
                        size: 20,
                        strokeWidth: 2.2,
                        color: textPrimary,
                      ),
                      tooltip: 'Share profile',
                    ),
                    IconButton(
                      onPressed: onMenu,
                      icon: const LucideIcon(
                        LucideIcons.moreHorizontal,
                        size: 20,
                        strokeWidth: 2.2,
                        color: textPrimary,
                      ),
                      tooltip: 'More',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- avatar + identity -----------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // The avatar sits on the right when a banner is present.
              if (bannerUrl.isEmpty) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Identity(
                        name: name,
                        username: username,
                        isVerified: isVerified,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _ProfileAvatar(
                  url: avatarUrl,
                  name: name,
                  isVerified: isVerified,
                ),
              ] else ...[
                _ProfileAvatar(
                  url: avatarUrl,
                  name: name,
                  isVerified: isVerified,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _Identity(
                      name: name,
                      username: username,
                      isVerified: isVerified,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // --- stats -----------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x12000000)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(value: posts, label: 'posts'),
                Container(
                  width: 1,
                  height: 24,
                  color: const Color(0x14000000),
                ),
                _Stat(value: followers, label: 'followers'),
                Container(
                  width: 1,
                  height: 24,
                  color: const Color(0x14000000),
                ),
                _Stat(value: following, label: 'following'),
              ],
            ),
          ),
        ),

        // --- action row ------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEditProfile,
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Text(
                      'Edit profile',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onFindFriends,
                child: Container(
                  width: 42,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: const Color(0x1F000000)),
                  ),
                  child: const LucideIcon(
                    LucideIcons.userPlus,
                    size: 18,
                    strokeWidth: 2.2,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- bio -------------------------------------------------------
        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              bio,
              style: EnnvoText.body.copyWith(color: textPrimary),
            ),
          ),

        // --- highlights -------------------------------------------------
        if (highlights.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              itemCount: highlights.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    // Flutter 3.50 removed `BoxDecoration.padding`.
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFAF5FF),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: Image.network(
                          highlights[index],
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 180,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Highlight',
                    style: EnnvoText.tiny.copyWith(
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9D5FF), Color(0xFFF3E8FF), Color(0xFFFAF5FF)],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.username,
    required this.isVerified,
  });

  final String name;
  final String username;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EnnvoText.titleMd.copyWith(
                  color: const Color(0xFF111827),
                  fontSize: 20,
                ),
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              const LucideIcon(
                LucideIcons.badgeCheck,
                size: 17,
                strokeWidth: 2.4,
                color: Color(0xFF1D9BF0),
              ),
            ],
          ],
        ),
        if (username.isNotEmpty)
          Text(
            '@$username',
            style: EnnvoText.caption.copyWith(
              color: const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.url,
    required this.name,
    required this.isVerified,
  });

  final String url;
  final String name;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0x14000000), width: 1),
          ),
          alignment: Alignment.center,
          child: url.isEmpty
              ? Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: EnnvoText.pageHero.copyWith(
                    color: const Color(0xFF6B7280),
                    fontSize: 32,
                  ),
                )
              : ClipOval(
                  child: Image.network(
                    url,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: EnnvoText.pageHero.copyWith(
                        color: const Color(0xFF6B7280),
                        fontSize: 32,
                      ),
                    ),
                  ),
                ),
        ),
        if (isVerified)
          const Positioned(
            right: 2,
            bottom: 2,
            child: LucideIcon(
              LucideIcons.badgeCheck,
              size: 22,
              strokeWidth: 2.2,
              color: Color(0xFF1D9BF0),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatProfileMetric(value),
          style: EnnvoText.bodySemi.copyWith(
            color: const Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: EnnvoText.caption.copyWith(
            color: const Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

String _formatProfileMetric(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
  }
  return '$value';
}

// ============================================================================
//  Tabs
// ============================================================================
class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.active, required this.onChanged});

  final ProfileTab active;
  final ValueChanged<ProfileTab> onChanged;

  static const List<(ProfileTab, String)> _tabs = [
    (ProfileTab.posts, 'Posts'),
    (ProfileTab.reels, 'Reels'),
    (ProfileTab.reposts, 'Reposts'),
    (ProfileTab.saved, 'Saved'),
    (ProfileTab.private, 'Private'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 18, 8, 0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x14000000)),
        ),
      ),
      child: Row(
        children: [
          for (final (tab, label) in _tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(tab),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: EnnvoText.label.copyWith(
                          color: tab == active
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF),
                          fontWeight: tab == active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: const SpringCurve(EnnvoSprings.profileTab),
                        height: 2.5,
                        width: tab == active ? 26 : 0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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
//  Grid (TikTok-style vertical reel boxes + rounded post cards)
// ============================================================================
class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.posts, required this.tab});

  final List<AppPost> posts;
  final ProfileTab tab;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      final (icon, headline, subtitle) = switch (tab) {
        ProfileTab.reels => (
            LucideIcons.film,
            'No reels yet',
            'Your vertical reels will show up here.',
          ),
        ProfileTab.saved => (
            LucideIcons.bookmark,
            'No saved posts yet',
            'Save posts you want to revisit anytime.',
          ),
        ProfileTab.reposts => (
            LucideIcons.repeat,
            'No reposts yet',
            'Posts you amplify will appear here.',
          ),
        ProfileTab.private => (
            LucideIcons.lock,
            'No private posts',
            'Only-me posts stay tucked away here.',
          ),
        ProfileTab.posts => (
            LucideIcons.image,
            'Nothing posted yet',
            'Share a photo or thought to fill your grid.',
          ),
      };

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.85),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                alignment: Alignment.center,
                child: LucideIcon(
                  icon,
                  size: 20,
                  strokeWidth: 2,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                headline,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isReelsTab = tab == ProfileTab.reels;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: posts.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          // TikTok-style tall vertical reel cards on Reels tab, balanced
          // portrait cards on Posts/Saved/Private tabs.
          childAspectRatio: isReelsTab ? 0.62 : 0.86,
        ),
        itemBuilder: (context, index) {
          final post = posts[index];
          return GestureDetector(
            onTap: () => _openPostPreview(context, post),
            child: isReelsTab || post.isReel
                ? _ProfileReelBox(post: post)
                : _ProfilePostBox(post: post),
          );
        },
      ),
    );
  }

  void _openPostPreview(BuildContext context, AppPost post) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ProfilePostPreviewDialog(post: post),
    );
  }
}

class _ProfileReelBox extends StatelessWidget {
  const _ProfileReelBox({required this.post});

  final AppPost post;

  static const List<List<Color>> _reelBackdrops = [
    [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
    [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0C4A6E)],
    [Color(0xFF3B0764), Color(0xFF701A75), Color(0xFF1E1B4B)],
    [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF0F172A)],
  ];

  @override
  Widget build(BuildContext context) {
    final poster = (post.thumbnailUrl?.trim().isNotEmpty == true)
        ? post.thumbnailUrl!.trim()
        : (post.media.isNotEmpty && post.mediaIsImage ? post.media.first : '');
    final backdrop = _reelBackdrops[post.id.hashCode.abs() % _reelBackdrops.length];
    final metric = post.viewsCount > 0 ? post.viewsCount : post.likesCount;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backdrop,
        ),
        border: Border.all(color: const Color(0x1A000000), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (poster.isNotEmpty)
            Image.network(
              poster,
              fit: BoxFit.cover,
              cacheWidth: 420,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          // Centered frosted play emblem when there's no poster image
          if (poster.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    if (post.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Top-right subtle Reel badge
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.film,
                size: 12,
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
          ),

          // Bottom gradient scrim + TikTok-style play & count overlay
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB8000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 7,
            right: 7,
            bottom: 7,
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Text(
                  _formatProfileMetric(metric),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 4,
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

class _ProfilePostBox extends StatelessWidget {
  const _ProfilePostBox({required this.post});

  final AppPost post;

  static const List<List<Color>> _textGradients = [
    [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF0EA5E9)],
    [Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFFF97316)],
    [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF22C55E)],
    [Color(0xFFF43F5E), Color(0xFF9333EA), Color(0xFF4F46E5)],
    [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
  ];

  List<Color> _resolveTextColors() {
    final bg = post.background?.trim() ?? '';
    final hexMatches = RegExp(r'#([0-9a-fA-F]{6})').allMatches(bg).toList();
    if (hexMatches.isNotEmpty) {
      final parsed = [
        for (final m in hexMatches)
          Color(int.parse('FF${m.group(1)!}', radix: 16)),
      ];
      return parsed.length == 1 ? [parsed.first, parsed.first] : parsed;
    }
    return _textGradients[post.id.hashCode.abs() % _textGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = post.media.isNotEmpty;
    final hasVideo = post.videoUrl != null;
    final imageUrl = post.mediaIsImage && hasMedia
        ? post.media.first
        : (post.thumbnailUrl?.trim() ?? '');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF3E8FF),
        border: Border.all(color: const Color(0x14000000), width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!hasMedia)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _resolveTextColors(),
                ),
              ),
              padding: const EdgeInsets.all(10),
              alignment: Alignment.center,
              child: Text(
                post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            )
          else if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: 420,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE9D5FF), Color(0xFFD8B4FE)],
                  ),
                ),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F2937), Color(0xFF0F172A)],
                ),
              ),
            ),

          if (post.media.length > 1)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${post.media.length - 1}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else if (hasVideo)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),

          if (hasMedia && post.likesCount > 0) ...[
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x88000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 7,
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatProfileMetric(post.likesCount),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

class _ProfilePostPreviewDialog extends StatefulWidget {
  const _ProfilePostPreviewDialog({required this.post});

  final AppPost post;

  @override
  State<_ProfilePostPreviewDialog> createState() =>
      _ProfilePostPreviewDialogState();
}

class _ProfilePostPreviewDialogState extends State<_ProfilePostPreviewDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.post.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controller = ctrl;
      ctrl.initialize().then((_) {
        if (!mounted) return;
        ctrl.setLooping(true);
        ctrl.play();
        setState(() => _ready = true);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasVideo = post.videoUrl != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasVideo)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 360,
                  color: const Color(0xFF0F172A),
                  child: _ready && _controller != null
                      ? GestureDetector(
                          onTap: () {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                            setState(() {});
                          },
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: _controller!.value.size.width == 0
                                  ? 1
                                  : _controller!.value.size.width,
                              height: _controller!.value.size.height == 0
                                  ? 1
                                  : _controller!.value.size.height,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                ),
              )
            else if (post.media.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: Image.network(
                    post.media.first,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (post.text.isNotEmpty) ...[
              if (post.media.isNotEmpty) const SizedBox(height: 12),
              Text(
                post.text,
                style: EnnvoText.body.copyWith(color: const Color(0xFF111827)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${_formatProfileMetric(post.likesCount)} likes · ${_formatProfileMetric(post.commentsCount)} comments',
                  style: EnnvoText.caption.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
