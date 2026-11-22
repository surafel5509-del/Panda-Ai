/// Central API configuration for PANDA AI STUDIO.
///
/// The base URL is a public endpoint address (not a secret). The API key is
/// NEVER hard-coded here — the user enters it in Settings → API Token and it
/// is stored in the device Keychain / Keystore (flutter_secure_storage) and
/// sent as the `X-API-Key` header on every request.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl =
      'https://panda-voice-ai-production.up.railway.app';

  /// Secure-storage key for the user API token.
  static const String tokenStorageKey = 'panda_api_token';

  /// Shared-preferences keys.
  static const String prefsBaseUrl = 'panda_base_url';
  static const String prefsThemeMode = 'panda_theme_mode';
  static const String prefsDefaultSpeed = 'panda_default_speed';
  static const String prefsDefaultVolume = 'panda_default_volume';
  static const String prefsDefaultEngine = 'panda_default_engine';
  static const String prefsDefaultVoiceId = 'panda_default_voice_id';
  static const String prefsDefaultVoiceName = 'panda_default_voice_name';
  static const String prefsDefaultStyle = 'panda_default_style';
  static const String prefsChatLanguage = 'panda_chat_language';
  static const String prefsLibraryItems = 'panda_library_items';
  static const String prefsChatSessions = 'panda_chat_sessions';
  static const String prefsChatMessagesPrefix = 'panda_chat_messages_';

  // ---- Panda Voice AI endpoints (verified against /openapi.json) ----
  static const String voices = '/api/v1/voices';
  static String voiceDetail(String voiceId) => '/api/v1/voices/$voiceId';
  static const String styles = '/api/v1/styles';
  static const String engines = '/api/v1/engines';
  static const String preview = '/api/v1/preview';
  static const String tts = '/api/v1/tts';
  static const String chat = '/api/v1/chat';
  static const String chatCompletions = '/api/v1/chat/completions';
  static const String chatSessions = '/api/v1/chat/sessions';
  static String deleteChatSession(String sessionId) =>
      '/api/v1/chat/sessions/$sessionId';
  static const String account = '/api/v1/account';
  static const String limits = '/api/v1/limits';
  static const String subscription = '/api/v1/subscription';
  static const String plans = '/api/v1/plans';
  static const String health = '/health';

  // ---- TTS constraints (from the live TTSInput schema) ----
  static const int maxTtsChars = 4000;
  static const int minVoiceIdLength = 8;
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const double defaultSpeed = 1.0;
  static const double minVolume = -20.0;
  static const double maxVolume = 20.0;
  static const double defaultVolume = 0.0;

  static const List<String> documentedStyles = <String>[
    'natural',
    'story',
    'podcast',
    'voiceover',
    'audiobook',
    'news',
    'documentary',
    'meditation',
    'energetic',
    'whisper',
    'empathetic',
    'commercial',
  ];

  static const List<String> documentedEngines = <String>[
    's2.1-pro-free',
    's2.1-pro',
    's2-pro',
    's1',
  ];

  static const List<String> chatLanguages = <String>['en', 'ar', 'es', 'la'];

  /// Sample text used for voice previews and the "Sample text" button.
  static const String sampleText =
      'Hello from Panda AI Studio. This is a preview of your selected voice.';
}
