import 'package:flutter/foundation.dart';

import '../../core/constants/api_config.dart';
import '../../core/utils/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/library_service.dart';
import 'settings_provider.dart';

enum VoiceGenderFilter { all, male, female }

/// State for the Voice Studio: text, voice/style/engine selection,
/// preview playback and speech generation.
class VoiceStudioProvider extends ChangeNotifier {
  final ApiService _api;
  final SettingsProvider Function() _settings;
  final AudioPlayerService _player;
  final LibraryService _library;

  VoiceStudioProvider({
    required ApiService api,
    required SettingsProvider Function() settings,
    required AudioPlayerService player,
    required LibraryService library,
  })  : _api = api,
        _settings = settings,
        _player = player,
        _library = library;

  // Text
  String text = '';
  int get charCount => text.length;
  int get maxChars => ApiConfig.maxTtsChars;
  bool get canGenerate =>
      text.trim().isNotEmpty && selectedVoice != null && !isGenerating;

  // Catalog
  List<Voice> voices = <Voice>[];
  List<VoiceStyle> styles = <VoiceStyle>[];
  List<Engine> engines = <Engine>[];
  bool catalogLoading = false;
  String? catalogError;

  VoiceGenderFilter genderFilter = VoiceGenderFilter.all;
  String voiceQuery = '';

  Voice? selectedVoice;
  String selectedStyle = 'natural';
  String? selectedEngine;
  double speed = ApiConfig.defaultSpeed;
  double volume = ApiConfig.defaultVolume;

  // Preview
  bool isPreviewLoading = false;
  Uint8List? previewBytes;
  bool get isPreviewPlaying =>
      _player.state == PlayerState.playing && previewBytes != null;

  // Generation
  bool isGenerating = false;
  Uint8List? generatedBytes;
  LibraryItem? lastSavedItem;
  String? errorMessage;
  bool errorRetryable = false;

  bool get hasToken => _settings().hasToken;

  List<Voice> get visibleVoices {
    List<Voice> list = voices;
    switch (genderFilter) {
      case VoiceGenderFilter.male:
        list = list.where((Voice v) => v.isMale).toList();
        break;
      case VoiceGenderFilter.female:
        list = list.where((Voice v) => v.isFemale).toList();
        break;
      case VoiceGenderFilter.all:
        break;
    }
    final String q = voiceQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((Voice v) =>
              v.name.toLowerCase().contains(q) ||
              v.id.toLowerCase().contains(q) ||
              v.description.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void setText(String value) {
    text = value;
    errorMessage = null;
    notifyListeners();
  }

  void clearText() {
    text = '';
    generatedBytes = null;
    errorMessage = null;
    notifyListeners();
  }

  void setSampleText() {
    text = ApiConfig.sampleText;
    notifyListeners();
  }

  void setGenderFilter(VoiceGenderFilter filter) {
    genderFilter = filter;
    notifyListeners();
  }

  void setVoiceQuery(String value) {
    voiceQuery = value;
    notifyListeners();
  }

  void selectVoice(Voice voice) {
    selectedVoice = voice;
    previewBytes = null;
    generatedBytes = null;
    errorMessage = null;
    notifyListeners();
  }

  void selectStyle(String style) {
    selectedStyle = style;
    notifyListeners();
  }

  void selectEngine(String? engine) {
    selectedEngine = engine;
    notifyListeners();
  }

  void setSpeed(double value) {
    speed = value;
    notifyListeners();
  }

  void setVolume(double value) {
    volume = value;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  /// Loads voices, styles and engines from the live API. Falls back to
  /// stored defaults for speed/volume/style/engine/voice.
  Future<void> loadCatalog() async {
    catalogLoading = true;
    catalogError = null;
    notifyListeners();
    try {
      final ApiService api = _api;
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        api.getVoices(gender: 'all', pageSize: 50),
        api.getStyles(),
        api.getEngines(),
      ]);
      voices = results[0] as List<Voice>;
      styles = results[1] as List<VoiceStyle>;
      engines = results[2] as List<Engine>;

      final SettingsProvider s = _settings();
      speed = s.defaultSpeed;
      volume = s.defaultVolume;
      if (s.defaultStyle.isNotEmpty &&
          styles.any((VoiceStyle e) => e.id == s.defaultStyle)) {
        selectedStyle = s.defaultStyle;
      } else if (styles.isNotEmpty) {
        selectedStyle = styles.first.id;
      }
      if (s.defaultEngine != null &&
          engines.any((Engine e) => e.id == s.defaultEngine)) {
        selectedEngine = s.defaultEngine;
      } else if (engines.isNotEmpty) {
        selectedEngine = engines.first.id;
      }
      if (s.defaultVoiceId != null) {
        for (final Voice v in voices) {
          if (v.id == s.defaultVoiceId) {
            selectedVoice = v;
            break;
          }
        }
      }
      selectedVoice ??= voices.isNotEmpty ? voices.first : null;
    } catch (e) {
      catalogError = e.toString();
      if (styles.isEmpty) {
        styles = ApiConfig.documentedStyles
            .map((String s) => VoiceStyle(id: s, name: s))
            .toList();
      }
      if (engines.isEmpty) {
        engines = ApiConfig.documentedEngines
            .map((String e) =>
                Engine(id: e, name: e, isFree: e.contains('free')))
            .toList();
      }
    }
    catalogLoading = false;
    notifyListeners();
  }

  Future<void> refreshVoices() async {
    try {
      final List<Voice> fresh =
          await _api.getVoices(gender: 'all', pageSize: 50);
      if (fresh.isNotEmpty) {
        voices = fresh;
        if (selectedVoice != null) {
          for (final Voice v in voices) {
            if (v.id == selectedVoice!.id) {
              selectedVoice = v;
              break;
            }
          }
        }
        selectedVoice ??= voices.first;
      }
      catalogError = null;
    } catch (e) {
      catalogError = e.toString();
    }
    notifyListeners();
  }

  /// Fetches a short MP3 preview and plays it. Not a generation request.
  Future<void> playPreview() async {
    final Voice? voice = selectedVoice;
    if (voice == null) {
      errorMessage = 'Please select a voice first.';
      notifyListeners();
      return;
    }
    if (previewBytes != null && _player.state == PlayerState.playing) {
      await _player.pause();
      notifyListeners();
      return;
    }
    if (previewBytes != null && _player.state == PlayerState.paused) {
      await _player.resume();
      notifyListeners();
      return;
    }
    isPreviewLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final Uint8List bytes = await _api.preview(
            text: ApiConfig.sampleText,
            voiceId: voice.id,
            style: selectedStyle,
            model: selectedEngine,
            speed: speed,
            volume: volume,
          );
      previewBytes = bytes;
      final String tmpDir = (await _library.tempDir()).path;
      await _player.playBytes(bytes, tempDir: tmpDir);
    } catch (e) {
      errorMessage = e.toString();
      errorRetryable = e is ApiException && e.retryable;
    }
    isPreviewLoading = false;
    notifyListeners();
  }

