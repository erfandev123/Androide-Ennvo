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

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/message.dart';
import '../../data/models/post.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/comment_service.dart';
import '../../data/services/media_download_service.dart';
import '../../data/services/post_service.dart';
import '../../data/services/story_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../reels/models/reel_comment.dart';
import '../reels/widgets/comments_sheet.dart';
import '../reels/widgets/share_sheet.dart';
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

  /// One story box per author, the way the web feed groups its tray.
  static List<Story> _uniqueStories(List<Story> items) {
    final seen = <String>{};
    final unique = <Story>[];
    for (final story in items) {
      final key = story.authorId.isEmpty ? story.id : story.authorId;
      if (seen.add(key)) unique.add(story);
    }
    return unique;
  }

  /// Likes a post, or takes the like back.
  ///
  /// The icon answers at once and the write follows in the background: a
  /// slow network never delays the tap.
  void _toggleLike(AppPost post) {
    HapticFeedback.lightImpact();
    final liked = _liked.contains(post.id);
    setState(() {
      if (liked) {
        _liked.remove(post.id);
      } else {
        _liked.add(post.id);
      }
    });

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    PostService.toggleLike(
      postId: post.id,
      userId: user.uid,
      currentlyLiked: liked,
      currentCount: post.likesCount,
    );
  }

  /// Reposts a post, or takes the repost back.
  void _toggleRepost(AppPost post) {
    HapticFeedback.lightImpact();
    final reposted = _reposted.contains(post.id);
    setState(() {
      if (reposted) {
        _reposted.remove(post.id);
      } else {
        _reposted.add(post.id);
      }
    });

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    PostService.toggleRepost(
      postId: post.id,
      userId: user.uid,
      currentlyReposted: reposted,
      currentCount: post.repostsCount,
    );
  }

  /// The comments of a feed post, in the same sheet the reels use.
  Future<void> _openComments(AppPost post) async {
    final user = ref.read(authControllerProvider).user;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final asyncComments = ref.watch(commentsProvider(post.id));
          final comments = asyncComments.value ?? const <ReelComment>[];

          return ReelCommentsSheet(
            comments: comments,
            replierName: post.authorName,
            avatarUrl: user?.avatar ?? '',
            userName: user?.name ?? 'You',
            postAuthorId: post.authorId,
            currentUserId: user?.uid ?? '',
            onSubmit: (text, replyTo) async {
              if (user == null || text.trim().isEmpty) return;
              await CommentService.add(
                postId: post.id,
                text: text,
                authorId: user.uid,
                authorName: user.name,
                authorAvatar: user.avatar,
                parentId: replyTo?.id,
              );
            },
            onToggleLike: (comment) {
              if (user == null) return;
              CommentService.toggleLike(
                postId: post.id,
                commentId: comment.id,
                userId: user.uid,
                currentlyLiked: comment.isLiked,
              );
            },
            onDelete: (comment) {
              CommentService.delete(postId: post.id, commentId: comment.id);
            },
          );
        },
      ),
    );
  }

  /// Sends a post to the people the user already talks to.
  Future<void> _openShare(AppPost post) async {
    final user = ref.read(authControllerProvider).user;
    final conversations =
        ref.read(conversationsProvider).value ?? const <Conversation>[];

    final targets = <ShareTarget>[];
    for (final conversation in conversations) {
      final otherId = conversation.participantIds.firstWhere(
        (id) => id != user?.uid,
        orElse: () => '',
      );
      if (otherId.isEmpty) continue;
      targets.add(
        ShareTarget(
          id: conversation.id,
          name:
              conversation.participantNames[otherId] ??
              conversation.groupName ??
              'Someone',
          avatarUrl:
              conversation.participantAvatars[otherId] ??
              conversation.groupAvatar ??
              '',
          isOnline: false,
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => ReelShareSheet(
        targets: targets,
        isOwner: user?.uid != null && user!.uid == post.authorId,
        hasReposted: _reposted.contains(post.id),
        onSend: (selected, message) async {
          final media = post.media.isNotEmpty ? post.media.first : null;
          for (final target in selected) {
            await ChatService.sendMessage(
              conversationId: target.id,
              messageId: 'local-${DateTime.now().microsecondsSinceEpoch}',
              senderId: user?.uid ?? '',
              type: MessageType.image,
              content: message.isEmpty ? 'Shared a post' : message,
              mediaUrl: media,
              postId: post.id,
            );
          }
        },
        onRepost: () => _toggleRepost(post),
        onSave: () {
          HapticFeedback.lightImpact();
          if (user != null) {
            PostService.toggleSave(postId: post.id, userId: user.uid);
          }
        },
        onCopyLink: () async {
          await Clipboard.setData(
            ClipboardData(text: 'https://ennvo.app/post/${post.id}'),
          );
        },
        onAddStory: () async {
          if (user == null) return;
          final media = post.media.isNotEmpty ? post.media.first : '';
          if (media.isEmpty) return;
          await StoryService.shareReel(
            authorId: user.uid,
            authorName: user.name,
            authorAvatar: user.avatar,
            mediaUrl: media,
            mediaType: post.mediaIsImage ? 'image' : 'video',
            title: post.text,
          );
        },
        onMessage: () {
          ref.read(navControllerProvider).setCurrentPage(AppPage.messages);
        },
        onDownload: () async {
          final media = post.media.isNotEmpty ? post.media.first : '';
          if (!media.startsWith('http')) return;
          final extension = media.contains('.')
              ? media.substring(media.lastIndexOf('.') + 1).split('?').first
              : (post.mediaIsImage ? 'jpg' : 'mp4');
          await MediaDownloadService.download(
            media,
            fileName: 'ennvo_${post.id}.$extension',
          );
        },
        onReport: () {
          final me = ref.read(authControllerProvider).user;
          FirebaseFirestore.instance.collection('reports').add({
            'type': 'post',
            'postId': post.id,
            'authorId': post.authorId,
            'reporterId': me?.uid ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        },
        onDelete: () {
          FirebaseFirestore.instance
              .collection('posts')
              .doc(post.id)
              .delete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final feed = ref.watch(feedProvider);
    final stories = ref.watch(storiesProvider);
    final me = ref.watch(authControllerProvider).user;

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
                onCreate: () =>
                    ref.read(navControllerProvider).pushPage(AppPage.create),
              ),
            ),

            // --- stories ------------------------------------------------
            SliverToBoxAdapter(
              child: stories.when(
                loading: () => const SizedBox(height: 8),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => _StoriesStrip(
                  stories: _uniqueStories(items),
                  viewerAvatar: me?.avatar ?? '',
                  viewerName: me?.name ?? '',
                  onAdd: () =>
                      ref.read(navControllerProvider).pushPage(AppPage.create),
                ),
              ),
            ),

            // --- the Facebook style composer ----------------------------
            SliverToBoxAdapter(
              child: _ComposerCard(
                name: me?.name ?? '',
                avatar: me?.avatar ?? '',
                onTap: () =>
                    ref.read(navControllerProvider).pushPage(AppPage.create),
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
                          onToggleLike: () => _toggleLike(post),
                          onToggleRepost: () => _toggleRepost(post),
                          onComment: () => _openComments(post),
                          onShare: () => _openShare(post),
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
//
//  Search on the left, the "ennvo" wordmark in the middle, the create button
//  on the right. The notification bell is gone: the inbox tab carries it.
// ============================================================================
class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.onSearch, required this.onCreate});

  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 6),
      child: Row(
        children: [
          _HeaderButton(
            icon: LucideIcons.search,
            onTap: onSearch,
            semanticLabel: 'Search',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/brand/ennvo_logo.png',
                    width: 26,
                    height: 26,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.square(
                      dimension: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'ennvo',
                  style: EnnvoText.pageHero.copyWith(
                    color: t.textPrimary,
                    fontSize: 27,
                    height: 1,
                    letterSpacing: -1.2,
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 3, top: 13),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ),
          _HeaderButton(
            icon: LucideIcons.plus,
            onTap: onCreate,
            filled: true,
            semanticLabel: 'Create post',
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
  });

  final String icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? t.textPrimary : t.surfaceAlt,
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            icon,
            size: 20,
            strokeWidth: filled ? 2.8 : 2.2,
            color: filled ? t.background : t.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The composer
//
//  The Facebook style box: the picture of the user, the question and the
//  three ways to start a post. Every one of them opens the create screen.
// ============================================================================
class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.name,
    required this.avatar,
    required this.onTap,
  });

  final String name;
  final String avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: t.border),
          boxShadow: t.isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  _FeedAvatar(url: avatar, name: name, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "What's on your mind?",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.body.copyWith(
                            color: t.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  _ComposerAction(
                    icon: LucideIcons.image,
                    label: 'Photo',
                    color: const Color(0xFF22C55E),
                    onTap: onTap,
                  ),
                  _ComposerAction(
                    icon: LucideIcons.video,
                    label: 'Video',
                    color: const Color(0xFFEF4444),
                    onTap: onTap,
                  ),
                  _ComposerAction(
                    icon: LucideIcons.film,
                    label: 'Reel',
                    color: t.accent,
                    onTap: onTap,
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

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LucideIcon(icon, size: 18, strokeWidth: 2.2, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: EnnvoText.bodySemi.copyWith(
                  color: t.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedAvatar extends StatelessWidget {
  const _FeedAvatar({
    required this.url,
    required this.name,
    required this.size,
  });

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceAlt,
        image: url.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
            )
          : null,
    );
  }
}


// ============================================================================
//  Stories strip
//
//  The Facebook shape: one rounded card per author, the picture filling it,
//  the avatar on the top left and the name on the bottom over a soft scrim.
//  The first card is always the viewer's own — "Add story".
// ============================================================================
class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip({
    required this.stories,
    required this.viewerAvatar,
    required this.viewerName,
    required this.onAdd,
  });

  final List<Story> stories;
  final String viewerAvatar;
  final String viewerName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        itemCount: stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryTile(
              label: 'Add story',
              avatarUrl: viewerAvatar,
              fallbackName: viewerName,
              mediaUrl: viewerAvatar,
              isAdd: true,
              onTap: onAdd,
            );
          }
          final story = stories[index - 1];
          return _StoryTile(
            label: story.authorName.isEmpty ? 'Story' : story.authorName,
            avatarUrl: story.authorAvatar,
            fallbackName: story.authorName,
            mediaUrl: story.mediaUrl,
            isDark: t.isDark,
            onTap: () {},
          );
        },
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.label,
    required this.avatarUrl,
    required this.fallbackName,
    required this.mediaUrl,
    required this.onTap,
    this.isAdd = false,
    this.isDark = false,
  });

  final String label;
  final String avatarUrl;
  final String fallbackName;
  final String mediaUrl;
  final VoidCallback onTap;
  final bool isAdd;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.story),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- the picture --------------------------------------------
              if (mediaUrl.isEmpty)
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF71D2FD), Color(0xFF2AA1FB)],
                    ),
                  ),
                )
              else
                Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE0F2FE),
                  ),
                ),

              // --- the scrim that keeps the name readable -----------------
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xB3000000),
                    ],
                    stops: [0, 0.28, 0.58, 1],
                  ),
                ),
              ),

              // --- the avatar ---------------------------------------------
              Positioned(
                top: 8,
                left: 8,
                child: _StoryAvatar(
                  url: avatarUrl,
                  name: fallbackName,
                  isAdd: isAdd,
                ),
              ),

              // --- the name ------------------------------------------------
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EnnvoText.tiny.copyWith(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.url,
    required this.name,
    required this.isAdd,
  });

  final String url;
  final String name;
  final bool isAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 6),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE0F2FE),
                image: url.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(url),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: url.isEmpty
                  ? Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                      ),
                    )
                  : null,
            ),
          ),
          if (isAdd)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2AA1FB),
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.plus,
                  size: 9,
                  strokeWidth: 3.4,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
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
