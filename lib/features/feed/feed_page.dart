// ============================================================================
//  ENNVO — FEED SCREEN
//
//  The Facebook-style home feed: a stories strip on top, quick composer card,
//  and the posts below. Ported from `src/pages/Home.tsx`.
// ============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/message.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/comment_service.dart';
import '../../data/services/media_download_service.dart';
import '../../data/services/post_service.dart';
import '../../data/services/story_service.dart';
import '../../data/services/user_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../../shared/widgets/story_viewer.dart';
import '../create/camera_page.dart';
import '../create/create_page.dart';
import '../messages/messages_page.dart' show ChatScreen;
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
  final Set<String> _saved = <String>{};
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

  void _openStoryViewer(List<Story> stories, int index) {
    if (stories.isEmpty || index < 0 || index >= stories.length) return;
    final uid = ref.read(authControllerProvider).user?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryViewerPage(
          stories: stories,
          initialIndex: index,
          currentUserId: uid,
        ),
      ),
    );
  }

  Future<void> _openCreatePost({XFile? mediaFile, bool isVideo = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePage(mediaFile: mediaFile, isVideo: isVideo),
      ),
    );
  }

  Future<void> _pickPhotoAndCreate() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (!mounted) return;
      await _openCreatePost(mediaFile: photo);
    } catch (_) {
      if (mounted) {
        await _openCreatePost();
      }
    }
  }

  Future<void> _pickVideoAndCreate() async {
    try {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (!mounted) return;
      if (video == null) {
        await _openCreatePost();
        return;
      }
      await _openCreatePost(mediaFile: video, isVideo: true);
    } catch (_) {
      if (mounted) {
        await _openCreatePost();
      }
    }
  }

  Future<void> _openReelCapture() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CameraPage()),
    );
  }

  Future<void> _openAuthorProfile(AppPost post) async {
    final me = ref.read(authControllerProvider).user;
    if (post.authorId.isEmpty) return;

    if (me != null && post.authorId == me.uid) {
      ref.read(navControllerProvider).setCurrentPage(AppPage.profile);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AuthorProfileSheet(
        authorId: post.authorId,
        fallbackName: post.authorName,
        fallbackUsername: post.authorUsername ?? '',
        fallbackAvatar: post.authorAvatar,
        currentUser: me,
        onOpenChat: (conversationId, title) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ChatScreen(conversationId: conversationId, title: title),
            ),
          );
        },
      ),
    );
  }

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

  void _toggleSave(AppPost post) {
    HapticFeedback.lightImpact();
    final saved = _saved.contains(post.id);
    setState(() {
      if (saved) {
        _saved.remove(post.id);
      } else {
        _saved.add(post.id);
      }
    });

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    PostService.toggleSave(postId: post.id, userId: user.uid);
  }

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
          name: conversation.participantNames[otherId] ??
              conversation.groupName ??
              'Someone',
          avatarUrl: conversation.participantAvatars[otherId] ??
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
              type: media != null ? MessageType.image : MessageType.text,
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
    final isLite = ref.watch(deviceProfileProvider).isLite;

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
                onCreate: () => _openCreatePost(),
              ),
            ),

            // --- stories ------------------------------------------------
            SliverToBoxAdapter(
              child: stories.when(
                loading: () => const SizedBox(height: 8),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) {
                  final unique = _uniqueStories(items);
                  return _StoriesStrip(
                    stories: unique,
                    viewerId: me?.uid ?? '',
                    viewerAvatar: me?.avatar ?? '',
                    viewerName: me?.name ?? '',
                    onAdd: () => _openCreatePost(),
                    onOpenStory: (index) => _openStoryViewer(unique, index),
                  );
                },
              ),
            ),

            // --- the Facebook style composer ----------------------------
            SliverToBoxAdapter(
              child: _ComposerCard(
                name: me?.name ?? '',
                avatar: me?.avatar ?? '',
                isLite: isLite,
                onTap: () => _openCreatePost(),
                onPhoto: _pickPhotoAndCreate,
                onVideo: _pickVideoAndCreate,
                onReel: _openReelCapture,
              ),
            ),

            // --- posts --------------------------------------------------
            feed.when(
              loading: () => const SliverToBoxAdapter(
                child: _FeedLoadingSkeleton(),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: _FeedEmpty(
                  title: 'Could not load the feed',
                  subtitle: 'Pull down or tap below to try again.',
                  onRetry: _refresh,
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _FeedEmpty(
                      title: 'Your feed is empty',
                      subtitle:
                          'Follow a few people or create your first post.',
                      onRetry: _refresh,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 90),
                  sliver: SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return RepaintBoundary(
                        child: PostCard(
                          post: post,
                          isLite: isLite,
                          isLiked: _liked.contains(post.id),
                          isSaved: _saved.contains(post.id),
                          isReposted: _reposted.contains(post.id),
                          likesCount:
                              post.likesCount + (_liked.contains(post.id) ? 1 : 0),
                          favoritesCount: post.favoritesCount +
                              (_saved.contains(post.id) ? 1 : 0),
                          onToggleLike: () => _toggleLike(post),
                          onToggleSave: () => _toggleSave(post),
                          onToggleRepost: () => _toggleRepost(post),
                          onOpenProfile: () => _openAuthorProfile(post),
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
//  Author quick profile sheet (Follow + Message)
// ============================================================================
class _AuthorProfileSheet extends StatefulWidget {
  const _AuthorProfileSheet({
    required this.authorId,
    required this.fallbackName,
    required this.fallbackUsername,
    required this.fallbackAvatar,
    required this.currentUser,
    required this.onOpenChat,
  });

  final String authorId;
  final String fallbackName;
  final String fallbackUsername;
  final String fallbackAvatar;
  final AppUser? currentUser;
  final void Function(String conversationId, String title) onOpenChat;

  @override
  State<_AuthorProfileSheet> createState() => _AuthorProfileSheetState();
}

class _AuthorProfileSheetState extends State<_AuthorProfileSheet> {
  AppUser? _author;
  bool _following = false;
  bool _loadingFollow = false;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await UserService.profiles([widget.authorId]);
    final myUid = widget.currentUser?.uid ?? '';
    final isFollow = myUid.isEmpty
        ? false
        : await UserService.isFollowing(myUid, widget.authorId);
    if (!mounted) return;
    setState(() {
      if (profiles.isNotEmpty) _author = profiles.first;
      _following = isFollow;
    });
  }

  Future<void> _toggleFollow() async {
    final me = widget.currentUser;
    if (me == null || _loadingFollow) return;
    final target = _author ??
        AppUser(
          uid: widget.authorId,
          name: widget.fallbackName,
          username: widget.fallbackUsername,
          email: '',
          avatar: widget.fallbackAvatar,
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
        );

    setState(() => _loadingFollow = true);
    if (_following) {
      await UserService.unfollow(myId: me.uid, otherId: widget.authorId);
    } else {
      await UserService.follow(me: me, other: target);
    }
    if (!mounted) return;
    setState(() {
      _following = !_following;
      _loadingFollow = false;
    });
  }

  Future<void> _startMessage() async {
    final me = widget.currentUser;
    if (me == null || _openingChat) return;
    setState(() => _openingChat = true);
    final name = _author?.name ?? widget.fallbackName;
    final avatar = _author?.avatar ?? widget.fallbackAvatar;
    final id = await ChatService.createConversation(
      currentUserId: me.uid,
      otherUserId: widget.authorId,
      otherUserName: name,
      otherUserAvatar: avatar,
      currentUserName: me.name,
      currentUserAvatar: me.avatar,
    );
    if (!mounted) return;
    setState(() => _openingChat = false);
    widget.onOpenChat(id, name.isEmpty ? 'Chat' : name);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = (_author?.name.isNotEmpty == true)
        ? _author!.name
        : widget.fallbackName;
    final username = (_author?.username.isNotEmpty == true)
        ? _author!.username
        : widget.fallbackUsername;
    final avatar = (_author?.avatar.isNotEmpty == true)
        ? _author!.avatar
        : widget.fallbackAvatar;
    final bio = _author?.bio ?? '';

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.borderStrong,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          _FeedAvatar(url: avatar, name: name, size: 68),
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? 'User' : name,
            style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '@$username',
              style: EnnvoText.caption.copyWith(color: t.textSecondary),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bio,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: EnnvoText.body.copyWith(
                color: t.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (widget.currentUser != null)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loadingFollow ? null : _toggleFollow,
                    style: FilledButton.styleFrom(
                      backgroundColor: _following ? t.surfaceAlt : t.accent,
                      foregroundColor: _following ? t.textPrimary : Colors.white,
                    ),
                    child: Text(_following ? 'Following' : 'Follow'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openingChat ? null : _startMessage,
                    child: const Text('Message'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Header
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
// ============================================================================
class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.name,
    required this.avatar,
    required this.isLite,
    required this.onTap,
    required this.onPhoto,
    required this.onVideo,
    required this.onReel,
  });

  final String name;
  final String avatar;
  final bool isLite;
  final VoidCallback onTap;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;
  final VoidCallback onReel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ColoredBox(
      color: t.background,
      child: Column(
        children: [
          Divider(height: 1, thickness: 1, color: t.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                        border: Border.all(color: t.border),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Row(
              children: [
                _ComposerAction(
                  icon: LucideIcons.image,
                  label: 'Photo',
                  color: const Color(0xFF22C55E),
                  onTap: onPhoto,
                ),
                _ComposerAction(
                  icon: LucideIcons.video,
                  label: 'Video',
                  color: const Color(0xFFEF4444),
                  onTap: onVideo,
                ),
                _ComposerAction(
                  icon: LucideIcons.film,
                  label: 'Reel',
                  color: t.accent,
                  onTap: onReel,
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: t.border),
        ],
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
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: t.surfaceAlt),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: url.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
                ),
              )
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: 120,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
                  ),
                ),
              ),
      ),
    );
  }
}

// ============================================================================
//  Stories strip
// ============================================================================
class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip({
    required this.stories,
    required this.viewerId,
    required this.viewerAvatar,
    required this.viewerName,
    required this.onAdd,
    required this.onOpenStory,
  });

  final List<Story> stories;
  final String viewerId;
  final String viewerAvatar;
  final String viewerName;
  final VoidCallback onAdd;
  final ValueChanged<int> onOpenStory;

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
              seen: true,
              onTap: onAdd,
            );
          }
          final story = stories[index - 1];
          return _StoryTile(
            label: story.authorName.isEmpty ? 'Story' : story.authorName,
            avatarUrl: story.authorAvatar,
            fallbackName: story.authorName,
            mediaUrl: story.mediaUrl,
            seen: viewerId.isNotEmpty && story.viewers.contains(viewerId),
            isDark: t.isDark,
            onTap: () => onOpenStory(index - 1),
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
    this.seen = false,
    this.isDark = false,
  });

  final String label;
  final String avatarUrl;
  final String fallbackName;
  final String mediaUrl;
  final VoidCallback onTap;
  final bool isAdd;
  final bool seen;
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
              if (mediaUrl.isEmpty)
                const DecoratedBox(
                  decoration: BoxDecoration(
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

              Positioned(
                top: 8,
                left: 8,
                child: _StoryAvatar(
                  url: avatarUrl,
                  name: fallbackName,
                  isAdd: isAdd,
                  seen: seen,
                ),
              ),

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
    required this.seen,
  });

  final String url;
  final String name;
  final bool isAdd;
  final bool seen;

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
              color: (!isAdd && !seen) ? const Color(0xFF0EA5E9) : Colors.white,
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 6),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE0F2FE),
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipOval(
                child: url.isEmpty
                    ? Center(
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      )
                    : Image.network(
                        url,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        cacheWidth: 100,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ),
              ),
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
//  Loading skeleton & empty state
// ============================================================================
class _FeedLoadingSkeleton extends StatelessWidget {
  const _FeedLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 12,
                            decoration: BoxDecoration(
                              color: t.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 72,
                            height: 10,
                            decoration: BoxDecoration(
                              color: t.surfaceAlt,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.postMedia),
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

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
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
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const LucideIcon(LucideIcons.refreshCw, size: 15),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
