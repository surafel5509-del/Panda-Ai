import 'package:flutter/material.dart';

import '../../core/constants/api_config.dart';
import '../../core/utils/api_exception.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';

/// App-wide settings: theme, API token (secure storage), base URL and
/// audio/chat defaults. The token is never exposed in full to the UI —
/// only a masked preview.
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiService _api;

  SettingsProvider(this._storage, this._api);

  ThemeMode themeMode = ThemeMode.system;
  String baseUrl = ApiConfig.defaultBaseUrl;
  String? _apiToken;

  double defaultSpeed = ApiConfig.defaultSpeed;
  double defaultVolume = ApiConfig.defaultVolume;
  String? defaultEngine;
  String? defaultVoiceId;
  String? defaultVoiceName;
  String defaultStyle = 'natural';

  /// '' = auto (omit language), otherwise en/ar/es/la.
  String chatLanguage = '';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool get hasToken => _apiToken != null && _apiToken!.isNotEmpty;
  String? get maskedToken {
    final String? t = _apiToken;
    if (t == null || t.isEmpty) return null;
    if (t.length <= 8) return '••••••••';
    return '${t.substring(0, 4)}••••••••${t.substring(t.length - 4)}';
  }

  Future<void> init() async {
    themeMode = await _storage.readThemeMode();
    baseUrl = await _storage.readBaseUrl();
    _apiToken = await _storage.readToken();
    defaultSpeed =
        await _storage.readDouble(ApiConfig.prefsDefaultSpeed, ApiConfig.defaultSpeed);
    defaultVolume =
        await _storage.readDouble(ApiConfig.prefsDefaultVolume, ApiConfig.defaultVolume);
    defaultEngine = await _storage.readString(ApiConfig.prefsDefaultEngine);
    defaultVoiceId = await _storage.readString(ApiConfig.prefsDefaultVoiceId);
    defaultVoiceName = await _storage.readString(ApiConfig.prefsDefaultVoiceName);
    defaultStyle =
        await _storage.readString(ApiConfig.prefsDefaultStyle) ?? 'natural';
    chatLanguage =
        await _storage.readString(ApiConfig.prefsChatLanguage) ?? '';
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _storage.saveThemeMode(mode);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    await _storage.saveBaseUrl(baseUrl);
    notifyListeners();
  }

  /// Saves a new API token to secure storage.
  Future<void> saveToken(String token) async {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw const ApiException('Please enter an API token.');
    }
    await _storage.saveToken(trimmed);
    _apiToken = trimmed;
    notifyListeners();
  }

  Future<void> removeToken() async {
    await _storage.deleteToken();
    _apiToken = null;
    notifyListeners();
  }

  /// Validates the stored token against the live account endpoint.
  /// Returns a human-readable result; throws [ApiException] on failure.
  Future<Map<String, dynamic>> testToken() async {
    if (!hasToken) {
      throw const ApiException(
          'No API token saved yet. Add your token first, then test it.');
    }
    return _api.testToken();
  }

  Future<void> setDefaultSpeed(double value) async {
    defaultSpeed = value;
    await _storage.saveDouble(ApiConfig.prefsDefaultSpeed, value);
    notifyListeners();
  }

  Future<void> setDefaultVolume(double value) async {
    defaultVolume = value;
    await _storage.saveDouble(ApiConfig.prefsDefaultVolume, value);
    notifyListeners();
  }

  Future<void> setDefaultEngine(String? engine) async {
    defaultEngine = engine;
    if (engine == null) {
      await _storage.removeString(ApiConfig.prefsDefaultEngine);
    } else {
      await _storage.saveString(ApiConfig.prefsDefaultEngine, engine);
    }
    notifyListeners();
  }

  Future<void> setDefaultVoice(String? voiceId, String? voiceName) async {
    defaultVoiceId = voiceId;
    defaultVoiceName = voiceName;
    if (voiceId == null) {
      await _storage.removeString(ApiConfig.prefsDefaultVoiceId);
      await _storage.removeString(ApiConfig.prefsDefaultVoiceName);
    } else {
      await _storage.saveString(ApiConfig.prefsDefaultVoiceId, voiceId);
      await _storage.saveString(ApiConfig.prefsDefaultVoiceName, voiceName ?? '');
    }
    notifyListeners();
  }

  Future<void> setDefaultStyle(String style) async {
    defaultStyle = style;
    await _storage.saveString(ApiConfig.prefsDefaultStyle, style);
    notifyListeners();
  }

  Future<void> setChatLanguage(String language) async {
    chatLanguage = language;
    await _storage.saveString(ApiConfig.prefsChatLanguage, language);
    notifyListeners();
  }
}
