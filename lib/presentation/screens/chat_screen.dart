import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common_widgets.dart';

/// AI Chat — premium conversational interface backed by
/// POST /api/v1/chat with session continuation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  int _lastMessageCount = 0;

  static const List<String> _suggestions = <String>[
    'Hello Panda AI, who are you?',
    'Write a short story opening',
    'Give me tips for voice acting',
    'Explain text-to-speech simply',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadRemoteSessions();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final double target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: 300.ms,
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final String text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    await context.read<ChatProvider>().send(text);
    if (mounted) _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final ThemeData theme = Theme.of(context);
    final ChatProvider chat = context.watch<ChatProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();

    if (chat.messages.length != _lastMessageCount) {
      _lastMessageCount = chat.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('AI CHAT'),
            Text(
              chat.sessionId == null
                  ? 'New conversation'
                  : chat.currentTitle,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Conversation history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showHistory(context),
          ),
          IconButton(
            tooltip: 'New conversation',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => chat.newConversation(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (!settings.hasToken)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ErrorBanner(
                message:
                    'Add your Panda API token in Settings → API Token to start chatting.',
                onRetry: null,
              ),
            ),
          Expanded(child: _buildBody(context, chat)),
          _buildComposer(context, chat, p),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChatProvider chat) {
    if (chat.messages.isEmpty && !chat.isSending) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: <Widget>[
          const PandaMark(size: 64),
          const SizedBox(height: 20),
          Text('Hello, I am Panda AI.',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Ask me anything — I can help you write, brainstorm, learn and explore ideas. Your conversations are saved on this device.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String suggestion in _suggestions)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () {
                    _inputController.text = suggestion;
                    _send();
                  },
                ),
            ],
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: chat.messages.length + (chat.isSending ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= chat.messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: TypingIndicator(),
            ),
          );
        }
        final ChatMessage message = chat.messages[index];
        return _MessageBubble(
          message: message,
          isLast: index == chat.messages.length - 1,
          onRetry: message.isError ? () => chat.retryLast() : null,
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context, ChatProvider chat, AppPalette p) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Message Panda AI…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(18, 14, 8, 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: p.inverseBackground,
                    foregroundColor: p.inverseText,
                    fixedSize: const Size(44, 44),
                  ),
                  icon: chat.isSending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: p.inverseText),
                        )
                      : const Icon(Icons.arrow_upward_rounded, size: 22),
                  onPressed: chat.isSending ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final ChatProvider chat = context.read<ChatProvider>();
    chat.loadRemoteSessions();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scroll) {
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('History',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40)),
                        onPressed: () {
                          chat.newConversation();
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New chat'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<ChatProvider>(
                    builder: (BuildContext context, ChatProvider s, Widget? child) {
                      if (s.sessionsLoading && s.remoteSessions.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (s.remoteSessions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No past conversations',
                          subtitle:
                              'Chats you start will appear here once the server stores them.',
                        );
                      }
                      return ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: s.remoteSessions.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ChatSession session = s.remoteSessions[index];
                          return ListTile(
                            leading: const Icon(Icons.chat_bubble_outline_rounded),
                            title: Text(session.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: session.createdAt == null
                                ? null
                                : Text(Formatters.relativeDate(session.createdAt!)),
                            trailing: IconButton(
                              tooltip: 'Delete conversation',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                final bool confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Delete conversation?',
                                  message:
                                      'This will permanently delete "${session.title}" from the server and this device.',
                                );
                                if (confirmed && context.mounted) {
                                  final bool ok =
                                      await s.deleteConversation(session.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(ok
                                              ? 'Conversation deleted'
                                              : 'Could not delete the conversation')),
                                    );
                                  }
                                }
                              },
                            ),
                            onTap: () {
                              s.openSession(session);
                              Navigator.of(sheetContext).pop();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLast;
  final VoidCallback? onRetry;
  const _MessageBubble({
    required this.message,
    required this.isLast,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? p.inverseBackground : p.surface,
          border: Border.all(color: isUser ? Colors.transparent : p.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(
              message.content,
              style: TextStyle(
                color: isUser ? p.inverseText : p.textPrimary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  Formatters.dateTime(message.createdAt),
                  style: TextStyle(
                    color: (isUser ? p.inverseText : p.textTertiary)
                        .withOpacity(0.7),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => copyToClipboard(context, message.content),
                  child: Icon(
                    Icons.copy_outlined,
                    size: 14,
                    color: (isUser ? p.inverseText : p.textTertiary)
                        .withOpacity(0.8),
                  ),
                ),
                if (message.isError && onRetry != null) ...<Widget>[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onRetry,
                    child: Icon(Icons.refresh_rounded,
                        size: 14, color: p.textPrimary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.08, end: 0, duration: 280.ms);
  }
}
