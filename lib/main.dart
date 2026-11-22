import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app.dart';
import 'data/services/api_service.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/library_service.dart';
import 'data/services/storage_service.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/library_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/voice_studio_provider.dart';

/// PANDA AI STUDIO — entry point.
///
/// The API token is read from secure storage at runtime (Settings → API
/// Token). It is never hard-coded in the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final StorageService storage = StorageService();
  final AudioPlayerService audioPlayer = AudioPlayerService();
  final LibraryService libraryService = LibraryService(storage);

  /// A single shared API client. It reads the token and base URL from
  /// storage at request time, so it always uses the latest credentials
  /// saved in Settings — without leaking HTTP connections.
  final ApiService api = ApiService(
    tokenProvider: storage.readToken,
    baseUrlProvider: storage.readBaseUrl,
  );

  // Settings must load first so the UI reflects persisted preferences.
  final SettingsProvider settings = SettingsProvider(storage, api);
  await settings.init();

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<StorageService>.value(value: storage),
        Provider<AudioPlayerService>.value(value: audioPlayer),
        Provider<LibraryService>.value(value: libraryService),
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LibraryProvider>(
          create: (_) => LibraryProvider(libraryService),
        ),
        ChangeNotifierProvider<VoiceStudioProvider>(
          create: (_) => VoiceStudioProvider(
            api: api,
            settings: () => settings,
            player: audioPlayer,
            library: libraryService,
          ),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            api: api,
            settings: () => settings,
            storage: storage,
          ),
        ),
      ],
      child: const PandaAiStudioApp(),
    ),
  );
}
