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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/message.dart';
import '../../data/services/chat_service.dart';
import '../../shared/icons/lucide_icons.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_composer.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  /// The message the user is replying to.
  AppMessage? _replyTo;

  /// The conversation that is open in the wide layout.
  ///
  /// On a phone the conversation opens as its own page instead.
  String? _activeConversationId;

  double _sidebarWidth = 440;
  bool _draggingDivider = false;

  /// The local message list, so the demo works without a backend.
  final Map<String, List<AppMessage>> _messages = <String, List<AppMessage>>{};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final loaded = ref.watch(conversationsProvider).value;
    final conversations = (loaded == null || loaded.isEmpty)
        ? _demoConversations()
        : loaded;
    final isWide = _isWide(context);

    // The floating navigation bar sits over the bottom of the page, so the
    // content keeps that much room — the chat composer included.
    final navClearance = AppSizes.bottomNavClearance(
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
      onOpen: (id) {
        // On a phone the conversation opens as its own page: it covers the
        // app, so the navigation bar does not sit on top of the chat — the
        // way the web app hides it while a chat is open.
        if (_isWide(context)) {
          setState(() => _activeConversationId = id);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ChatRoute(
              conversationId: id,
              title: _nameOf(conversations, id),
            ),
          ),
        );
      },
    );

    final chat = _activeConversationId == null
        ? null
        : _ChatPane(
            conversationId: _activeConversationId!,
            title: _nameOf(conversations, _activeConversationId!),
            messages: _messages[_activeConversationId!] ?? const [],
            replyTo: _replyTo,
            onBack: () => setState(() => _activeConversationId = null),
            onReply: (message) => setState(() => _replyTo = message),
            onCancelReply: () => setState(() => _replyTo = null),
            onSend: (text, replyTo) async {
              final message = AppMessage(
                id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                senderId: 'me',
                type: MessageType.text,
                content: text,
                createdAt: DateTime.now(),
                status: MessageStatus.sent,
                replyTo: replyTo == null
                    ? null
                    : ReplyPreview(
                        id: replyTo.id,
                        text: replyTo.content,
                        authorName: 'them',
                      ),
              );
              setState(() {
                _messages[_activeConversationId!] = [
                  ...?_messages[_activeConversationId!],
                  message,
                ];
              });
            },
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

  List<Conversation> _demoConversations() => [
    Conversation(
      id: 'demo-1',
      participantIds: const ['me', 'demo-a'],
      participantNames: const {'demo-a': 'Arif Hasan'},
      participantAvatars: const {'demo-a': ''},
      lastMessage: 'ওয়াও, আলোটা কী সুন্দর!',
      unreadCount: const {'me': 2},
      updatedAt: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
    Conversation(
      id: 'demo-2',
      participantIds: const ['me', 'demo-b'],
      participantNames: const {'demo-b': 'Tania Akter'},
      participantAvatars: const {'demo-b': ''},
      lastMessage: 'Location ta kothay bhai?',
      unreadCount: const {'me': 0},
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Conversation(
      id: 'demo-3',
      participantIds: const ['me', 'demo-c'],
      participantNames: const {'demo-c': 'Rafi Ahmed'},
      participantAvatars: const {'demo-c': ''},
      lastMessage: 'Sent a message',
      unreadCount: const {'me': 0},
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
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
class _ChatRoute extends ConsumerStatefulWidget {
  const _ChatRoute({required this.conversationId, required this.title});

  final String conversationId;
  final String title;

  @override
  ConsumerState<_ChatRoute> createState() => _ChatRouteState();
}

class _ChatRouteState extends ConsumerState<_ChatRoute> {
  /// The messages that were written here and did not come back yet.
  final List<AppMessage> _pending = <AppMessage>[];

  AppMessage? _replyTo;

  @override
  Widget build(BuildContext context) {
    final asyncMessages = ref.watch(
      messagesProvider(widget.conversationId),
    );
    final live = asyncMessages.value ?? const <AppMessage>[];

    // The live list wins, the messages that are still on their way are
    // added on top of it.
    final known = live.map((message) => message.id).toSet();
    final messages = [
      ...live,
      for (final message in _pending)
        if (!known.contains(message.id)) message,
    ];

    return Scaffold(
      backgroundColor: context.tokens.chatBackground,
      body: _ChatPane(
        conversationId: widget.conversationId,
        title: widget.title,
        messages: messages,
        replyTo: _replyTo,
        onBack: () => Navigator.of(context).maybePop(),
        onReply: (message) => setState(() => _replyTo = message),
        onCancelReply: () => setState(() => _replyTo = null),
        onSend: _send,
      ),
    );
  }

  /// Writes a message and shows it right away.
  Future<void> _send(String text, AppMessage? replyTo) async {
    final user = ref.read(authControllerProvider).user;
    final id = 'client-${user?.uid ?? 'me'}-${DateTime.now().microsecondsSinceEpoch}';

    final message = AppMessage(
      id: id,
      senderId: user?.uid ?? 'me',
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
      senderId: user?.uid ?? 'me',
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

// ============================================================================
//  The conversation list
// ============================================================================
class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.conversations, required this.onOpen});

  final List<Conversation> conversations;
  final ValueChanged<String> onOpen;

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
                    icon: LucideIcons.users,
                    onTap: () {},
                    semanticLabel: 'New group',
                  ),
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
                    onTap: () {},
                    semanticLabel: 'Search',
                  ),
                ],
              ),
            ),

            // --- the stories row --------------------------------------
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: const [
                  _StoryTile(name: 'Create', isCreate: true),
                  _StoryTile(name: 'Arif', viewed: false),
                  _StoryTile(name: 'Tania', viewed: false),
                  _StoryTile(name: 'Rafi', viewed: true),
                  _StoryTile(name: 'Mim', viewed: true),
                ],
              ),
            ),

            // --- the conversations ------------------------------------
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return _ConversationRow(
                    conversation: conversation,
                    currentUserId: 'me',
                    onTap: () => onOpen(conversation.id),
                  );
                },
              ),
            ),
          ],
        ),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surfaceAlt,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
                  ),
                ),
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
                          : (t.isDark
                                ? const Color(0xFFA3A3A3)
                                : const Color(0xFFA3A3A3)),
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
    if (delta.inHours < 24) return '${delta.inHours} hour${delta.inHours == 1 ? '' : 's'} ago';
    if (delta.inDays < 30) return '${delta.inDays} day${delta.inDays == 1 ? '' : 's'} ago';
    return '${delta.inDays ~/ 30} month${delta.inDays ~/ 30 == 1 ? '' : 's'} ago';
  }
}

