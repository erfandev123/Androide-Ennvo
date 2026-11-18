// ============================================================================
//  ENNVO — MESSAGES SCREEN
//
//  The chat, ported from `src/pages/Messages.tsx`.
//
//  Two panes:
//    • the conversation list — a stories row on top, then the conversations
//    • the active conversation — the header, the messages, the read receipt
//      slot and the composer
//
//  On a wide screen the two sit side by side with a draggable divider; on a
//  phone the list and the chat are two separate screens.
//
//  The chat view stays **light** even in dark mode, exactly like the web
//  app's `.chat-view-container`.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/message.dart';
import '../../data/models/user.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/story_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../notifications/notifications_page.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_composer.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  /// The conversation that is open in the wide layout.
  ///
  /// On a phone the conversation opens as its own page instead.
  String? _activeConversationId;

  double _sidebarWidth = 440;
  bool _draggingDivider = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final signedInUid = ref.watch(authControllerProvider).user?.uid ?? '';
    final uid = signedInUid.isEmpty ? 'me' : signedInUid;
    final conversations = ref.watch(conversationsProvider).value ?? const <Conversation>[];
    final stories = ref.watch(storiesProvider).value ?? const <Story>[];
    final following = ref.watch(followingProvider).value ?? const <AppUser>[];
    final followers = ref.watch(followersProvider).value ?? const <AppUser>[];
    final notifications = ref.watch(notificationsProvider).value ?? const [];
    final unreadActivity = notifications.where((item) => !item.isRead).length;

    // The friends of the inbox are the people who follow the user and the
    // people the user follows, plus the people already in a conversation.
    final friends = _friendsOf(conversations, following, followers, uid);

    final isWide = _isWide(context);

    // The navigation bar sits over the bottom of the page, so the content
    // keeps that much room — the chat composer included. The classic bar is
    // flush, the glass pill floats, so the room comes from the skin in use.
    final navClearance = AppSizes.navClearanceFor(
      ref.watch(navStyleProvider),
      MediaQuery.paddingOf(context).bottom,
    );

    final ambientGlow = Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 300,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (t.isDark
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF38BDF8))
                    .withValues(alpha: t.isDark ? 0.2 : 0.14),
                (t.isDark
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF3B82F6))
                    .withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );

    final list = _ConversationList(
      conversations: conversations,
      currentUserId: uid,
      stories: stories,
      friends: friends,
      unreadActivity: unreadActivity,
      onActivity: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsPage(modal: true),
          ),
        );
      },
      onOpen: (id) => _openConversation(id, _nameOf(conversations, id)),
      onOpenFriend: _openFriend,
      onCreateStory: () =>
          ref.read(navControllerProvider).pushPage(AppPage.create),
    );

    final chat = _activeConversationId == null
        ? null
        : _ChatPane(
            conversationId: _activeConversationId!,
            title: _nameOf(conversations, _activeConversationId!),
            onBack: () => setState(() => _activeConversationId = null),
          );

    return Scaffold(
      backgroundColor: t.isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          ambientGlow,
          // --- the phone layout: the conversation list -----------------
          if (!isWide)
            Padding(
              padding: EdgeInsets.only(bottom: navClearance),
              child: list,
            )
          // --- the wide layout: the list and the chat side by side ------
          else
            Padding(
              padding: EdgeInsets.only(bottom: navClearance),
              child: Row(
                children: [
                  SizedBox(width: _sidebarWidth, child: list),
                  if (chat != null) ...[
                    _Divider(
                      dragging: _draggingDivider,
                      onDrag: (delta) {
                        setState(() {
                          _sidebarWidth = (_sidebarWidth + delta).clamp(
                            320.0,
                            620.0,
                          );
                        });
                      },
                      onStart: () => setState(() => _draggingDivider = true),
                      onEnd: () => setState(() => _draggingDivider = false),
                    ),
                    Expanded(child: chat),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 768;

  /// The people the user can talk to: everyone who follows them, everyone
  /// they follow, and the people in their existing conversations.
  static List<AppUser> _friendsOf(
    List<Conversation> conversations,
    List<AppUser> following,
    List<AppUser> followers,
    String uid,
  ) {
    final friends = <String, AppUser>{};
    for (final person in [...following, ...followers]) {
      if (person.uid.isNotEmpty && person.uid != uid) {
        friends.putIfAbsent(person.uid, () => person);
      }
    }
    for (final conversation in conversations) {
      if (conversation.groupName?.isNotEmpty == true) continue;
      for (final id in conversation.participantIds) {
        if (id.isEmpty || id == uid || friends.containsKey(id)) continue;
        friends[id] = AppUser(
          uid: id,
          name: conversation.participantNames[id] ?? 'Friend',
          username: '',
          email: '',
          avatar: conversation.participantAvatars[id] ?? '',
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
        );
      }
    }
    final list = friends.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// The name of the person in a conversation.
  static String _nameOf(List<Conversation> conversations, String id) {
    for (final conversation in conversations) {
      if (conversation.id == id) {
        final name = conversation.displayName('me');
        return name.isEmpty ? 'Chat' : name;
      }
    }
    return 'Chat';
  }

  /// Opens a conversation. On a phone it covers the app, the way the web app
  /// hides the navigation while a chat is open.
  void _openConversation(String id, String title) {
    if (_isWide(context)) {
      setState(() => _activeConversationId = id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatRoute(conversationId: id, title: title),
      ),
    );
  }

  /// Starts a chat with a friend, making the direct conversation if needed.
  Future<void> _openFriend(AppUser friend) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final id = await ChatService.createConversation(
      currentUserId: user.uid,
      otherUserId: friend.uid,
      otherUserName: friend.name,
      otherUserAvatar: friend.avatar,
    );
    if (!mounted) return;
    _openConversation(id, friend.name.isEmpty ? 'Chat' : friend.name);
  }
}

// ============================================================================
//  The chat page — its own route, pushed over the conversation list
//
//  The route covers the whole app, so the navigation bar is not on top of
//  the conversation: the chat is a page of its own, exactly like it is on
//  the web.
//
//  The messages come live from Firestore. The message that is written is
//  shown at once and it carries the id of the document, so the copy that
//  comes back from the server replaces it instead of standing next to it.
// ============================================================================
class _ChatRoute extends StatelessWidget {
  const _ChatRoute({required this.conversationId, required this.title});

  final String conversationId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.chatBackground,
      body: _ChatPane(conversationId: conversationId, title: title),
    );
  }
}

// The live presence and typing of the person on the other side.
final _presenceProvider = StreamProvider.family<bool, String>((ref, userId) {
  return ChatService.subscribePresence(userId);
});

final _typingProvider = StreamProvider.family<bool, ({String conversationId, String otherUserId})>((
  ref,
  args,
) {
  return ChatService.subscribeTyping(
    conversationId: args.conversationId,
    otherUserId: args.otherUserId,
  );
});

// ============================================================================
//  The chat pane
//
//  It owns its messages: the live ones from Firestore, plus the ones that
//  were written here and have not come back from the server yet. The copy
//  that comes back replaces the optimistic one, because both carry the same
//  id.
// ============================================================================
class _ChatPane extends ConsumerStatefulWidget {
  const _ChatPane({
    required this.conversationId,
    this.title = 'Chat',
    this.onBack,
  });

  final String conversationId;
  final String title;
  final VoidCallback? onBack;

  @override
  ConsumerState<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<_ChatPane> {
  final List<AppMessage> _pending = <AppMessage>[];
  AppMessage? _replyTo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final signedInUid = ref.watch(authControllerProvider).user?.uid ?? '';
    final uid = signedInUid.isEmpty ? 'me' : signedInUid;

    final conversations = ref.watch(conversationsProvider).value ?? const <Conversation>[];
    Conversation? conversation;
    for (final item in conversations) {
      if (item.id == widget.conversationId) {
        conversation = item;
        break;
      }
    }

    String otherId = '';
    if (conversation != null) {
      for (final id in conversation.participantIds) {
        if (id != uid) {
          otherId = id;
          break;
        }
      }
    }

    final name = conversation == null
        ? widget.title
        : (conversation.participantNames[otherId] ?? widget.title);
    final avatar = conversation == null
        ? ''
        : (conversation.participantAvatars[otherId] ?? '');

    final online = otherId.isEmpty
        ? false
        : ref.watch(_presenceProvider(otherId)).value ?? false;
    final typing = otherId.isEmpty
        ? false
        : ref
                .watch(
                  _typingProvider((
                    conversationId: widget.conversationId,
                    otherUserId: otherId,
                  )),
                )
                .value ??
            false;

    final asyncMessages = ref.watch(messagesProvider(widget.conversationId));
    final live = asyncMessages.value ?? const <AppMessage>[];

    final known = live.map((message) => message.id).toSet();
    final messages = [
      ...live,
      for (final message in _pending)
        if (!known.contains(message.id)) message,
    ];

    return Container(
      color: t.chatBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- the header --------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Back',
                    child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final back = widget.onBack;
                      if (back != null) {
                        back();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: LucideIcon(
                        LucideIcons.arrowLeft,
                        size: 20,
                        strokeWidth: 2.4,
                        color: t.isDark
                            ? const Color(0xFFF5F5F5)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  ),
                  _PersonAvatar(name: name, url: avatar, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name.isEmpty ? 'Chat' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.bodySemi.copyWith(
                            color: t.isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 1),
                        if (typing)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const LucideIcon(
                                LucideIcons.mic,
                                size: 11,
                                strokeWidth: 2,
                                color: Color(0xFFA855F7),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'typing...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: EnnvoText.tiny.copyWith(
                                    color: const Color(0xFFA855F7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            online ? 'Active now' : 'Offline',
                            style: EnnvoText.tiny.copyWith(
                              color: online
                                  ? const Color(0xFF22C55E)
                                  : t.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _HeaderIcon(icon: LucideIcons.phone, semantic: 'Audio call'),
                  _HeaderIcon(icon: LucideIcons.video, semantic: 'Video call'),
                  _HeaderIcon(
                    icon: LucideIcons.moreVertical,
                    semantic: 'Details',
                  ),
                ],
              ),
            ),

            // --- the messages ------------------------------------------
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        'Say hello 👋',
                        style: EnnvoText.body.copyWith(color: t.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        final previous = index + 1 < messages.length
                            ? messages[messages.length - 2 - index]
                            : null;
                        final next = index > 0
                            ? messages[messages.length - index]
                            : null;

                        final isMine = message.senderId == uid;
                        final reply = message.replyTo;
                        final replyPreview = reply == null
                            ? null
                            : AppMessage(
                                id: reply.id,
                                senderId: reply.authorName,
                                type: MessageType.text,
                                content: reply.text,
                                createdAt: null,
                              );
                        final sameAsPrevious = previous != null &&
                            previous.senderId == message.senderId &&
                            _withinAMinute(previous, message);
                        final sameAsNext = next != null &&
                            next.senderId == message.senderId &&
                            _withinAMinute(message, next);

                        return ChatBubble(
                          message: message,
                          isMine: isMine,
                          isFirstInGroup: !sameAsPrevious,
                          isLastInGroup: !sameAsNext,
                          replyPreview: replyPreview,
                          onReply: () => setState(() => _replyTo = message),
                        );
                      },
                    ),
            ),

            // --- the composer ------------------------------------------
            ChatComposer(
              replyTo: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  static bool _withinAMinute(AppMessage a, AppMessage b) {
    final ta = a.createdAt;
    final tb = b.createdAt;
    if (ta == null || tb == null) return false;
    return ta.difference(tb).inSeconds.abs() < 60;
  }

  /// Writes a message and shows it right away.
  Future<void> _send(String text, AppMessage? replyTo) async {
    final user = ref.read(authControllerProvider).user;
    final uid = user?.uid ?? 'me';
    final id = 'client-$uid-${DateTime.now().microsecondsSinceEpoch}';

    final message = AppMessage(
      id: id,
      senderId: uid,
      type: MessageType.text,
      content: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      replyTo: replyTo == null
          ? null
          : ReplyPreview(
              id: replyTo.id,
              text: replyTo.content,
              authorName: replyTo.senderId,
            ),
    );

    setState(() {
      _pending.add(message);
      _replyTo = null;
    });

    await ChatService.sendMessage(
      conversationId: widget.conversationId,
      messageId: id,
      senderId: uid,
      type: MessageType.text,
      content: text,
      replyTo: message.replyTo,
    );

    if (!mounted) return;
    setState(() {
      _pending.removeWhere((pending) => pending.id == id);
    });
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.semantic});

  final String icon;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: semantic,
      child: SizedBox(
        width: 38,
        height: 40,
        child: LucideIcon(
          icon,
          size: 20,
          strokeWidth: 2.1,
          color: t.isDark ? const Color(0xFFE5E5E5) : const Color(0xFF374151),
        ),
      ),
    );
  }
}

class _ConversationList extends StatefulWidget {
  const _ConversationList({
    required this.conversations,
    required this.currentUserId,
    required this.stories,
    required this.friends,
    required this.unreadActivity,
    required this.onActivity,
    required this.onOpen,
    required this.onOpenFriend,
    required this.onCreateStory,
  });

  final List<Conversation> conversations;
  final String currentUserId;
  final List<Story> stories;
  final List<AppUser> friends;
  final int unreadActivity;
  final VoidCallback onActivity;
  final ValueChanged<String> onOpen;
  final ValueChanged<AppUser> onOpenFriend;
  final VoidCallback onCreateStory;

  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The friends that match what the user typed.
  List<AppUser> get _matchedFriends {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return const <AppUser>[];
    return widget.friends
        .where(
          (friend) =>
              friend.name.toLowerCase().contains(term) ||
              friend.username.toLowerCase().contains(term),
        )
        .toList(growable: false);
  }

  /// The conversations that match what the user typed.
  List<Conversation> get _matchedConversations {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return widget.conversations;
    return widget.conversations.where((conversation) {
      final name = _otherName(conversation).toLowerCase();
      return name.contains(term) ||
          conversation.lastMessage.toLowerCase().contains(term);
    }).toList(growable: false);
  }

  static String _otherName(Conversation conversation) {
    final values = conversation.participantNames.values;
    if (values.isEmpty) return conversation.groupName ?? '';
    return values.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: t.isDark ? const Color(0x1AFFFFFF) : const Color(0x80E5E7EB),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- the header -------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  _CircleButton(
                    icon: _searching ? LucideIcons.arrowLeft : LucideIcons.users,
                    semanticLabel: _searching ? 'Close search' : 'Find friends',
                    onTap: () {
                      setState(() {
                        _searching = !_searching;
                        if (!_searching) _search.clear();
                      });
                    },
                  ),
                  if (_searching)
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.border),
                        ),
                        child: Row(
                          children: [
                            LucideIcon(
                              LucideIcons.search,
                              size: 17,
                              strokeWidth: 2.2,
                              color: t.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _search,
                                autofocus: true,
                                onChanged: (_) => setState(() {}),
                                style: EnnvoText.body.copyWith(
                                  color: t.textPrimary,
                                  fontSize: 14,
                                ),
                                cursorColor: t.accent,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Search friends',
                                  hintStyle: EnnvoText.body.copyWith(
                                    color: t.textTertiary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'Chats',
                          style: EnnvoText.titleLg.copyWith(
                            color: t.isDark ? Colors.white : const Color(0xFF0A0A0A),
                            fontSize: 20,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const LucideIcon(
                          LucideIcons.chevronDown,
                          size: 16,
                          strokeWidth: 2.4,
                          color: Color(0xFF737373),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0EA5E9),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _CircleButton(
                      icon: LucideIcons.search,
                      semanticLabel: 'Search',
                      onTap: () => setState(() => _searching = true),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // --- the Activity option, a friend row ----------------
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onActivity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF6B8B), Color(0xFFFF2D55)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const LucideIcon(
                              LucideIcons.sparkles,
                              size: 21,
                              strokeWidth: 2.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Activity',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Notifications & alerts',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12.5,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.unreadActivity > 0)
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFE2C55),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                widget.unreadActivity > 9
                                    ? '9+'
                                    : '${widget.unreadActivity}',
                                style: EnnvoText.tiny.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            LucideIcon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: t.textTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),

                  // --- the stories of the people in the inbox ----------
                  if (!_searching)
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _inboxStories().length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _StoryTile(
                              name: 'Create',
                              isCreate: true,
                              onTap: widget.onCreateStory,
                            );
                          }
                          final story = _inboxStories()[index - 1];
                          return _StoryTile(
                            name: story.authorName.isEmpty
                                ? 'Story'
                                : story.authorName,
                            avatarUrl: story.authorAvatar,
                            viewed: story.viewers.contains(widget.currentUserId),
                            onTap: () => _openStory(context, index - 1),
                          );
                        },
                      ),
                    ),

                  // --- the real friends --------------------------------
                  if (_searching)
                    if (_matchedFriends.isNotEmpty) ...[
                      _SectionLabel(label: 'Friends'),
                      for (final friend in _matchedFriends)
                        _FriendRow(
                          friend: friend,
                          onTap: () => widget.onOpenFriend(friend),
                        ),
                    ],

                  // --- the conversations --------------------------------
                  _SectionLabel(
                    label: _searching ? 'Chats' : 'Messages',
                  ),
                  if (_matchedConversations.isEmpty && !_searching)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        children: [
                          LucideIcon(
                            LucideIcons.messageCircle,
                            size: 42,
                            strokeWidth: 1.4,
                            color: t.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No chats yet',
                            style: EnnvoText.bodySemi.copyWith(
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search for a friend above to start one.',
                            textAlign: TextAlign.center,
                            style: EnnvoText.caption.copyWith(
                              color: t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final conversation in _matchedConversations)
                      _ConversationRow(
                        conversation: conversation,
                        currentUserId: widget.currentUserId,
                        onTap: () => widget.onOpen(conversation.id),
                      ),

                  // --- the rest of the friends, when there is no search -
                  if (!_searching && widget.friends.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionLabel(label: 'Friends'),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: widget.friends.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final friend = widget.friends[index];
                          return _FriendTile(
                            friend: friend,
                            onTap: () => widget.onOpenFriend(friend),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One story per author, newest first.
  List<Story> _inboxStories() {
    final seen = <String>{};
    final stories = <Story>[];
    for (final story in widget.stories) {
      if (seen.add(story.authorId.isEmpty ? story.id : story.authorId)) {
        stories.add(story);
      }
    }
    return stories;
  }

  void _openStory(BuildContext context, int index) {
    final stories = _inboxStories();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StoryViewerRoute(
          stories: stories,
          initialIndex: index,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: EnnvoText.overlineXs.copyWith(
          color: t.textTertiary,
          fontSize: 10.5,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onTap});

  final AppUser friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            _PersonAvatar(
              name: friend.name,
              url: friend.avatar,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name.isEmpty ? 'Friend' : friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnnvoText.bodySemi.copyWith(
                      color: t.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.username.isEmpty ? 'Tap to chat' : '@${friend.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnnvoText.caption.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                LucideIcons.messageCircle,
                size: 16,
                strokeWidth: 2.1,
                color: t.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});

  final AppUser friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            _PersonAvatar(name: friend.name, url: friend.avatar, size: 56),
            const SizedBox(height: 6),
            Text(
              friend.name.isEmpty ? 'Friend' : friend.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: EnnvoText.tiny.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE0F2FE),
        image: url.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
      ),
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: EnnvoText.bodySemi.copyWith(
                fontSize: size * 0.36,
                color: const Color(0xFF0369A1),
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

// A full screen story viewer, the same gesture the web app uses in the inbox.
class _StoryViewerRoute extends StatefulWidget {
  const _StoryViewerRoute({
    required this.stories,
    required this.initialIndex,
    required this.currentUserId,
  });

  final List<Story> stories;
  final int initialIndex;
  final String currentUserId;

  @override
  State<_StoryViewerRoute> createState() => _StoryViewerRouteState();
}

class _StoryViewerRouteState extends State<_StoryViewerRoute> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _schedule();
    _markSeen();
  }

  void _markSeen() {
    final story = widget.stories[_index];
    if (!story.viewers.contains(widget.currentUserId)) {
      StoryService.markSeen(storyId: story.id, userId: widget.currentUserId);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 6), _next);
  }

  void _next() {
    if (_index + 1 < widget.stories.length) {
      _controller.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _previous() {
    if (_index > 0) {
      _controller.animateToPage(
        _index - 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _markSeen();
              _schedule();
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final width = MediaQuery.sizeOf(context).width;
                  if (details.globalPosition.dx < width * 0.32) {
                    _previous();
                  } else {
                    _next();
                  }
                },
                child: Center(
                  child: story.mediaUrl.isEmpty
                      ? const SizedBox.shrink()
                      : Image.network(
                          story.mediaUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 8,
            right: 8,
            child: Row(
              children: [
                for (var i = 0; i < widget.stories.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 26,
            left: 12,
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: _PersonAvatar(
                    name: widget.stories[_index].authorName,
                    url: widget.stories[_index].authorAvatar,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.stories[_index].authorName,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 24,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  One conversation row
// ============================================================================
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = conversation.displayName(currentUserId);
    final unread = conversation.unreadFor(currentUserId);
    final isUnread = unread > 0;

    String otherId = '';
    for (final id in conversation.participantIds) {
      if (id != currentUserId) {
        otherId = id;
        break;
      }
    }
    final avatar = conversation.participantAvatars[otherId] ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                _PersonAvatar(name: name, url: avatar, size: 48),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.isDark ? const Color(0xFF16181F) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnnvoText.bodySemi.copyWith(
                      color: t.isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: isUnread ? 15 : 14.5,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.lastMessage.isEmpty
                        ? 'Sent a message'
                        : conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnnvoText.caption.copyWith(
                      color: isUnread
                          ? (t.isDark ? Colors.white : const Color(0xFF111827))
                          : const Color(0xFFA3A3A3),
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeTime(conversation.updatedAt),
                  style: EnnvoText.tiny.copyWith(
                    color: t.isDark ? const Color(0xFF737373) : const Color(0xFFA3A3A3),
                    fontSize: 11.5,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE2C55),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 5 ? '5+' : '$unread',
                      style: EnnvoText.tiny.copyWith(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final delta = DateTime.now().difference(time);
    if (delta.inSeconds < 45) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 30) return '${delta.inDays}d ago';
    return '${delta.inDays ~/ 30}mo ago';
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.name,
    required this.onTap,
    this.avatarUrl = '',
    this.viewed = false,
    this.isCreate = false,
  });

  final String name;
  final String avatarUrl;
  final bool viewed;
  final bool isCreate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isCreate
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFFEC4899),
                                  Color(0xFFF59E0B),
                                ],
                              )
                            : (viewed
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF38BDF8),
                                      Color(0xFF3B82F6),
                                      Color(0xFF4F46E5),
                                    ],
                                  )),
                        color: viewed && !isCreate ? t.surfaceAlt : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.isDark ? const Color(0xFF0A0A0A) : Colors.white,
                          image: (avatarUrl.isNotEmpty && !isCreate)
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl),
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: (avatarUrl.isNotEmpty && !isCreate)
                            ? null
                            : Text(
                                name.isEmpty
                                    ? '?'
                                    : name.characters.first.toUpperCase(),
                                style: EnnvoText.titleMd.copyWith(
                                  color: t.textSecondary,
                                ),
                              ),
                      ),
                    ),
                    if (isCreate)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const LucideIcon(
                            LucideIcons.plus,
                            size: 14,
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EnnvoText.tiny.copyWith(
                  color: t.isDark ? const Color(0xFFE5E5E5) : const Color(0xFF1F2937),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The draggable divider
// ============================================================================
class _Divider extends StatelessWidget {
  const _Divider({
    required this.dragging,
    required this.onDrag,
    required this.onStart,
    required this.onEnd,
  });

  final bool dragging;
  final ValueChanged<double> onDrag;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onStart(),
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      onHorizontalDragEnd: (_) => onEnd(),
      child: Container(
        width: 9,
        alignment: Alignment.center,
        color: dragging ? const Color(0x330EA5E9) : null,
        child: Container(
          width: 2,
          height: double.infinity,
          color: dragging
              ? const Color(0xFF0EA5E9)
              : (t.isDark ? const Color(0x26FFFFFF) : const Color(0xCCE5E7EB)),
        ),
      ),
    );
  }
}

// ============================================================================
//  A round icon button
// ============================================================================
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final String icon;
  final VoidCallback onTap;
  final String semanticLabel;

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
            color: t.isDark
                ? const Color(0x1AFFFFFF)
                : const Color(0xB3FFFFFF),
            border: Border.all(
              color: t.isDark ? const Color(0x1AFFFFFF) : const Color(0x0D000000),
            ),
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            icon,
            size: 18,
            strokeWidth: 2.1,
            color: t.isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }
}