  Future<void> togglePreviewPlayback() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else if (previewBytes != null) {
      final String tmpDir = (await _library.tempDir()).path;
      await _player.playBytes(previewBytes!, tempDir: tmpDir);
    }
    notifyListeners();
  }

  /// Generates full speech, saves it to the local library and returns the
  /// saved item (or null on failure, with [errorMessage] set).
  Future<LibraryItem?> generate() async {
    final Voice? voice = selectedVoice;
    if (voice == null) {
      errorMessage = 'Please select a voice first.';
      notifyListeners();
      return null;
    }
    if (text.trim().isEmpty) {
      errorMessage = 'Please enter some text to convert to speech.';
      notifyListeners();
      return null;
    }
    if (text.length > ApiConfig.maxTtsChars) {
      errorMessage =
          'Text is too long (${text.length} characters). The limit is ${ApiConfig.maxTtsChars}.';
      notifyListeners();
      return null;
    }
    isGenerating = true;
    errorMessage = null;
    generatedBytes = null;
    lastSavedItem = null;
    notifyListeners();
    try {
      final Uint8List bytes = await _api.generateSpeech(
            text: text.trim(),
            voiceId: voice.id,
            style: selectedStyle,
            model: selectedEngine,
            speed: speed,
            volume: volume,
          );
      generatedBytes = bytes;
      final LibraryItem item = await _library.saveAudio(
        bytes: bytes,
        text: text.trim(),
        voiceId: voice.id,
        voiceName: voice.name,
        style: selectedStyle,
        model: selectedEngine ?? '',
        speed: speed,
        volume: volume,
      );
      lastSavedItem = item;
      final String tmpDir = (await _library.tempDir()).path;
      await _player.playBytes(bytes, tempDir: tmpDir);
      return item;
    } catch (e) {
      errorMessage = e.toString();
      errorRetryable = e is ApiException && e.retryable;
      return null;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> playGenerated() async {
    if (generatedBytes == null) return;
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else {
      final String tmpDir = (await _library.tempDir()).path;
      await _player.playBytes(generatedBytes!, tempDir: tmpDir);
    }
    notifyListeners();
  }
}
