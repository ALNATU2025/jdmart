import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/models/app_user.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/push_service.dart';

/// Who is signed in, and their profile. Guests can browse; buying, selling and
/// chatting require a signed-in user with a profile.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this.auth, this._users, this._push) {
    _authSub = auth.changes.listen(_onAuth);
  }

  final AuthService auth;
  final UserRepository _users;
  final PushService _push;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  User? _authUser;
  AppUser? _profile;
  bool _authResolved = false;
  bool _profileResolved = false;

  User? get authUser => _authUser;
  AppUser? get profile => _profile;
  String? get uid => _authUser?.uid;
  String get phone => _authUser?.phoneNumber ?? '';

  /// True once we know whether someone is signed in (and loaded their profile).
  bool get ready => _authResolved && (_authUser == null || _profileResolved);
  bool get isLoggedIn => _authUser != null && _profile != null;

  /// Signed in with a phone number but hasn't completed the profile form yet.
  bool get needsProfile => _authUser != null && _profileResolved && _profile == null;

  void _onAuth(User? user) {
    final previous = _authUser?.uid;
    _authUser = user;
    _authResolved = true;
    _profileSub?.cancel();
    _profile = null;
    _profileResolved = false;
    if (user != null) {
      _profileSub = _users.watch(user.uid).listen((p) {
        final firstLoad = !_profileResolved;
        _profile = p;
        _profileResolved = true;
        if (p != null && firstLoad) _push.register(user.uid);
        notifyListeners();
      }, onError: (Object e) {
        debugPrint('Profile stream error: $e');
        _profileResolved = true;
        notifyListeners();
      });
    } else if (previous != null) {
      _push.unregister(previous);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    final id = uid;
    if (id != null) await _push.unregister(id);
    await auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
