import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import '../../core/utils/api_exception.dart';
import '../models/models.dart';

/// HTTP client for the Panda Voice AI API.
///
/// Every request carries the user-provided token as `X-API-Key` (read from
/// secure storage at call time, never hard-coded). MP3 endpoints are handled
/// as binary — never parsed as JSON — and success is only reported when the
/// response actually contains valid audio bytes.
class ApiService {
  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Future<String> Function() _baseUrlProvider;

  ApiService({
    http.Client? client,
    required Future<String?> Function() tokenProvider,
    required Future<String> Function() baseUrlProvider,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider,
        _baseUrlProvider = baseUrlProvider;

  Future<Map<String, String>> _headers({bool json = true}) async {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
    };
    if (json) headers['Content-Type'] = 'application/json';
    final String? token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      headers['X-API-Key'] = token;
    }
    return headers;
  }

  Future<Uri> _uri(String path, [Map<String, String>? query]) async {
    final String base = (await _baseUrlProvider()).trim();
    final Uri baseUri = Uri.parse(
        base.endsWith('/') ? base.substring(0, base.length - 1) : base);
    return baseUri.resolve(path).replace(
          queryParameters: query,
        );
  }

  String _serverDetail(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is List) {
          return detail
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> e) => e['msg']?.toString() ?? '')
              .where((String s) => s.isNotEmpty)
              .join('; ');
        }
        final dynamic message = decoded['message'] ?? decoded['error'];
        if (message is String) return message;
      }
    } catch (_) {
      // Not JSON — fall through.
    }
    return body.length > 300 ? body.substring(0, 300) : body;
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException.fromStatus(
        response.statusCode, _serverDetail(response.body));
  }

  Future<dynamic> _getJson(String path,
      {Map<String, String>? query, bool retryOnce = true}) async {
    http.Response response;
    try {
      response = await _client
          .get(await _uri(path, query), headers: await _headers())
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException(
          'The request timed out. Please check your connection and retry.');
    }
    if (retryOnce &&
        (response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return _getJson(path, query: query, retryOnce: false);
    }
    _throwIfError(response);
    final String body = response.body.trim();
    if (body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ApiException(
          'The server returned an unexpected response. Please retry.',
          statusCode: response.statusCode);
    }
  }

  Future<dynamic> _postJson(String path, Map<String, dynamic> body) async {
    http.Response response;
    try {
      response = await _client
          .post(
            await _uri(path),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException(
          'The request timed out. Please check your connection and retry.');
    }
    _throwIfError(response);
    final String text = response.body.trim();
    if (text.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ApiException(
          'The server returned an unexpected response. Please retry.',
          statusCode: response.statusCode);
    }
  }

  /// POST that must return MP3 binary data. Validates the payload before
  /// returning so callers never treat an error body as audio.
  Future<Uint8List> _postAudio(String path, Map<String, dynamic> body) async {
    http.Response response;
    try {
      response = await _client
          .post(
            await _uri(path),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException(
          'Audio generation timed out. Please retry with shorter text.');
    }
    _throwIfError(response);

    final Uint8List bytes = response.bodyBytes;
    final String contentType =
        response.headers['content-type']?.toLowerCase() ?? '';
    final bool looksJson = contentType.contains('json') ||
        (bytes.length >= 2 &&
            ((bytes[0] == 0x7B && bytes[1] == 0x22) || // {"
                (bytes[0] == 0x5B && bytes[1] != 0x00))); // [
    if (looksJson || bytes.isEmpty) {
      throw InvalidAudioException(
        looksJson
            ? 'The server returned an error instead of audio: '
                '${_serverDetail(response.body)}'
            : 'The server returned empty audio. Please retry.',
      );
    }
    // MP3 frames start with 0xFF 0xFB / 0xFF 0xF3 / 0xFF 0xF2, or an
    // ID3 tag ("ID3"). Accept those; reject anything else.
    final bool isId3 = bytes.length >= 3 &&
        bytes[0] == 0x49 && // I
        bytes[1] == 0x44 && // D
        bytes[2] == 0x33; // 3
    final bool isFrameSync = bytes.length >= 2 && bytes[0] == 0xFF;
    if (!isId3 && !isFrameSync) {
      throw const InvalidAudioException();
    }
    return bytes;
  }

  // -------------------------------------------------------------------------
  // Voices
  // -------------------------------------------------------------------------

  Future<List<Voice>> getVoices({
    String gender = 'all',
    String? style,
    int page = 1,
    int pageSize = 50,
  }) async {
    final Map<String, String> query = <String, String>{
      'gender': gender,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (style != null && style.isNotEmpty) query['style'] = style;
    final dynamic json = await _getJson(ApiConfig.voices, query: query);
    return extractList(json, <String>['voices'])
        .map(Voice.fromJson)
        .where((Voice v) => v.id.isNotEmpty)
        .toList();
  }

  Future<Voice> getVoiceDetail(String voiceId) async {
    final dynamic json =
        await _getJson(ApiConfig.voiceDetail(voiceId));
    if (json is Map<String, dynamic>) {
      final dynamic nested = json['voice'] ?? json['data'];
      if (nested is Map<String, dynamic>) return Voice.fromJson(nested);
    }
    return Voice.fromJson(json);
  }

  // -------------------------------------------------------------------------
  // Styles & engines
  // -------------------------------------------------------------------------

  Future<List<VoiceStyle>> getStyles() async {
    final dynamic json = await _getJson(ApiConfig.styles);
    final List<dynamic> list = extractList(json, <String>['styles']);
    if (list.isEmpty) {
      // Fall back to the documented style list only when the API returns
      // nothing usable — never invent styles the API does not know.
      return ApiConfig.documentedStyles
          .map((String s) => VoiceStyle(id: s, name: s))
          .toList();
    }
    return list.map(VoiceStyle.fromJson).where((VoiceStyle s) => s.id.isNotEmpty).toList();
  }

  Future<List<Engine>> getEngines() async {
    final dynamic json = await _getJson(ApiConfig.engines);
    final List<dynamic> list = extractList(json, <String>['engines', 'models']);
    if (list.isEmpty) {
      return ApiConfig.documentedEngines
          .map((String e) => Engine(id: e, name: e, isFree: e.contains('free')))
          .toList();
    }
    return list.map(Engine.fromJson).where((Engine e) => e.id.isNotEmpty).toList();
  }

  // -------------------------------------------------------------------------
  // Speech (MP3 binary)
  // -------------------------------------------------------------------------

  Map<String, dynamic> _ttsBody({
    required String text,
    required String voiceId,
    required String style,
    String? model,
    required double speed,
    required double volume,
  }) {
    return <String, dynamic>{
      'text': text,
      'voice_id': voiceId,
      'style': style,
      if (model != null && model.isNotEmpty) 'model': model,
      'speed': speed.clamp(ApiConfig.minSpeed, ApiConfig.maxSpeed),
      'volume': volume.clamp(ApiConfig.minVolume, ApiConfig.maxVolume),
    };
  }

  /// Voice preview — returns MP3 bytes. Not counted as a generation.
  Future<Uint8List> preview({
    required String text,
    required String voiceId,
    required String style,
    String? model,
    required double speed,
    required double volume,
  }) {
    return _postAudio(
      ApiConfig.preview,
      _ttsBody(
          text: text,
          voiceId: voiceId,
          style: style,
          model: model,
          speed: speed,
          volume: volume),
    );
  }

  /// Full speech generation — returns MP3 bytes.
  Future<Uint8List> generateSpeech({
    required String text,
    required String voiceId,
    required String style,
    String? model,
    required double speed,
    required double volume,
  }) {
    return _postAudio(
      ApiConfig.tts,
      _ttsBody(
          text: text,
          voiceId: voiceId,
          style: style,
          model: model,
          speed: speed,
          volume: volume),
    );
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  Future<ChatResult> chat({
    required String message,
    String? sessionId,
    String? language,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'message': message,
      'session_id': sessionId,
    };
    if (language != null && language.isNotEmpty) body['language'] = language;
    final dynamic json = await _postJson(ApiConfig.chat, body);
    return ChatResult.fromJson(json);
  }

  /// Alternative completions endpoint — exactly one new user message.
  Future<ChatResult> chatCompletions({
    required String message,
    String? sessionId,
    String? language,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'messages': <Map<String, String>>[
        <String, String>{'role': 'user', 'content': message},
      ],
      'session_id': sessionId,
    };
    if (language != null && language.isNotEmpty) body['language'] = language;
    final dynamic json = await _postJson(ApiConfig.chatCompletions, body);
    return ChatResult.fromJson(json);
  }

  Future<List<ChatSession>> getChatSessions({int limit = 20}) async {
    final dynamic json = await _getJson(ApiConfig.chatSessions,
        query: <String, String>{'limit': limit.toString()});
    return extractList(json, <String>['sessions'])
        .map(ChatSession.fromJson)
        .where((ChatSession s) => s.id.isNotEmpty)
        .toList();
  }

  Future<void> deleteChatSession(String sessionId) async {
    http.Response response;
    try {
      response = await _client
          .delete(
            await _uri(ApiConfig.deleteChatSession(sessionId)),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const NetworkException();
    }
    _throwIfError(response);
  }

  // -------------------------------------------------------------------------
  // Account / usage
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> getAccount() async {
    final dynamic json = await _getJson(ApiConfig.account);
    return json is Map<String, dynamic> ? json : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getLimits() async {
    final dynamic json = await _getJson(ApiConfig.limits);
    return json is Map<String, dynamic> ? json : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSubscription() async {
    final dynamic json = await _getJson(ApiConfig.subscription);
    return json is Map<String, dynamic> ? json : <String, dynamic>{};
  }

  Future<bool> healthCheck() async {
    try {
      await _getJson(ApiConfig.health);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies the stored token against the account endpoint.
  Future<Map<String, dynamic>> testToken() => getAccount();
}
