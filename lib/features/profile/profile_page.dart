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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/post.dart';
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
                    data: (items) => _ProfileGrid(
                      posts: items,
                      tab: _tab,
                    ),
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
                      onPressed: () {},
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
                      onPressed: () {},
                      icon: const LucideIcon(
                        LucideIcons.share2,
                        size: 20,
                        strokeWidth: 2.2,
                        color: textPrimary,
                      ),
                      tooltip: 'Share',
                    ),
                    IconButton(
                      onPressed: () {},
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
          child: Row(
            children: [
              _Stat(value: posts, label: 'posts'),
              const SizedBox(width: 26),
              _Stat(value: followers, label: 'followers'),
              const SizedBox(width: 26),
              _Stat(value: following, label: 'following'),
            ],
          ),
        ),

        // --- action row ------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Row(
            children: [
              Expanded(
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
              const SizedBox(width: 8),
              Container(
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                      ),
                      padding: const EdgeInsets.all(2),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFAF5FF),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Image.network(
                        highlights[index],
                        fit: BoxFit.cover,
                        cacheWidth: 180,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
            image: url.isEmpty
                ? null
                : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
          ),
          child: url.isEmpty
              ? Center(
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: EnnvoText.pageHero.copyWith(
                      color: const Color(0xFF6B7280),
                      fontSize: 32,
                    ),
                  ),
                )
              : null,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: EnnvoText.bodySemi.copyWith(
            color: const Color(0xFF111827),
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: EnnvoText.caption.copyWith(
            color: const Color(0xFF6B7280),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
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
//  Grid
// ============================================================================
class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.posts, required this.tab});

  final List<AppPost> posts;
  final ProfileTab tab;

  @override
  Widget build(BuildContext context) {
    if (tab == ProfileTab.private) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          children: [
            LucideIcon(
              LucideIcons.lock,
              size: 40,
              strokeWidth: 1.6,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 12),
            Text(
              'Only Me',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'This section is private. Make it public to share these posts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Nothing here yet',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: posts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemBuilder: (context, index) {
          final post = posts[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: post.media.isEmpty
                ? const ColoredBox(color: Color(0xFFF3E8FF))
                : Image.network(
                    post.media.first,
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFFF3E8FF)),
                  ),
          );
        },
      ),
    );
  }
}
