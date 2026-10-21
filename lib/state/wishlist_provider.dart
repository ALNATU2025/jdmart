import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories/misc_repositories.dart';

/// Saved items for the signed-in user, synced across devices.
class WishlistProvider extends ChangeNotifier {
  WishlistProvider(this._repo);
  final WishlistRepository _repo;

  String? _uid;
  Set<String> _ids = {};
  StreamSubscription<Set<String>>? _sub;

  Set<String> get ids => _ids;
  bool isSaved(String productId) => _ids.contains(productId);

  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _ids = {};
    if (uid != null) {
      _sub = _repo.ids(uid).listen((s) {
        _ids = s;
        notifyListeners();
      }, onError: (Object e) => debugPrint('Wishlist error: $e'));
    }
    notifyListeners();
  }

  /// Returns false if the user must sign in first.
  bool toggle(String productId) {
    final uid = _uid;
    if (uid == null) return false;
    final save = !_ids.contains(productId);
    _ids = {..._ids};
    save ? _ids.add(productId) : _ids.remove(productId);
    notifyListeners(); // optimistic
    _repo.set(uid, productId, save);
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