// ============================================================================
//  The story tile
// ============================================================================
class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.name,
    this.viewed = false,
    this.isCreate = false,
  });

  final String name;
  final bool viewed;
  final bool isCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
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
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: EnnvoText.titleMd.copyWith(color: t.textSecondary),
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
    );
  }
}

// ============================================================================
//  The chat pane
// ============================================================================
class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.conversationId,
    required this.messages,
    required this.replyTo,
    required this.onBack,
    required this.onReply,
    required this.onCancelReply,
    required this.onSend,
    this.title = 'Chat',
  });

  final String conversationId;
  final List<AppMessage> messages;
  final AppMessage? replyTo;
  final VoidCallback onBack;
  final ValueChanged<AppMessage> onReply;
  final VoidCallback onCancelReply;
  final Future<void> Function(String text, AppMessage? replyTo) onSend;

  /// The name of the person on the other side.
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

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
                  IconButton(
                    onPressed: onBack,
                    icon: LucideIcon(
                      LucideIcons.arrowLeft,
                      size: 20,
                      strokeWidth: 2.4,
                      color: t.isDark
                          ? const Color(0xFFF5F5F5)
                          : const Color(0xFF1F2937),
                    ),
                    tooltip: 'Back',
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.surfaceAlt,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'A',
                      style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.bodySemi.copyWith(
                            color: t.isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 1),
                        // The row shrinks on a narrow phone, so the label
                        // gives way before the header overflows.
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LucideIcon(
                              LucideIcons.mic,
                              size: 11,
                              strokeWidth: 2,
                              color: Color(0xFFA855F7),
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'typing...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFA855F7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: LucideIcon(
                      LucideIcons.phone,
                      size: 20,
                      strokeWidth: 2.1,
                      color: t.isDark
                          ? const Color(0xFFE5E5E5)
                          : const Color(0xFF374151),
                    ),
                    tooltip: 'Audio call',
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: LucideIcon(
                      LucideIcons.video,
                      size: 21,
                      strokeWidth: 2.1,
                      color: t.isDark
                          ? const Color(0xFFE5E5E5)
                          : const Color(0xFF374151),
                    ),
                    tooltip: 'Video call',
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: LucideIcon(
                      LucideIcons.moreVertical,
                      size: 20,
                      strokeWidth: 2.1,
                      color: t.isDark
                          ? const Color(0xFFE5E5E5)
                          : const Color(0xFF374151),
                    ),
                    tooltip: 'Details',
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

                        final isMine = message.senderId == 'me';
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
                          replyPreview: null,
                          onReply: () => onReply(message),
                        );
                      },
                    ),
            ),

            // --- the read receipt slot ---------------------------------
            const SizedBox(height: 15),

            // --- the composer ------------------------------------------
            ChatComposer(
              replyTo: replyTo,
              onCancelReply: onCancelReply,
              onSend: onSend,
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
