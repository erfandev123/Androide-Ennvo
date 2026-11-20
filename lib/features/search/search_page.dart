// ============================================================================
//  ENNVO — SEARCH SCREEN
//
//  Ported from `src/pages/SearchPage.tsx`: a squircle search field, category
//  pills, recent searches, trending tags, and live people/posts/reels search.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/post_service.dart';
import '../../data/services/user_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../feed/widgets/post_card.dart';
import '../messages/messages_page.dart' show ChatScreen;

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<String> _categories = [
    'All',
    'People',
    'Posts',
    'Reels',
    'Sounds',
    'Tags',
  ];

  static const List<String> _trending = [
    '#Ennvo',
    '#Reels',
    '#Stories',
    '#Tech',
    '#Music',
    '#Gaming',
    '#Lifestyle',
  ];

  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<String> _recent = <String>[];
  final Set<String> _followingIds = <String>{};

  int _category = 0;
  Timer? _debounce;
  bool _loading = false;
  List<AppUser> _users = const [];
  List<AppPost> _posts = const [];
  String _lastSearched = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String raw) async {
    final term = raw.trim();
    if (term.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _users = const [];
          _posts = const [];
          _lastSearched = '';
        });
      }
      return;
    }

    if (term == _lastSearched && (_users.isNotEmpty || _posts.isNotEmpty)) {
      return;
    }

    setState(() => _loading = true);
    final results = await Future.wait([
      UserService.searchUsers(term),
      PostService.searchPosts(term),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _lastSearched = term;
      _users = results[0] as List<AppUser>;
      _posts = results[1] as List<AppPost>;
    });
  }

  void _commitRecent(String term) {
    final value = term.trim();
    if (value.isEmpty) return;
    setState(() {
      _recent.remove(value);
      _recent.insert(0, value);
      if (_recent.length > 8) _recent.removeRange(8, _recent.length);
    });
    _runSearch(value);
  }

  Future<void> _messageUser(AppUser target) async {
    final me = ref.read(authControllerProvider).user;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to message people.')),
      );
      return;
    }
    final id = await ChatService.createConversation(
      currentUserId: me.uid,
      otherUserId: target.uid,
      otherUserName: target.name,
      otherUserAvatar: target.avatar,
      currentUserName: me.name,
      currentUserAvatar: me.avatar,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: id,
          title: target.name.isEmpty ? 'Chat' : target.name,
        ),
      ),
    );
  }

  Future<void> _toggleFollow(AppUser target) async {
    final me = ref.read(authControllerProvider).user;
    if (me == null) return;
    final followed = _followingIds.contains(target.uid);
    setState(() {
      if (followed) {
        _followingIds.remove(target.uid);
      } else {
        _followingIds.add(target.uid);
      }
    });
    if (followed) {
      await UserService.unfollow(myId: me.uid, otherId: target.uid);
    } else {
      await UserService.follow(me: me, other: target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;
    final hasQuery = _query.text.trim().isNotEmpty;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final existingFollowing =
        ref.watch(followingProvider).value ?? const <AppUser>[];
    final knownFollowing = {
      ...existingFollowing.map((u) => u.uid),
      ..._followingIds,
    };

    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        children: [
          // --- header -------------------------------------------------
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 10, 14, 8),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(navControllerProvider).backPage(),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: LucideIcon(
                        LucideIcons.chevronLeft,
                        size: 24,
                        strokeWidth: 2.4,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _focus.hasFocus ? t.surface : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _focus.hasFocus ? t.accent : t.border,
                        width: _focus.hasFocus ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        LucideIcon(
                          LucideIcons.search,
                          size: 17,
                          strokeWidth: 2.2,
                          color: _focus.hasFocus ? t.accent : t.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            focusNode: _focus,
                            onChanged: _onChanged,
                            onSubmitted: _commitRecent,
                            textInputAction: TextInputAction.search,
                            style: EnnvoText.body.copyWith(
                              color: t.textPrimary,
                              fontSize: 14.5,
                            ),
                            cursorColor: t.accent,
                            decoration: InputDecoration(
                              hintText: 'Search people, posts, sounds...',
                              hintStyle: EnnvoText.body.copyWith(
                                color: t.textTertiary,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (hasQuery)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _query.clear();
                              _runSearch('');
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: LucideIcon(
                                LucideIcons.x,
                                size: 16,
                                strokeWidth: 2.2,
                                color: t.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(prefsProvider).setDarkTheme(!isDark),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      isDark ? LucideIcons.sun : LucideIcons.moon,
                      size: 18,
                      strokeWidth: 2.2,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- category pills ----------------------------------------
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isActive = index == _category;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _category = index),
                  child: AnimatedContainer(
                    duration: EnnvoDurations.dropdown,
                    curve: EnnvoCurves.press,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? t.accent : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _categories[index],
                      style: EnnvoText.label.copyWith(
                        color: isActive ? Colors.white : t.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- results ------------------------------------------------
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
              children: [
                if (!hasQuery) ...[
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'RECENT',
                      style: EnnvoText.overlineXs.copyWith(
                        color: t.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final term in _recent)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          _query.text = term;
                          _runSearch(term);
                        },
                        leading: LucideIcon(
                          LucideIcons.clock,
                          size: 17,
                          strokeWidth: 2.2,
                          color: t.textTertiary,
                        ),
                        title: Text(
                          term,
                          style: EnnvoText.body.copyWith(color: t.textPrimary),
                        ),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _recent.remove(term)),
                          child: LucideIcon(
                            LucideIcons.x,
                            size: 16,
                            strokeWidth: 2.2,
                            color: t.textTertiary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    'TRENDING',
                    style: EnnvoText.overlineXs.copyWith(
                      color: t.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _trending)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _query.text = tag;
                            _commitRecent(tag);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: t.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: EnnvoText.label.copyWith(
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else
                  _SearchResults(
                    query: _query.text.trim(),
                    category: _categories[_category],
                    loading: _loading,
                    users: _users,
                    posts: _posts,
                    knownFollowing: knownFollowing,
                    onFollow: _toggleFollow,
                    onMessage: _messageUser,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Live search results
// ============================================================================
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.category,
    required this.loading,
    required this.users,
    required this.posts,
    required this.knownFollowing,
    required this.onFollow,
    required this.onMessage,
  });

  final String query;
  final String category;
  final bool loading;
  final List<AppUser> users;
  final List<AppPost> posts;
  final Set<String> knownFollowing;
  final ValueChanged<AppUser> onFollow;
  final ValueChanged<AppUser> onMessage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    final showUsers = category == 'All' || category == 'People';
    final filteredPosts = switch (category) {
      'Reels' => posts.where((p) => p.isReel).toList(growable: false),
      'Posts' => posts.where((p) => !p.isReel).toList(growable: false),
      'Sounds' => posts
          .where((p) => (p.songTitle ?? '').isNotEmpty)
          .toList(growable: false),
      'People' => const <AppPost>[],
      _ => posts,
    };

    if ((!showUsers || users.isEmpty) && filteredPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            LucideIcon(
              LucideIcons.search,
              size: 42,
              strokeWidth: 1.6,
              color: t.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different keyword or category.',
              textAlign: TextAlign.center,
              style: EnnvoText.body.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showUsers && users.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'PEOPLE',
              style: EnnvoText.overlineXs.copyWith(
                color: t.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          for (final user in users)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: user.avatar.isEmpty
                        ? Container(
                            width: 42,
                            height: 42,
                            color: t.surfaceAlt,
                            alignment: Alignment.center,
                            child: Text(
                              user.name.isEmpty
                                  ? '?'
                                  : user.name.characters.first.toUpperCase(),
                              style: EnnvoText.bodySemi
                                  .copyWith(color: t.textSecondary),
                            ),
                          )
                        : Image.network(
                            user.avatar,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 42,
                              height: 42,
                              color: t.surfaceAlt,
                              alignment: Alignment.center,
                              child: Text(
                                user.name.isEmpty
                                    ? '?'
                                    : user.name.characters.first.toUpperCase(),
                                style: EnnvoText.bodySemi
                                    .copyWith(color: t.textSecondary),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isEmpty ? 'User' : user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.bodySemi
                              .copyWith(color: t.textPrimary),
                        ),
                        if (user.username.isNotEmpty)
                          Text(
                            '@${user.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnnvoText.caption
                                .copyWith(color: t.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onFollow(user),
                    child: Text(
                      knownFollowing.contains(user.uid)
                          ? 'Following'
                          : 'Follow',
                    ),
                  ),
                  IconButton(
                    onPressed: () => onMessage(user),
                    tooltip: 'Message',
                    icon: LucideIcon(
                      LucideIcons.messageCircle,
                      size: 18,
                      color: t.accent,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (filteredPosts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              category == 'Reels' ? 'REELS' : 'POSTS',
              style: EnnvoText.overlineXs.copyWith(
                color: t.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          for (final post in filteredPosts)
            PostCard(
              post: post,
              isLiked: false,
              isReposted: false,
              likesCount: post.likesCount,
            ),
        ],
      ],
    );
  }
}
