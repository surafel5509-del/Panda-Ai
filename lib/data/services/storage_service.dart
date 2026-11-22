import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_config.dart';

/// Persists app settings and the API token.
///
/// The API token is stored ONLY in the platform secure store
/// (iOS Keychain / Android Keystore) via [FlutterSecureStorage] — never in
/// plain preferences, never in source code, never in logs.
class StorageService {
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // -------------------------------------------------------------------------
  // API token (secure storage)
  // -------------------------------------------------------------------------

  Future<String?> readToken() async {
    try {
      final String? token = await _secure.read(key: ApiConfig.tokenStorageKey);
      final String trimmed = (token ?? '').trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    await _secure.write(key: ApiConfig.tokenStorageKey, value: token.trim());
  }

  Future<void> deleteToken() async {
    try {
      await _secure.delete(key: ApiConfig.tokenStorageKey);
    } catch (_) {
      // Best effort — nothing else to do.
    }
  }

  // -------------------------------------------------------------------------
  // Plain preferences (non-secret settings)
  // -------------------------------------------------------------------------

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<String> readBaseUrl() async {
    final SharedPreferences prefs = await _prefs();
    final String url = prefs.getString(ApiConfig.prefsBaseUrl) ?? '';
    return url.trim().isEmpty ? ApiConfig.defaultBaseUrl : url.trim();
  }

  Future<void> saveBaseUrl(String url) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(ApiConfig.prefsBaseUrl, url.trim());
  }

  Future<ThemeMode> readThemeMode() async {
    final SharedPreferences prefs = await _prefs();
    final String value = prefs.getString(ApiConfig.prefsThemeMode) ?? 'system';
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(ApiConfig.prefsThemeMode, mode.name);
  }

  Future<double> readDouble(String key, double fallback) async {
    final SharedPreferences prefs = await _prefs();
    return prefs.getDouble(key) ?? fallback;
  }

  Future<void> saveDouble(String key, double value) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setDouble(key, value);
  }

  Future<String?> readString(String key) async {
    final SharedPreferences prefs = await _prefs();
    return prefs.getString(key);
  }

  Future<void> saveString(String key, String value) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(key, value);
  }

  Future<void> removeString(String key) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.remove(key);
  }

  Future<String> readJsonList(String key) async {
    final SharedPreferences prefs = await _prefs();
    return prefs.getString(key) ?? '[]';
  }

  Future<void> saveJsonList(String key, String json) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(key, json);
  }
}
