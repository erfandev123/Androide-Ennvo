// ============================================================================
//  ENNVO — MESSAGES SCREEN
//
//  Ported from `src/pages/Messages.tsx`.
//
//  Two states:
//    • the conversation list — stories on top, then the conversations
//    • an active conversation — header, message list, typing indicator,
//      read receipt slot and the input bar
//
//  The chat surface keeps the web app's deliberate choice: the chat view
//  stays **light** even in dark mode.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/message.dart';
import '../../data/services/chat_service.dart';
import '../../shared/icons/lucide_icons.dart';
import 'widgets/chat_bubble.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String? _activeConversationId;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _currentUserId =>
      ref.read(authControllerProvider).user?.uid ?? '';

  void _openConversation(Conversation conversation) {
    setState(() => _activeConversationId = conversation.id);
    ChatService.markRead(
      conversationId: conversation.id,
      userId: _currentUserId,
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final conversationId = _activeConversationId;
    final uid = _currentUserId;
    if (text.isEmpty || conversationId == null || uid.isEmpty) return;

    _input.clear();
    final messageId =
        '${DateTime.now().microsecondsSinceEpoch}_${uid.hashCode.abs()}';

    await ChatService.sendMessage(
      conversationId: conversationId,
      messageId: messageId,
      senderId: uid,
      type: MessageType.text,
      content: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = _activeConversationId;

    return Scaffold(
      // The chat surface stays light in dark mode, like the web app.
      backgroundColor: context.tokens.chatBackground,
      body: conversationId == null
          ? _ConversationList(onOpen: _openConversation)
          : _ConversationView(
              conversationId: conversationId,
              currentUserId: _currentUserId,
              input: _input,
              scroll: _scroll,
              onSend: _send,
              onBack: () => setState(() => _activeConversationId = null),
            ),
    );
  }
}

// ============================================================================
//  The conversation list
// ============================================================================
class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.onOpen});

  final ValueChanged<Conversation> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final conversations = ref.watch(conversationsProvider);
    final top = MediaQuery.paddingOf(context).top;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Text(
                  'Inbox',
                  style: EnnvoText.pageHero.copyWith(color: t.textPrimary),
                ),
                const Spacer(),
                LucideIcon(
                  LucideIcons.search,
                  size: 21,
                  strokeWidth: 2.2,
                  color: t.textPrimary,
                ),
              ],
            ),
          ),
          Expanded(
            child: conversations.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Could not load your inbox',
                  style: EnnvoText.body.copyWith(color: t.textSecondary),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LucideIcon(
                            LucideIcons.messageCircle,
                            size: 48,
                            strokeWidth: 1.6,
                            color: t.textTertiary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No conversations yet',
                            style: EnnvoText.titleMd.copyWith(
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start a chat and it will show up here.',
                            textAlign: TextAlign.center,
                            style: EnnvoText.body.copyWith(
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 78,
                  ),
                  itemBuilder: (context, index) {
                    final conversation = items[index];
                    final uid =
                        ref.watch(authControllerProvider).user?.uid ?? '';
                    final unread = conversation.unreadFor(uid);

                    return ListTile(
                      onTap: () => onOpen(conversation),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: _ConversationAvatar(
                        url: conversation.displayAvatar(uid),
                        name: conversation.displayName(uid),
                      ),
                      title: Text(
                        conversation.displayName(uid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnnvoText.bodySemi.copyWith(
                          color: t.textPrimary,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnnvoText.caption.copyWith(
                          color: t.textSecondary,
                        ),
                      ),
                      trailing: unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: kBrand,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                '$unread',
                                style: EnnvoText.tiny.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The active conversation
// ============================================================================
class _ConversationView extends ConsumerWidget {
  const _ConversationView({
    required this.conversationId,
    required this.currentUserId,
    required this.input,
    required this.scroll,
    required this.onSend,
    required this.onBack,
  });

  final String conversationId;
  final String currentUserId;
  final TextEditingController input;
  final ScrollController scroll;
  final VoidCallback onSend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final messages = ref.watch(messagesProvider(conversationId));

    return Column(
      children: [
        // --- header ----------------------------------------------------
        _ConversationHeader(
          conversationId: conversationId,
          currentUserId: currentUserId,
          onBack: onBack,
        ),

        // --- messages --------------------------------------------------
        Expanded(
          child: messages.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Could not load the messages',
                style: EnnvoText.body.copyWith(color: t.textSecondary),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'Say hello 👋',
                    style: EnnvoText.body.copyWith(color: t.textTertiary),
                  ),
                );
              }

              return ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final message = items[index];
                  final isMine = message.senderId == currentUserId;

                  // The last bubble of a group gets the squared tail.
                  final next = index + 1 < items.length ? items[index + 1] : null;
                  final isLastInGroup =
                      next == null || next.senderId != message.senderId;

                  // The reply preview of the message above.
                  AppMessage? replyTo;
                  if (index > 0) {
                    final previous = items[index - 1];
                    if (previous.id == message.replyTo?.id) {
                      replyTo = previous;
                    }
                  }

                  return RepaintBoundary(
                    child: ChatBubble(
                      message: message,
                      isMine: isMine,
                      isLastInGroup: isLastInGroup,
                      showReply: replyTo,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // --- typing indicator -----------------------------------------
        const TypingIndicator(),

        // --- read receipt ---------------------------------------------
        ReadReceipt(
          status: MessageStatus.seen,
          isMine: true,
        ),

        // --- input bar -------------------------------------------------
        _ChatInputBar(controller: input, onSend: onSend),
      ],
    );
  }
}

class _ConversationHeader extends ConsumerWidget {
  const _ConversationHeader({
    required this.conversationId,
    required this.currentUserId,
    required this.onBack,
  });

  final String conversationId;
  final String currentUserId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];
    final conversation = conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;

    final name = conversation?.displayName(currentUserId) ?? 'Chat';
    final avatar = conversation?.displayAvatar(currentUserId) ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.paddingOf(context).top + 6,
        8,
        8,
      ),
      decoration: BoxDecoration(
        color: t.chatBackground,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: LucideIcon(
              LucideIcons.chevronLeft,
              size: 24,
              strokeWidth: 2.4,
              color: t.textPrimary,
            ),
            tooltip: 'Back',
          ),
          _ConversationAvatar(url: avatar, name: name, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EnnvoText.bodySemi.copyWith(
                color: t.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: LucideIcon(
              LucideIcons.phone,
              size: 20,
              strokeWidth: 2.2,
              color: t.textPrimary,
            ),
            tooltip: 'Audio call',
          ),
          IconButton(
            onPressed: () {},
            icon: LucideIcon(
              LucideIcons.video,
              size: 21,
              strokeWidth: 2.2,
              color: t.textPrimary,
            ),
            tooltip: 'Video call',
          ),
          IconButton(
            onPressed: () {},
            icon: LucideIcon(
              LucideIcons.moreVertical,
              size: 20,
              strokeWidth: 2.2,
              color: t.textPrimary,
            ),
            tooltip: 'Details',
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        6,
        10,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      decoration: BoxDecoration(
        color: t.chatBackground,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () {},
            icon: LucideIcon(
              LucideIcons.image,
              size: 21,
              strokeWidth: 2.2,
              color: t.textSecondary,
            ),
            tooltip: 'Photo',
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.isDark ? const Color(0xFFF2F4F7) : const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                style: EnnvoText.body.copyWith(
                  color: const Color(0xFF111827),
                  fontSize: 14.5,
                ),
                cursorColor: kBrand,
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: EnnvoText.body.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 14.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: kBrand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.url,
    required this.name,
    this.size = 48,
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
      child: url.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
              ),
            )
          : null,
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
