import 'dart:convert';

/// Data models for PANDA AI STUDIO.
///
/// The live API returns loosely-typed JSON (its OpenAPI schemas are
/// untyped `{}`), so every parser here is defensive: it accepts a bare
/// list, or an object wrapping the list under common keys
/// (`voices`, `data`, `items`, `results`, …), and reads fields under
/// their documented names with sensible fallbacks. Nothing is invented —
/// unknown fields are simply ignored.

/// Extracts a list from an API payload that may be a bare list or an
/// object wrapping the list under a known key.
List<dynamic> extractList(dynamic json, [List<String> keys = const <String>[]]) {
  if (json is List) return json;
  if (json is Map<String, dynamic>) {
    final List<String> candidates = <String>[
      ...keys,
      'data',
      'items',
      'results',
      'voices',
      'styles',
      'engines',
      'sessions',
      'chats',
      'list',
    ];
    for (final String key in candidates) {
      final dynamic value = json[key];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        final List<dynamic> nested = extractList(value, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
  }
  return <dynamic>[];
}

/// Reads the first non-null value among [keys] from [map].
dynamic pick(Map<String, dynamic> map, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = map[key];
    if (value != null && !(value is String && value.trim().isEmpty)) {
      return value;
    }
  }
  return null;
}

String _string(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

class Voice {
  final String id;
  final String name;
  final String gender; // 'male' | 'female' | '' (unknown)
  final String description;
  final String style;
  final String language;
  final String? previewUrl;
  final Map<String, dynamic> raw;

  const Voice({
    required this.id,
    required this.name,
    this.gender = '',
    this.description = '',
    this.style = '',
    this.language = '',
    this.previewUrl,
    this.raw = const <String, dynamic>{},
  });

  factory Voice.fromJson(dynamic json) {
    if (json is String) {
      return Voice(id: json, name: json);
    }
    final Map<String, dynamic> map = json is Map<String, dynamic>
        ? json
        : <String, dynamic>{'value': json};
    final String id = _string(pick(map, <String>['voice_id', 'id', 'name']));
    final String name = _string(
      pick(map, <String>['name', 'voice_name', 'title', 'id', 'voice_id']),
      id,
    );
    final String genderRaw =
        _string(pick(map, <String>['gender', 'sex'])).toLowerCase();
    final String gender = genderRaw.contains('female') || genderRaw == 'f'
        ? 'female'
        : genderRaw.contains('male') || genderRaw == 'm'
            ? 'male'
            : genderRaw;
    return Voice(
      id: id,
      name: name,
      gender: gender,
      description: _string(
          pick(map, <String>['description', 'desc', 'about', 'bio'])),
      style: _string(pick(map, <String>['style', 'category'])),
      language: _string(pick(map, <String>['language', 'lang', 'locale'])),
      previewUrl: _string(
          pick(map, <String>['preview_url', 'preview', 'sample_url', 'audio_url'])),
      raw: map,
    );
  }

  bool get isMale => gender == 'male';
  bool get isFemale => gender == 'female';

  @override
  bool operator ==(Object other) => other is Voice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// Voice style
// ---------------------------------------------------------------------------

class VoiceStyle {
  final String id;
  final String name;
  final String description;

  const VoiceStyle({required this.id, required this.name, this.description = ''});

  factory VoiceStyle.fromJson(dynamic json) {
    if (json is String) {
      return VoiceStyle(id: json, name: json);
    }
    if (json is Map<String, dynamic>) {
      final String id = _string(
          pick(json, <String>['id', 'name', 'style', 'key', 'value']));
      return VoiceStyle(
        id: id,
        name: _string(pick(json, <String>['name', 'label', 'title', 'id']), id),
        description: _string(pick(json, <String>['description', 'desc'])),
      );
    }
    return VoiceStyle(id: json.toString(), name: json.toString());
  }
}

// ---------------------------------------------------------------------------
// Engine / model
// ---------------------------------------------------------------------------

class Engine {
  final String id;
  final String name;
  final String description;
  final bool isFree;
  final Map<String, dynamic> raw;

  const Engine({
    required this.id,
    required this.name,
    this.description = '',
    this.isFree = false,
    this.raw = const <String, dynamic>{},
  });

  factory Engine.fromJson(dynamic json) {
    if (json is String) {
      return Engine(id: json, name: json, isFree: json.contains('free'));
    }
    if (json is Map<String, dynamic>) {
      final String id = _string(
          pick(json, <String>['id', 'model', 'name', 'key', 'value']));
      final dynamic freeRaw =
          pick(json, <String>['is_free', 'free', 'tier', 'plan']);
      final bool isFree = freeRaw == true ||
          (freeRaw is String && freeRaw.toLowerCase().contains('free')) ||
          id.contains('free');
      return Engine(
        id: id,
        name: _string(pick(json, <String>['name', 'label', 'title', 'id']), id),
        description: _string(pick(json, <String>['description', 'desc'])),
        isFree: isFree,
        raw: json,
      );
    }
    return Engine(id: json.toString(), name: json.toString());
  }
}

// ---------------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------------

enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
  });

  factory ChatMessage.user(String content) => ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: MessageRole.user,
        content: content,
        createdAt: DateTime.now(),
      );

  factory ChatMessage.assistant(String content) => ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: content,
        createdAt: DateTime.now(),
      );

  factory ChatMessage.error(String content) => ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: content,
        createdAt: DateTime.now(),
        isError: true,
      );

  bool get isUser => role == MessageRole.user;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isError': isError,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: _string(json['id'], DateTime.now().microsecondsSinceEpoch.toString()),
        role: json['role'] == 'user'
            ? MessageRole.user
            : json['role'] == 'system'
                ? MessageRole.system
                : MessageRole.assistant,
        content: _string(json['content']),
        createdAt: DateTime.tryParse(_string(json['createdAt'])) ??
            DateTime.now(),
        isError: json['isError'] == true,
      );

  String toJsonString() => jsonEncode(toJson());

  factory ChatMessage.fromJsonString(String source) =>
      ChatMessage.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Result of a chat request, parsed defensively from the API response.
