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
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import '../../data/services/firebase_service.dart';
import '../../data/services/reels_service.dart';
import '../../data/services/upload_service.dart';
import '../../shared/icons/lucide_icons.dart';
import 'demo_reels.dart';
import 'models/reel_comment.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/reel_card.dart';
import 'widgets/reel_preloader.dart';
import 'widgets/reel_video.dart';
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

  /// The progress of the active reel.
  ///
  /// It lives in a [ValueNotifier] and not in the state of the page: the
  /// video reports its position on every frame, and a `setState` for each of
  /// them would rebuild the whole feed thirty times a second — which is
  /// exactly what makes a reels page stutter on a weak phone.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  bool _muted = true;
  String _tab = 'forYou';

  /// The reel on screen is stopped.
  ///
  /// The controls of the reel - the timeline and the sound button - only
  /// show while it is stopped, so a running reel is nothing but the
  /// picture.
  bool _paused = false;

  /// The playback handle of the feed: the speed of the 2x hold and the
  /// position the timeline drags to.
  final ReelPlayback _playback = ReelPlayback();

  /// The feed is held still — a sheet is open over it, or the app went to
  /// the background. The video keeps its position and the sound stops.
  bool _suspended = false;

  final Set<String> _liked = <String>{};
  final Set<String> _saved = <String>{};
  final Set<String> _reposted = <String>{};
  final Set<String> _following = <String>{};
  final Set<String> _seen = <String>{};

  /// The comments of each reel, kept locally so the sheet is instant.
  final Map<String, List<ReelComment>> _comments = <String, List<ReelComment>>{};

  Timer? _dwellTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);

    _seen.addAll(ref.read(prefsProvider).seenReels);
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _progress.dispose();
    _playback.dispose();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _dwellTimer?.cancel();
      // The sound must not follow the app into the background.
      if (mounted) setState(() => _suspended = true);
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _suspended = false);
    }
  }

  List<AppPost> _currentReels = const [];

  void _onPageChanged(int index, List<AppPost> reels) {
    _dwellTimer?.cancel();
    setState(() {
      _activeIndex = index;
      // A new reel starts running.
      _paused = false;
    });
    _progress.value = 0;

    // The 2x hold belongs to the reel that was on screen.
    _playback.setSpeed(1);

    if (index >= reels.length) return;
    final reel = reels[index];

    // Warm the connections to the videos that are about to be shown, so the
    // swipe lands on an already warm path. How many are warmed follows the
    // device: a weak phone warms one, a strong one warms three.
    final device = ref.read(deviceProfileProvider);
    final upcoming = <String?>[];
    for (var i = index + 1; i <= index + 3 && i < reels.length; i++) {
      final next = reels[i];
      final nextDemo = demoReelFor(next.id);
      upcoming.add(nextDemo == null ? _videoUrlOf(next) : null);
    }
    ReelPreloader.warmAll(upcoming, count: device.videoPreloadCount);

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

    // The first feed that arrives is kept, so the next visit to the reels
    // starts with the real reels instead of the local ones.
    ref.listen(reelsProvider, (previous, next) {
      if (!next.hasValue) return;
      final items = next.value;
      if (items == null || items.isEmpty) return;
      if (ref.read(reelsCacheProvider).isEmpty) {
        ref.read(reelsCacheProvider.notifier).state = items;
      }
    });

    // The reels of the last visit — they are on screen while the network is
    // still answering.
    final cached = ref.watch(reelsCacheProvider);
    final fallback = cached.isEmpty ? demoReelsAsPosts() : cached;

    return asyncReels.when(
      // The feed opens with the reels of the last visit, so the page is
      // never an empty screen while the network is still answering.
      loading: () => _buildFeed(context, fallback),
      error: (_, __) => _buildFeed(context, fallback),
      data: (items) {
        final base = items.isEmpty ? fallback : items;
        return _buildFeed(context, [...base, ..._extraReels]);
      },
    );
  }

  Widget _buildFeed(BuildContext context, List<AppPost> reels) {
    _currentReels = reels;
    final device = ref.watch(deviceProfileProvider);
    final window = device.reelWindow;

    // The song of the reel on screen — the reel only stores the id, the
    // name and the artist live in the `songs` collection.
    final activePost = _activeIndex < reels.length ? reels[_activeIndex] : null;
    final songId = activePost?.songId;
    final songAsync = songId == null ? null : ref.watch(songProvider(songId));
    final song = songAsync != null && songAsync.hasValue ? songAsync.value : null;

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
                  isSuspended: _suspended,
                  song: index == _activeIndex ? song : null,
                  playback: _playback,
                  onProgress: (value) {
                    // Only the timeline listens to this — the feed itself is
                    // never rebuilt for it.
                    if (index != _activeIndex || !mounted) return;
                    _progress.value = value;
                  },
                  onPauseChanged: (paused) {
                    if (index != _activeIndex || !mounted) return;
                    setState(() => _paused = paused);
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

          // --- the timeline -------------------------------------------
          // It sits right on top of the floating navigation bar, and it
          // moves on its own: the feed is never rebuilt while a video plays.
          //
          // It only shows while the reel is stopped, and it can be dragged:
          // the reel follows the finger.
          if (_paused)
            Positioned(
              left: 18,
              right: 18,
              bottom:
                  AppSizes.bottomNavTop(MediaQuery.paddingOf(context).bottom) +
                  4,
              child: _Timeline(
                value: _progress,
                onSeek: (fraction) => _playback.seek(fraction),
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
    _suspend();
    final user = ref.read(authControllerProvider).user;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          // The comments of the reel come live from Firestore. Until they
          // answer, the local ones keep the sheet from being empty.
          final asyncComments = ref.watch(commentsProvider(post.id));
          final comments = _commentsOf(post, asyncComments);

          return ReelCommentsSheet(
            comments: comments,
            replierName: post.authorName,
            avatarUrl: user?.avatar ?? '',
            userName: user?.name ?? 'You',
            onSubmit: (text, replyTo) async {
              await _addComment(post, text, replyTo);
            },
            onVoice: (path, durationMs, replyTo) async {
              await _addVoiceComment(post, path, durationMs, replyTo);
            },
            onPhoto: (file, replyTo) async {
              await _addPhotoComment(post, file, replyTo);
            },
            onToggleLike: (comment) {
              _toggleCommentLike(post, comment);
            },
            onDelete: (comment) {
              _deleteComment(post, comment);
            },
          );
        },
      ),
    ).whenComplete(_resume);
  }

  /// The comments that are shown in the sheet.
  ///
  /// The local ones are the answer while the network is still thinking and
  /// when the app is offline; the live ones take over as soon as they are
  /// there.
  List<ReelComment> _commentsOf(
    AppPost post,
    AsyncValue<List<ReelComment>> asyncComments,
  ) {
    final local = _comments.putIfAbsent(post.id, () => demoComments(post.id));
    if (!FirebaseService.isReady) return local;
    if (asyncComments.isLoading) return local;
    final live = asyncComments.value;
    if (live == null || live.isEmpty) return local;
    return live;
  }

  /// Writes a comment — or a reply — and shows it at once.
  Future<void> _addComment(AppPost post, String text, ReelComment? replyTo) async {
    await _writeComment(
      post,
      text: text,
      replyTo: replyTo,
      kind: CommentKind.text,
    );
  }

  /// Sends a voice note and shows it at once.
  Future<void> _addVoiceComment(
    AppPost post,
    String path,
    int durationMs,
    ReelComment? replyTo,
  ) async {
    String? url;
    try {
      final uploaded = await UploadService.uploadFile(
        file: File(path),
        folder: 'voice',
        contentType: 'audio/mp4',
      );
      url = uploaded.url;
    } catch (_) {
      url = null;
    }

    await _writeComment(
      post,
      text: 'Voice note',
      replyTo: replyTo,
      kind: CommentKind.voice,
      mediaUrl: url,
      audioDuration: durationMs,
    );
  }

  /// Attaches a picture and shows it at once.
  Future<void> _addPhotoComment(
    AppPost post,
    File file,
    ReelComment? replyTo,
  ) async {
    String? url;
    try {
      final uploaded = await UploadService.uploadFile(
        file: file,
        folder: 'comments',
        contentType: 'image/jpeg',
      );
      url = uploaded.url;
    } catch (_) {
      url = null;
    }

    await _writeComment(
      post,
      text: 'Photo',
      replyTo: replyTo,
      kind: CommentKind.photo,
      mediaUrl: url,
    );
  }

  /// Writes a comment of any kind and shows it at once.
  Future<void> _writeComment(
    AppPost post, {
    required String text,
    required ReelComment? replyTo,
    required CommentKind kind,
    String? mediaUrl,
    int? audioDuration,
  }) async {
    final user = ref.read(authControllerProvider).user;

    final written = await CommentService.add(
      postId: post.id,
      text: text,
      authorId: user?.uid ?? 'me',
      authorName: user?.name ?? 'You',
      authorAvatar: user?.avatar ?? '',
      parentId: replyTo?.id,
      kind: kind.name,
      mediaUrl: mediaUrl,
      audioDuration: audioDuration,
    );

    // The live list follows the write on its own. Only when the write did
    // not reach the server the comment is shown here.
    if (written) return;

    final comment = ReelComment(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      authorId: user?.uid ?? 'me',
      authorName: user?.name ?? 'You',
      authorAvatar: user?.avatar ?? '',
      kind: kind,
      text: text,
      createdAt: DateTime.now(),
      mediaUrl: mediaUrl,
      audioDuration: audioDuration,
      likesCount: 0,
      isOwn: true,
      replyToId: replyTo?.id,
      replyToName: replyTo?.authorName,
    );

    if (!mounted) return;
    setState(() {
      final current = _comments[post.id] ?? const <ReelComment>[];
      if (replyTo != null) {
        _comments[post.id] = [
          for (final existing in current)
            if (existing.id == replyTo.id)
              existing.copyWith(replies: [...existing.replies, comment])
            else
              existing,
        ];
      } else {
        _comments[post.id] = [comment, ...current];
      }
    });
  }

  /// The like on a comment.
  Future<void> _toggleCommentLike(AppPost post, ReelComment comment) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final liked = await CommentService.toggleLike(
      postId: post.id,
      commentId: comment.id,
      userId: user.uid,
      currentlyLiked: comment.isLiked,
    );
    if (liked == null) return;

    if (!mounted) return;
    setState(() {
      final current = _comments[post.id] ?? const <ReelComment>[];
      _comments[post.id] = [
        for (final existing in current)
          if (existing.id == comment.id)
            existing.copyWith(
              isLiked: liked,
              likesCount: existing.likesCount + (liked ? 1 : -1),
            )
          else
            existing,
      ];
    });
  }

  /// Removes a comment.
  Future<void> _deleteComment(AppPost post, ReelComment comment) async {
    final removed = await CommentService.delete(
      postId: post.id,
      commentId: comment.id,
    );
    if (!removed) return;

    if (!mounted) return;
    setState(() {
      final current = _comments[post.id] ?? const <ReelComment>[];
      _comments[post.id] = [
        for (final existing in current)
          if (existing.id != comment.id) existing,
      ];
    });
  }

  /// Holds the feed still while a sheet is open over it.
  void _suspend() {
    if (mounted) setState(() => _suspended = true);
  }

  /// Gives the feed back to the user.
  void _resume() {
    if (mounted) setState(() => _suspended = false);
  }

  void _openShare(AppPost post) {
    // The people are the conversations the user already has, the way the
    // web app builds its share sheet.
    final user = ref.read(authControllerProvider).user;
    final conversations = ref.read(conversationsProvider).value ?? const <Conversation>[];

    final targets = <ShareTarget>[];
    for (final conversation in conversations) {
      final otherId = conversation.participantIds.firstWhere(
        (id) => id != user?.uid,
        orElse: () => '',
      );
      final name = conversation.groupName ??
          conversation.participantNames[otherId] ??
          'Someone';
      final avatar = conversation.groupAvatar ??
          conversation.participantAvatars[otherId] ??
          '';
      targets.add(
        ShareTarget(id: conversation.id, name: name, avatarUrl: avatar),
      );
    }

    // Without a network the sheet still shows somebody to send to.
    if (targets.isEmpty) {
      targets.addAll(_demoTargets);
    }

    _suspend();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => ReelShareSheet(
        targets: targets,
        isOwner: user?.uid != null && user!.uid == post.authorId,
        onSend: (selected) async {
          await _sendReel(post, selected, user?.uid ?? '');
        },
        onRepost: () {},
        onSave: () {},
        onCopyLink: () async {
          await Clipboard.setData(
            ClipboardData(text: 'https://ennvo.app/reel/${post.id}'),
          );
        },
        onAddStory: () {},
        onDownload: () {},
      ),
    ).whenComplete(_resume);
  }

  /// Sends the reel to the people that were picked.
  Future<void> _sendReel(
    AppPost post,
    List<ShareTarget> selected,
    String senderId,
  ) async {
    final media = post.media.isNotEmpty ? post.media.first : null;
    for (final target in selected) {
      await ChatService.sendMessage(
        conversationId: target.id,
        messageId: 'local-${DateTime.now().microsecondsSinceEpoch}',
        senderId: senderId,
        type: MessageType.reel,
        content: 'Shared a reel',
        mediaUrl: media,
        postId: post.id,
      );
    }
  }

  /// The people of the share sheet when there is no network.
  static const List<ShareTarget> _demoTargets = [
    ShareTarget(id: '1', name: 'Arif Hasan', isOnline: true),
    ShareTarget(id: '2', name: 'Tania Akter'),
    ShareTarget(id: '3', name: 'Rafi Ahmed', isOnline: true),
    ShareTarget(id: '4', name: 'Mim', isOnline: true),
    ShareTarget(id: '5', name: 'Sakib'),
    ShareTarget(id: '6', name: 'Nabila'),
    ShareTarget(id: '7', name: 'Tuhin'),
    ShareTarget(id: '8', name: 'Ritu'),
  ];
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
//  The timeline of the active reel
//
//  It shows how far the reel has played, and it can be dragged: the reel
//  follows the finger. The drag is handled by the page, so the feed is
//  never rebuilt while the video plays.
// ============================================================================
class _Timeline extends StatelessWidget {
  const _Timeline({required this.value, required this.onSeek});

  /// The progress of the active video.
  final ValueListenable<double> value;

  /// The reel was dragged to a new position.
  final ValueChanged<double> onSeek;

  /// The height of the line.
  static const double _thickness = 2;

  /// The height of the touch area. It is taller than the line, so the
  /// timeline is easy to grab on a phone.
  static const double _touch = 16;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          void seekTo(double dx) {
            if (width <= 0) return;
            onSeek((dx / width).clamp(0.0, 1.0));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seekTo(details.localPosition.dx),
            onHorizontalDragStart: (details) =>
                seekTo(details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                seekTo(details.localPosition.dx),
            child: SizedBox(
              height: _touch,
              child: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: value,
                  builder: (context, progress, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: _thickness,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

