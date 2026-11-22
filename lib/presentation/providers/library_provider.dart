import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/services/library_service.dart';

enum LibrarySort { newest, oldest }

/// Manages the local audio library (generated speech saved on device).
class LibraryProvider extends ChangeNotifier {
  final LibraryService _service;

  LibraryProvider(this._service);

  List<LibraryItem> _items = <LibraryItem>[];
  bool _loading = false;
  String _query = '';
  LibrarySort sort = LibrarySort.newest;

  List<LibraryItem> get items => _items;
  bool get isLoading => _loading;
  String get query => _query;

  List<LibraryItem> get visibleItems {
    List<LibraryItem> list = _items;
    final String q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((LibraryItem e) =>
              e.title.toLowerCase().contains(q) ||
              e.voiceName.toLowerCase().contains(q) ||
              e.text.toLowerCase().contains(q))
          .toList();
    }
    final List<LibraryItem> sorted = List<LibraryItem>.from(list);
    sorted.sort((LibraryItem a, LibraryItem b) => sort == LibrarySort.newest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _service.pruneMissingFiles();
    _loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSort(LibrarySort value) {
    sort = value;
    notifyListeners();
  }

  Future<void> addItem(LibraryItem item) async {
    _items.insert(0, item);
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    await _service.deleteItem(id);
    _items.removeWhere((LibraryItem e) => e.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _items = <LibraryItem>[];
    notifyListeners();
  }

  Future<int> totalBytes() => _service.totalBytes();
  Future<void> clearTempFiles() => _service.clearTempFiles();
}
