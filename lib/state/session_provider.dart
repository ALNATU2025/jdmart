import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/models/app_user.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/push_service.dart';

/// Who is signed in (email + password), and their profile. Guests can browse;
/// buying, selling and chatting require a signed-in user with a profile.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this.auth, this._users, this._push) {
    _authSub = auth.changes.listen(_onAuth);
  }

  final AuthService auth;
  final UserRepository _users;
  final PushService _push;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;
  StreamSubscription<Map<String, dynamic>>? _privateSub;

  User? _authUser;
  AppUser? _profile;
  bool _authResolved = false;
  bool _profileResolved = false;
  String _phone = '';
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  User? get authUser => _authUser;
  AppUser? get profile => _profile;
  String? get uid => _authUser?.uid;
  String get email => _authUser?.email ?? '';

  /// Admin console access (from the `admin` / `superAdmin` sign-in claims,
  /// set by the server; Firestore rules enforce the same claims).
  bool get isAdmin => _isAdmin;
  bool get isSuperAdmin => _isSuperAdmin;

  /// The user's phone number (E.164), from their private account data.
  String get phone => _phone;

  /// True once we know whether someone is signed in (and loaded their profile).
  bool get ready => _authResolved && (_authUser == null || _profileResolved);
  bool get isLoggedIn => _authUser != null && _profile != null;

  /// Signed in by email but hasn't completed the profile form yet.
  bool get needsProfile => _authUser != null && _profileResolved && _profile == null;

  void _onAuth(User? user) {
    final previous = _authUser?.uid;
    _authUser = user;
    _authResolved = true;
    _profileSub?.cancel();
    _privateSub?.cancel();
    _profile = null;
    _profileResolved = false;
    _phone = '';
    _isAdmin = false;
    _isSuperAdmin = false;
    if (user != null) {
      _loadClaims(user);
      _privateSub = _users.watchPrivate(user.uid).listen((d) {
        _phone = (d['phone'] ?? '') as String;
        notifyListeners();
      }, onError: (Object e) => debugPrint('Private data stream error: $e'));
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

  Future<void> _loadClaims(User user) async {
    try {
      // Roles come from the sign-in token when the server has set them, and
      // otherwise from the database (super admin email or /admins list).
      var r = await user.getIdTokenResult(true);
      var c = r.claims ?? const <String, dynamic>{};
      if (c['admin'] != true) {
        await auth.refreshRoles();
        if (_authUser?.uid != user.uid) return;
        r = await user.getIdTokenResult(true);
        c = r.claims ?? const <String, dynamic>{};
      }
      var admin = c['admin'] == true;
      var superAdmin = c['superAdmin'] == true;
      if (!admin) {
        final db = await auth.rolesFromDatabase(user);
        admin = db.admin;
        superAdmin = db.superAdmin;
      }
      if (_authUser?.uid != user.uid) return;
      _isAdmin = admin;
      _isSuperAdmin = superAdmin;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not read sign-in roles: $e');
    }
  }

  /// True when the signed-in email address hasn't been confirmed yet.
  bool get emailUnverified => _authUser != null && !_authUser!.emailVerified;

  /// Re-reads the account (e.g. after the user clicked the verification link).
  Future<void> reloadUser() async {
    final u = _authUser;
    if (u == null) return;
    try {
      await u.reload();
      final fresh = auth.currentUser;
      if (fresh != null) {
        _authUser = fresh;
        await _loadClaims(fresh);
        notifyListeners();
      }
    } catch (_) {}
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
    _privateSub?.cancel();
    super.dispose();
  }
}
