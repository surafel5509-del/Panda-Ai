import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

export 'package:audioplayers/audioplayers.dart' show PlayerState;

/// Single shared audio player for previews, generated audio and library
/// playback. Exposes streams so the UI can render progress and waveforms.
///
/// [duration] and [position] are cached from the player streams so they
/// work on every audioplayers 6.x release (which only guarantees the
/// stream and async getter APIs).
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  AudioPlayerService() {
    _player.onDurationChanged.listen((Duration d) => _duration = d);
    _player.onPositionChanged.listen((Duration p) => _position = p);
  }

  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<void> get completeStream => _player.onPlayerComplete;

  PlayerState get state => _player.state;

  /// Last known total duration of the current audio (zero when unknown).
  Duration get duration => _duration;

  /// Last known playback position of the current audio.
  Duration get position => _position;

  String? _currentPath;

  /// Plays an MP3 file from disk.
  Future<void> playFile(String path) async {
    _currentPath = path;
    _position = Duration.zero;
    _duration = Duration.zero;
    await _player.play(DeviceFileSource(path));
  }

  /// Plays MP3 bytes (writes a temp file first — the most reliable path
  /// across Android/iOS for in-memory audio).
  Future<void> playBytes(Uint8List bytes, {String? tempDir}) async {
    final Directory dir = tempDir != null
        ? Directory(tempDir)
        : await Directory.systemTemp.createTemp('panda_audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final File file = File(
        '${dir.path}/panda_${DateTime.now().microsecondsSinceEpoch}.mp3');
    await file.writeAsBytes(bytes, flush: true);
    await playFile(file.path);
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));
  Future<void> setSpeed(double rate) =>
      _player.setPlaybackRate(rate.clamp(0.5, 2.0));

  String? get currentPath => _currentPath;

  Future<void> dispose() => _player.dispose();
}
