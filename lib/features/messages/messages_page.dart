// ============================================================================
//  ENNVO — MESSAGES SCREEN
//
//  Layout order:
//    1. Stories strip at the top (Create tile + friend stories)
//    2. Activity row right below Stories, styled like a friend list row
//    3. Conversations / Messages list
//    4. Friends quick-start strip
//
//  On a wide screen the list and chat sit side-by-side; on a phone a chat
//  opens as its own full-screen [ChatScreen] without the bottom nav bar.
//  `.chat-view-container` stays light (`#FFFFFF`) even in dark mode.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/message.dart';
import '../../data/models/notification.dart';
import '../../data/models/user.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/story_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../../shared/widgets/story_viewer.dart';
import '../notifications/notifications_page.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_composer.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String? _activeConversationId;
  double _sidebarWidth = 440;
  bool _draggingDivider = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final signedInUid = ref.watch(authControllerProvider).user?.uid ?? '';
    final uid = signedInUid.isEmpty ? 'me' : signedInUid;
    final conversations =
        ref.watch(conversationsProvider).value ?? const <Conversation>[];
    final stories = ref.watch(storiesProvider).value ?? const <Story>[];
    final following = ref.watch(followingProvider).value ?? const <AppUser>[];
    final followers = ref.watch(followersProvider).value ?? const <AppUser>[];
    final notifications =
        ref.watch(notificationsProvider).value ?? const <AppNotification>[];
    final unreadActivity = notifications.where((item) => !item.isRead).length;
    final latestActivity = _latestActivitySummary(notifications);

    final friends = _friendsOf(conversations, following, followers, uid);
    final isWide = _isWide(context);

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
      latestActivityText: latestActivity,
      onActivity: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsPage(modal: true),
          ),
        );
      },
      onOpen: (id) => _openConversation(id, _nameOf(conversations, id, uid)),
      onOpenFriend: _openFriend,
      onCreateStory: () =>
          ref.read(navControllerProvider).pushPage(AppPage.create),
    );

    final chat = _activeConversationId == null
        ? null
        : _ChatPane(
            conversationId: _activeConversationId!,
            title: _nameOf(conversations, _activeConversationId!, uid),
            onBack: () => setState(() => _activeConversationId = null),
          );

    return Scaffold(
      backgroundColor: t.isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          ambientGlow,
          if (!isWide)
            Padding(
              padding: EdgeInsets.only(bottom: navClearance),
              child: list,
            )
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

  static String _latestActivitySummary(List<AppNotification> items) {
    if (items.isEmpty) return 'Notifications & alerts';
    final latest = items.first;
    final actor = latest.senderName.isEmpty ? 'Someone' : latest.senderName;
    final verb = switch (latest.type) {
      NotificationType.like => 'liked your post',
      NotificationType.comment => 'commented on your post',
      NotificationType.follow => 'started following you',
      NotificationType.repost => 'reposted your post',
      NotificationType.mention => 'mentioned you',
      NotificationType.message => 'sent you a message',
    };
    return '$actor $verb';
  }

  static bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 768;

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

  static String _nameOf(
    List<Conversation> conversations,
    String id,
    String currentUid,
  ) {
    for (final conversation in conversations) {
      if (conversation.id == id) {
        final name = conversation.displayName(currentUid);
        return name.isEmpty ? 'Chat' : name;
      }
    }
    return 'Chat';
  }

  void _openConversation(String id, String title) {
    if (_isWide(context)) {
      setState(() => _activeConversationId = id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversationId: id, title: title),
      ),
    );
  }

  Future<void> _openFriend(AppUser friend) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to start a conversation.')),
      );
      return;
    }

    final id = await ChatService.createConversation(
      currentUserId: user.uid,
      otherUserId: friend.uid,
      otherUserName: friend.name,
      otherUserAvatar: friend.avatar,
      currentUserName: user.name,
      currentUserAvatar: user.avatar,
    );
    if (!mounted) return;
    _openConversation(id, friend.name.isEmpty ? 'Chat' : friend.name);
  }
}

/// Public full-screen chat route usable from Feed, Search, Notifications & Inbox.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

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

final _presenceProvider = StreamProvider.family<bool, String>((ref, userId) {
  return ChatService.subscribePresence(userId);
});

final _typingProvider =
    StreamProvider.family<bool, ({String conversationId, String otherUserId})>(
      (ref, args) {
        return ChatService.subscribeTyping(
          conversationId: args.conversationId,
          otherUserId: args.otherUserId,
        );
      },
    );

