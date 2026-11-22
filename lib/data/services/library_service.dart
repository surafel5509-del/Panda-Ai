import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../core/constants/api_config.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// Local audio library: MP3 files on disk + metadata persisted across
/// restarts in SharedPreferences (JSON). Files live in the app documents
/// directory under `panda_audio/`.
class LibraryService {
  final StorageService _storage;

  LibraryService(this._storage);

  static const String _folderName = 'panda_audio';

  Future<Directory> _libraryDir() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> tempDir() async {
    final Directory tmp = await getTemporaryDirectory();
    final Directory dir = Directory('${tmp.path}/panda_tmp');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves MP3 bytes to disk and records its metadata. Returns the item.
  Future<LibraryItem> saveAudio({
    required Uint8List bytes,
    required String text,
    required String voiceId,
    required String voiceName,
    required String style,
    required String model,
    required double speed,
    required double volume,
    int? durationMs,
  }) async {
    final Directory dir = await _libraryDir();
    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    final File file = File('${dir.path}/panda_$id.mp3');
    await file.writeAsBytes(bytes, flush: true);

    final String trimmedText = text.trim();
    final String title = trimmedText.length > 48
        ? '${trimmedText.substring(0, 48)}…'
        : (trimmedText.isEmpty ? 'Untitled audio' : trimmedText);

    final LibraryItem item = LibraryItem(
      id: id,
      title: title,
      text: text,
      voiceId: voiceId,
      voiceName: voiceName,
      style: style,
      model: model,
      speed: speed,
      volume: volume,
      filePath: file.path,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );

    final List<LibraryItem> items = await listItems();
    items.insert(0, item);
    await _persist(items);
    return item;
  }

  Future<List<LibraryItem>> listItems() async {
    final String raw = await _storage.readJsonList(ApiConfig.prefsLibraryItems);
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(LibraryItem.fromJson)
            .toList();
      }
    } catch (_) {
      // Corrupted prefs — start clean rather than crash.
    }
    return <LibraryItem>[];
  }

  Future<void> _persist(List<LibraryItem> items) async {
    final String encoded = jsonEncode(
        items.map((LibraryItem e) => e.toJson()).toList());
    await _storage.saveJsonList(ApiConfig.prefsLibraryItems, encoded);
  }

  Future<void> deleteItem(String id) async {
    final List<LibraryItem> items = await listItems();
    final LibraryItem? target =
        items.where((LibraryItem e) => e.id == id).firstOrNull;
    if (target != null) {
      final File file = File(target.filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // File already gone — still remove metadata.
        }
      }
    }
    items.removeWhere((LibraryItem e) => e.id == id);
    await _persist(items);
  }

  /// Deletes every saved audio file and clears metadata.
  Future<void> clearAll() async {
    final Directory dir = await _libraryDir();
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Best effort.
      }
    }
    await _persist(<LibraryItem>[]);
  }

  /// Deletes temporary preview files.
  Future<void> clearTempFiles() async {
    final Directory dir = await tempDir();
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Best effort.
      }
    }
  }

  /// Total size in bytes of all saved audio files.
  Future<int> totalBytes() async {
    final List<LibraryItem> items = await listItems();
    int total = 0;
    for (final LibraryItem item in items) {
      final File file = File(item.filePath);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  /// Removes metadata entries whose audio file no longer exists.
  Future<List<LibraryItem>> pruneMissingFiles() async {
    final List<LibraryItem> items = await listItems();
    final List<LibraryItem> kept = <LibraryItem>[];
    for (final LibraryItem item in items) {
      if (await File(item.filePath).exists()) kept.add(item);
    }
    if (kept.length != items.length) await _persist(kept);
    return kept;
  }
}