class ChatResult {
  final String reply;
  final String? sessionId;
  final String? model;
  final Map<String, dynamic> raw;

  const ChatResult({
    required this.reply,
    this.sessionId,
    this.model,
    this.raw = const <String, dynamic>{},
  });

  factory ChatResult.fromJson(dynamic json) {
    if (json is String) return ChatResult(reply: json);
    final Map<String, dynamic> map = json is Map<String, dynamic>
        ? json
        : <String, dynamic>{'reply': json.toString()};

    String reply = _string(pick(map, <String>[
      'reply',
      'response',
      'message',
      'content',
      'text',
      'answer',
    ]));
    // OpenAI-style shape: { choices: [ { message: { content } } ] }
    if (reply.isEmpty && map['choices'] is List) {
      final List<dynamic> choices = map['choices'] as List<dynamic>;
      if (choices.isNotEmpty && choices.first is Map<String, dynamic>) {
        final Map<String, dynamic> first =
            choices.first as Map<String, dynamic>;
        final dynamic message = first['message'];
        if (message is Map<String, dynamic>) {
          reply = _string(message['content']);
        }
        reply = reply.isEmpty ? _string(first['text']) : reply;
      }
    }
    if (reply.isEmpty && map['message'] is Map<String, dynamic>) {
      reply = _string((map['message'] as Map<String, dynamic>)['content']);
    }

    return ChatResult(
      reply: reply,
      sessionId: _string(pick(map, <String>['session_id', 'sessionId', 'id'])).isEmpty
          ? null
          : _string(pick(map, <String>['session_id', 'sessionId', 'id'])),
      model: _string(pick(map, <String>['model', 'model_name'])).isEmpty
          ? null
          : _string(pick(map, <String>['model', 'model_name'])),
      raw: map,
    );
  }
}

/// A chat session as returned by GET /api/v1/chat/sessions.
class ChatSession {
  final String id;
  final String title;
  final DateTime? createdAt;
  final String? preview;
  final Map<String, dynamic> raw;

  const ChatSession({
    required this.id,
    required this.title,
    this.createdAt,
    this.preview,
    this.raw = const <String, dynamic>{},
  });

  factory ChatSession.fromJson(dynamic json) {
    if (json is String) return ChatSession(id: json, title: json);
    final Map<String, dynamic> map = json is Map<String, dynamic>
        ? json
        : <String, dynamic>{'value': json};
    final String id =
        _string(pick(map, <String>['session_id', 'id', 'sessionId']));
    final String title = _string(
      pick(map, <String>['title', 'name', 'preview', 'first_message', 'summary']),
      'Conversation',
    );
    final dynamic createdRaw =
        pick(map, <String>['created_at', 'createdAt', 'updated_at', 'timestamp']);
    return ChatSession(
      id: id,
      title: title.isEmpty ? 'Conversation' : title,
      createdAt: createdRaw is String ? DateTime.tryParse(createdRaw) : null,
      preview: _string(pick(map, <String>['preview', 'last_message'])).isEmpty
          ? null
          : _string(pick(map, <String>['preview', 'last_message'])),
      raw: map,
    );
  }
}

// ---------------------------------------------------------------------------
// Audio library item (generated speech saved on device)
// ---------------------------------------------------------------------------

class LibraryItem {
  final String id;
  final String title;
  final String text;
  final String voiceId;
  final String voiceName;
  final String style;
  final String model;
  final double speed;
  final double volume;
  final String filePath;
  final int? durationMs;
  final DateTime createdAt;

  const LibraryItem({
    required this.id,
    required this.title,
    required this.text,
    required this.voiceId,
    required this.voiceName,
    required this.style,
    required this.model,
    required this.speed,
    required this.volume,
    required this.filePath,
    this.durationMs,
    required this.createdAt,
  });

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'text': text,
        'voiceId': voiceId,
        'voiceName': voiceName,
        'style': style,
        'model': model,
        'speed': speed,
        'volume': volume,
        'filePath': filePath,
        'durationMs': durationMs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
        id: _string(json['id']),
        title: _string(json['title'], 'Untitled'),
        text: _string(json['text']),
        voiceId: _string(json['voiceId']),
        voiceName: _string(json['voiceName']),
        style: _string(json['style']),
        model: _string(json['model']),
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
        filePath: _string(json['filePath']),
        durationMs: (json['durationMs'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(_string(json['createdAt'])) ??
            DateTime.now(),
      );
}
