import 'package:flutter/foundation.dart';
import '../data/services/local_store.dart';

class SearchHistory extends ChangeNotifier {
  static const _key = 'recent_searches';
  List<String> _items = LocalStore.getStringList(_key);

  List<String> get items => List.unmodifiable(_items);

  void add(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    _items = [t, ..._items.where((e) => e.toLowerCase() != t.toLowerCase())].take(8).toList();
    LocalStore.setStringList(_key, _items);
    notifyListeners();
  }

  void clear() {
    _items = [];
    LocalStore.setStringList(_key, _items);
    notifyListeners();
  }
}
