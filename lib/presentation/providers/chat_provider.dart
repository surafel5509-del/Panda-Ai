import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/api_config.dart';
import '../../core/utils/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import 'settings_provider.dart';

/// AI chat state: current conversation, local message persistence,
/// remote session list, send/retry/delete flows.
class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final SettingsProvider Function() _settings;
  final StorageService _storage;

  ChatProvider({
    required ApiService api,
    required SettingsProvider Function() settings,
    required StorageService storage,
  })  : _api = api,
        _settings = settings,
        _storage = storage;

  List<ChatMessage> messages = <ChatMessage>[];
  String? sessionId;
  bool isSending = false;
  String? errorMessage;
  bool errorRetryable = false;

  List<ChatSession> remoteSessions = <ChatSession>[];
  bool sessionsLoading = false;

  bool get hasToken => _settings().hasToken;

  String? get _language {
    final String lang = _settings().chatLanguage;
    return lang.isEmpty ? null : lang;
  }

  String get currentTitle {
    for (final ChatMessage m in messages) {
      if (m.isUser && m.content.trim().isNotEmpty) {
        final String c = m.content.trim();
        return c.length > 42 ? '${c.substring(0, 42)}…' : c;
      }
    }
    return 'New conversation';
  }

  // -------------------------------------------------------------------------
  // Local persistence
  // -------------------------------------------------------------------------

  String _messagesKey(String id) => '${ApiConfig.prefsChatMessagesPrefix}$id';

  Future<void> _persistMessages() async {
    if (sessionId == null) return;
    final String encoded =
        jsonEncode(messages.map((ChatMessage m) => m.toJson()).toList());
    await _storage.saveJsonList(_messagesKey(sessionId!), encoded);
  }

  Future<List<ChatMessage>> _loadMessages(String id) async {
    final String raw = await _storage.readJsonList(_messagesKey(id));
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList();
      }
    } catch (_) {
      // Ignore corrupted cache.
    }
    return <ChatMessage>[];
  }

  Future<void> _deleteLocalMessages(String id) async {
    await _storage.removeString(_messagesKey(id));
  }

  // -------------------------------------------------------------------------
  // Conversation lifecycle
  // -------------------------------------------------------------------------

  void newConversation() {
    sessionId = null;
    messages = <ChatMessage>[];
    errorMessage = null;
    notifyListeners();
  }

  Future<void> openSession(ChatSession session) async {
    sessionId = session.id;
    messages = await _loadMessages(session.id);
    errorMessage = null;
    notifyListeners();
  }

  Future<void> loadRemoteSessions() async {
    sessionsLoading = true;
    notifyListeners();
    try {
      remoteSessions = await _api.getChatSessions(limit: 20);
    } catch (_) {
      // Keep whatever sessions are already loaded; the UI shows them or
      // its empty state.
    }
    sessionsLoading = false;
    notifyListeners();
  }

  Future<bool> deleteConversation(String id) async {
    try {
      await _api.deleteChatSession(id);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
    await _deleteLocalMessages(id);
    remoteSessions.removeWhere((ChatSession s) => s.id == id);
    if (sessionId == id) {
      sessionId = null;
      messages = <ChatMessage>[];
    }
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------------------------
  // Sending
  // -------------------------------------------------------------------------

  Future<void> send(String rawText) async {
    final String content = rawText.trim();
    if (content.isEmpty || isSending) return;
    if (content.length > 6000) {
      errorMessage = 'Message is too long (max 6000 characters).';
      notifyListeners();
      return;
    }
    messages.add(ChatMessage.user(content));
    errorMessage = null;
    isSending = true;
    notifyListeners();
    await _persistMessages();
    await _requestReply(content);
  }

  /// Retries the last user message after a failure.
  Future<void> retryLast() async {
    if (isSending) return;
    String? lastUserText;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isUser) {
        lastUserText = messages[i].content;
        break;
      }
    }
    if (lastUserText == null) return;
    // Drop trailing error bubbles before retrying.
    messages.removeWhere((ChatMessage m) => m.isError);
    errorMessage = null;
    isSending = true;
    notifyListeners();
    await _requestReply(lastUserText);
  }

  Future<void> _requestReply(String content) async {
    try {
      final ChatResult result = await _api.chat(
            message: content,
            sessionId: sessionId,
            language: _language,
          );
      if (result.sessionId != null && result.sessionId!.isNotEmpty) {
        sessionId = result.sessionId;
      }
      final String reply = result.reply.trim().isEmpty
          ? 'I received your message but the assistant returned an empty reply. Please try again.'
          : result.reply;
      messages.add(ChatMessage.assistant(reply));
    } catch (e) {
      errorMessage = e.toString();
      errorRetryable = e is ApiException && e.retryable;
      messages.add(ChatMessage.error(e.toString()));
    }
    isSending = false;
    notifyListeners();
    await _persistMessages();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
