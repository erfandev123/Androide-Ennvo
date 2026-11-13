// ============================================================================
//  ENNVO — FEED SCREEN
//
//  The Facebook-style home feed: a stories strip on top and the posts
//  below. Ported from `src/pages/Home.tsx`.
//
//  Layout:
//    • mobile header — search on the left, the "ennvo" wordmark in the
//      middle, notifications and create on the right
//    • the stories strip — squircle cards, `rounded-[24px]`, 96×142
//      (110×162 on a wide screen)
//    • the posts list
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/post.dart';
import '../../data/services/story_service.dart';
import '../../shared/icons/lucide_icons.dart';
import 'widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final Set<String> _liked = <String>{};
  final Set<String> _reposted = <String>{};

  Future<void> _refresh() async {
    ref.invalidate(feedProvider);
    ref.invalidate(storiesProvider);
    await ref.read(feedProvider.future).catchError((_) => <AppPost>[]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final feed = ref.watch(feedProvider);
    final stories = ref.watch(storiesProvider);

    return Scaffold(
      backgroundColor: t.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: t.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // --- header -------------------------------------------------
            SliverToBoxAdapter(
              child: _FeedHeader(
                onSearch: () =>
                    ref.read(navControllerProvider).pushPage(AppPage.search),
              ),
            ),

            // --- stories ------------------------------------------------
            SliverToBoxAdapter(
              child: stories.when(
                loading: () => const SizedBox(height: 8),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _StoriesStrip(stories: items),
              ),
            ),

            // --- posts --------------------------------------------------
            feed.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: _FeedEmpty(
                  title: 'Could not load the feed',
                  subtitle: 'Pull down to try again.',
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: _FeedEmpty(
                      title: 'Your feed is empty',
                      subtitle:
                          'Follow a few people and their posts will show up here.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  sliver: SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return RepaintBoundary(
                        child: PostCard(
                          post: post,
                          isLiked: _liked.contains(post.id),
                          isReposted: _reposted.contains(post.id),
                          likesCount:
                              post.likesCount + (_liked.contains(post.id) ? 1 : 0),
                          onToggleLike: () => setState(() {
                            if (!_liked.remove(post.id)) _liked.add(post.id);
                          }),
                          onToggleRepost: () => setState(() {
                            if (!_reposted.remove(post.id)) {
                              _reposted.add(post.id);
                            }
                          }),
                        ),
                      );
                    },
                  ),
                );
              },
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
class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 10, 8, 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSearch,
            child: LucideIcon(
              LucideIcons.search,
              size: 22,
              strokeWidth: 2.2,
              color: t.textPrimary,
            ),
          ),
          const Spacer(),
          const Text('ennvo', style: EnnvoText.pageHero),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: LucideIcon(
              LucideIcons.bell,
              size: 22,
              strokeWidth: 2.2,
              color: t.textPrimary,
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () {},
            icon: LucideIcon(
              LucideIcons.plus,
              size: 22,
              strokeWidth: 2.3,
              color: t.textPrimary,
            ),
            tooltip: 'Create',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Stories strip
// ============================================================================
class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip({required this.stories});

  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 640;

    return SizedBox(
      height: wide ? 162 + 16 : 142 + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = stories[index];
          return SizedBox(
            width: wide ? 110 : 96,
            child: _StoryCard(story: story, isDark: t.isDark, wide: wide),
          );
        },
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.isDark,
    required this.wide,
  });

  final Story story;
  final bool isDark;

  /// True on a screen at least 640 logical pixels wide, where the web app
  /// uses the larger `110 x 162` story card.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      children: [
        Expanded(
          child: Container(
            // Flutter 3.50 removed `BoxDecoration.padding`, so the inset
            // lives on the container itself.
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                wide ? AppRadius.storyLarge : AppRadius.story,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFFEC4899)],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  (wide ? AppRadius.storyLarge : AppRadius.story) - 2.5,
                ),
                color: isDark ? const Color(0xFF101014) : Colors.white,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          (wide ? AppRadius.storyLarge : AppRadius.story) - 10,
                        ),
                        child: story.mediaUrl.isEmpty
                            ? ColoredBox(color: t.surfaceAlt)
                            : Image.network(
                                story.mediaUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 360,
                                errorBuilder: (_, __, ___) =>
                                    ColoredBox(color: t.surfaceAlt),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                    child: Text(
                      story.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: EnnvoText.tiny.copyWith(
                        color: t.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  Empty state
// ============================================================================
class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(
            LucideIcons.fileText,
            size: 44,
            strokeWidth: 1.6,
            color: t.textTertiary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: EnnvoText.body.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