// ============================================================================
//  The chat pane (`.chat-view-container` — light canvas even in dark mode)
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
  final List<AppMessage> _older = <AppMessage>[];
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  AppMessage? _replyTo;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void didUpdateWidget(covariant _ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _pending.clear();
      _older.clear();
      _hasMoreOlder = true;
      _replyTo = null;
      _markAsRead();
    }
  }

  void _markAsRead() {
    final uid = ref.read(authControllerProvider).user?.uid ?? '';
    if (uid.isEmpty || widget.conversationId.isEmpty) return;
    ChatService.markRead(
      conversationId: widget.conversationId,
      userId: uid,
    );
  }

  Future<void> _loadOlder(List<AppMessage> live) async {
    if (_loadingOlder || !_hasMoreOlder) return;
    final oldest = _older.isNotEmpty
        ? _older.first.createdAt
        : (live.isNotEmpty ? live.first.createdAt : null);
    if (oldest == null) return;

    setState(() => _loadingOlder = true);
    final batch = await ChatService.loadOlderMessages(
      conversationId: widget.conversationId,
      before: oldest,
    );
    if (!mounted) return;
    setState(() {
      _loadingOlder = false;
      if (batch.isEmpty) {
        _hasMoreOlder = false;
      } else {
        _older.insertAll(0, batch);
      }
    });
  }

  Future<void> _sendTyped({
    required MessageType type,
    required String content,
    String? mediaUrl,
    int? voiceDuration,
    String? stickerUrl,
    AppMessage? replyTo,
    String otherId = '',
  }) async {
    final user = ref.read(authControllerProvider).user;
    final uid = user?.uid ?? 'me';
    final id = 'client-$uid-${DateTime.now().microsecondsSinceEpoch}';

    final message = AppMessage(
      id: id,
      senderId: uid,
      type: type,
      content: content,
      createdAt: DateTime.now(),
      mediaUrl: mediaUrl,
      voiceDuration: voiceDuration,
      stickerUrl: stickerUrl,
      status: MessageStatus.sending,
      replyTo: replyTo == null
          ? null
          : ReplyPreview(
              id: replyTo.id,
              text: replyTo.content.isNotEmpty ? replyTo.content : 'Attachment',
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
      type: type,
      content: content,
      recipientId: otherId,
      mediaUrl: mediaUrl,
      voiceDuration: voiceDuration,
      stickerUrl: stickerUrl,
      replyTo: message.replyTo,
    );
  }

  Future<void> _startCall(String kind, String name, String otherId) async {
    final user = ref.read(authControllerProvider).user;
    final uid = user?.uid ?? 'me';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '$kind call',
          style: EnnvoText.titleSm.copyWith(color: const Color(0xFF111827)),
        ),
        content: Text(
          'Calling $name...',
          style: EnnvoText.body.copyWith(color: const Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (user != null) {
                await ChatService.sendMessage(
                  conversationId: widget.conversationId,
                  messageId: 'call-${DateTime.now().microsecondsSinceEpoch}',
                  senderId: uid,
                  type: MessageType.system,
                  content: '$kind call started',
                  recipientId: otherId,
                );
              }
            },
            child: const Text('End call'),
          ),
        ],
      ),
    );
  }

  void _openDetails(String name, String avatar, bool online) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.paddingOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PersonAvatar(name: name, url: avatar, size: 64),
            const SizedBox(height: 12),
            Text(
              name.isEmpty ? 'Chat' : name,
              style: EnnvoText.titleMd.copyWith(color: const Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Text(
              online ? 'Active now' : 'Offline',
              style: EnnvoText.caption.copyWith(
                color: online
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _markAsRead();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: const Text('Mark as read'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMessageActions(AppMessage message, bool isMine) {
    const reactions = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.paddingOf(sheetContext).bottom + 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in reactions)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ChatService.reactToMessage(
                        conversationId: widget.conversationId,
                        messageId: message.id,
                        emoji: message.reaction == emoji ? null : emoji,
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: message.reaction == emoji
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const LucideIcon(
                LucideIcons.reply,
                size: 19,
                color: Color(0xFF111827),
              ),
              title: const Text(
                'Reply',
                style: TextStyle(color: Color(0xFF111827)),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() => _replyTo = message);
              },
            ),
            if (message.content.isNotEmpty)
              ListTile(
                leading: const LucideIcon(
                  LucideIcons.copy,
                  size: 19,
                  color: Color(0xFF111827),
                ),
                title: const Text(
                  'Copy',
                  style: TextStyle(color: Color(0xFF111827)),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Clipboard.setData(ClipboardData(text: message.content));
                },
              ),
            if (isMine)
              ListTile(
                leading: const LucideIcon(
                  LucideIcons.trash2,
                  size: 19,
                  color: Color(0xFFDC2626),
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ChatService.deleteMessage(
                    conversationId: widget.conversationId,
                    messageId: message.id,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final signedInUid = ref.watch(authControllerProvider).user?.uid ?? '';
    final uid = signedInUid.isEmpty ? 'me' : signedInUid;

    final conversations =
        ref.watch(conversationsProvider).value ?? const <Conversation>[];
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
        : (conversation.participantNames[otherId] ??
            conversation.displayName(uid));
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

    final combinedMap = <String, AppMessage>{};
    for (final m in _older) {
      combinedMap[m.id] = m;
    }
    for (final m in live) {
      combinedMap[m.id] = m;
    }
    for (final m in _pending) {
      combinedMap.putIfAbsent(m.id, () => m);
    }
    final messages = combinedMap.values.toList(growable: false);

    return Container(
      color: t.chatBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- light-canvas header (always dark ink on white) ------
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
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
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: LucideIcon(
                            LucideIcons.arrowLeft,
                            size: 20,
                            strokeWidth: 2.4,
                            color: Color(0xFF1F2937),
                          ),
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
                            color: const Color(0xFF111827),
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 1),
                        if (typing)
                          Text(
                            'typing...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnnvoText.tiny.copyWith(
                              color: const Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            online ? 'Active now' : 'Offline',
                            style: EnnvoText.tiny.copyWith(
                              color: online
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _HeaderIcon(
                    icon: LucideIcons.phone,
                    semantic: 'Audio call',
                    onTap: () => _startCall('Audio', name, otherId),
                  ),
                  _HeaderIcon(
                    icon: LucideIcons.video,
                    semantic: 'Video call',
                    onTap: () => _startCall('Video', name, otherId),
                  ),
                  _HeaderIcon(
                    icon: LucideIcons.moreVertical,
                    semantic: 'Details',
                    onTap: () => _openDetails(name, avatar, online),
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
                        style: EnnvoText.body.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: messages.length +
                          (_hasMoreOlder && live.length >= 40 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: TextButton(
                                onPressed: _loadingOlder
                                    ? null
                                    : () => _loadOlder(live),
                                child: Text(
                                  _loadingOlder
                                      ? 'Loading...'
                                      : 'Load older messages',
                                  style: EnnvoText.caption.copyWith(
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

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
                          avatarUrl: avatar,
                          replyPreview: replyPreview,
                          onReply: () => setState(() => _replyTo = message),
                          onLongPress: () =>
                              _openMessageActions(message, isMine),
                        );
                      },
                    ),
            ),

            // --- the composer ------------------------------------------
            ChatComposer(
              replyTo: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              onTyping: (v) {
                if (uid != 'me') {
                  ChatService.setTyping(
                    conversationId: widget.conversationId,
                    userId: uid,
                    isTyping: v,
                  );
                }
              },
              onSend: (text, replyTo) => _sendTyped(
                type: MessageType.text,
                content: text,
                replyTo: replyTo,
                otherId: otherId,
              ),
              onSendMedia: (url, type, replyTo) => _sendTyped(
                type: type,
                content: '',
                mediaUrl: url,
                replyTo: replyTo,
                otherId: otherId,
              ),
              onSendVoice: (url, durationSec, replyTo) => _sendTyped(
                type: MessageType.voice,
                content: 'Voice message',
                mediaUrl: url,
                voiceDuration: durationSec,
                replyTo: replyTo,
                otherId: otherId,
              ),
              onSendSticker: (url, replyTo) => _sendTyped(
                type: MessageType.sticker,
                content: 'Sticker',
                stickerUrl: url,
                replyTo: replyTo,
                otherId: otherId,
              ),
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
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.semantic,
    required this.onTap,
  });

  final String icon;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 40,
          child: LucideIcon(
            icon,
            size: 20,
            strokeWidth: 2.1,
            color: const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  Conversation list
// ============================================================================
class _ConversationList extends StatefulWidget {
  const _ConversationList({
    required this.conversations,
    required this.currentUserId,
    required this.stories,
    required this.friends,
    required this.unreadActivity,
    required this.latestActivityText,
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
  final String latestActivityText;
  final VoidCallback onActivity;
  final ValueChanged<String> onOpen;
  final ValueChanged<AppUser> onOpenFriend;
  final VoidCallback onCreateStory;

  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

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

  List<Conversation> get _matchedConversations {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return widget.conversations;
    return widget.conversations.where((conversation) {
      final name = conversation
          .displayName(widget.currentUserId)
          .toLowerCase();
      return name.contains(term) ||
          conversation.lastMessage.toLowerCase().contains(term);
    }).toList(growable: false);
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
                    semanticLabel:
                        _searching ? 'Close search' : 'Find friends',
                    onTap: () {
                      setState(() {
                        _searching = !_searching;
                        if (!_searching) _search.clear();
                      });
                    },
                  ),
                  if (_searching) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _searchFocus.hasFocus ? t.surface : t.surfaceAlt,
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(
                            color:
                                _searchFocus.hasFocus ? t.accent : t.border,
                            width: _searchFocus.hasFocus ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            LucideIcon(
                              LucideIcons.search,
                              size: 16,
                              strokeWidth: 2.2,
                              color: _searchFocus.hasFocus
                                  ? t.accent
                                  : t.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _search,
                                focusNode: _searchFocus,
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
                                  hintText: 'Search friends & chats...',
                                  hintStyle: EnnvoText.body.copyWith(
                                    color: t.textTertiary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_search.text.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: LucideIcon(
                                    LucideIcons.x,
                                    size: 15,
                                    strokeWidth: 2.3,
                                    color: t.textTertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'Chats',
                          style: EnnvoText.titleLg.copyWith(
                            color: t.isDark
                                ? Colors.white
                                : const Color(0xFF0A0A0A),
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
                  // --- 1. STORIES STRIP FIRST AT THE TOP -----------------
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
                            viewed:
                                story.viewers.contains(widget.currentUserId),
                            onTap: () => _openStory(context, index - 1),
                          );
                        },
                      ),
                    ),

                  // --- 2. ACTIVITY FRIEND-STYLE ROW RIGHT BELOW STORIES --
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onActivity,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Activity',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: EnnvoText.bodySemi.copyWith(
                                    color: t.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.latestActivityText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: EnnvoText.caption.copyWith(
                                    color: widget.unreadActivity > 0
                                        ? t.textPrimary
                                        : t.textSecondary,
                                    fontSize: 13,
                                    fontWeight: widget.unreadActivity > 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.unreadActivity > 0)
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
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

                  // --- matched friends while searching -------------------
                  if (_searching && _matchedFriends.isNotEmpty) ...[
                    const _SectionLabel(label: 'Friends'),
                    for (final friend in _matchedFriends)
                      _FriendRow(
                        friend: friend,
                        onTap: () => widget.onOpenFriend(friend),
                      ),
                  ],

                  // --- 3. CONVERSATIONS / MESSAGES -----------------------
                  _SectionLabel(label: _searching ? 'Chats' : 'Messages'),
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

                  // --- 4. FRIENDS STRIP ----------------------------------
                  if (!_searching && widget.friends.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const _SectionLabel(label: 'Friends'),
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
        builder: (_) => StoryViewerPage(
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
                    friend.username.isEmpty
                        ? 'Tap to chat'
                        : '@${friend.username}',
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
    final t = context.tokens;
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
              style: EnnvoText.tiny.copyWith(
                fontSize: 11.5,
                color: t.textPrimary,
              ),
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
                image: ResizeImage(NetworkImage(url), width: 140),
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
                        color: t.isDark
                            ? const Color(0xFF16181F)
                            : Colors.white,
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
                          ? (t.isDark
                              ? Colors.white
                              : const Color(0xFF111827))
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
                    color: t.isDark
                        ? const Color(0xFF737373)
                        : const Color(0xFFA3A3A3),
                    fontSize: 11.5,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints:
                        const BoxConstraints(minWidth: 22, minHeight: 22),
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
                          color: t.isDark
                              ? const Color(0xFF0A0A0A)
                              : Colors.white,
                          image: (avatarUrl.isNotEmpty && !isCreate)
                              ? DecorationImage(
                                  image: ResizeImage(
                                    NetworkImage(avatarUrl),
                                    width: 140,
                                  ),
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
                  color: t.isDark
                      ? const Color(0xFFE5E5E5)
                      : const Color(0xFF1F2937),
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
              : (t.isDark
                  ? const Color(0x26FFFFFF)
                  : const Color(0xCCE5E7EB)),
        ),
      ),
    );
  }
}

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
              color:
                  t.isDark ? const Color(0x1AFFFFFF) : const Color(0x0D000000),
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
