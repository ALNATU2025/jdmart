import 'package:flutter/foundation.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _usersKey = 'users';
  static const _sessionKey = 'session_user_id';

  final List<AppUser> _users = [];
  AppUser? _current;

  AppUser? get user => _current;
  bool get isLoggedIn => _current != null;

  void load() {
    final stored = StorageService.readList(_usersKey).map(AppUser.fromJson).toList();
    _users
      ..clear()
      ..addAll(stored.isEmpty ? SeedData.sellers : stored);
    // Make sure demo sellers always exist (e.g. after an update that adds new ones).
    for (final s in SeedData.sellers) {
      if (!_users.any((u) => u.id == s.id)) _users.add(s);
    }
    final sid = StorageService.getString(_sessionKey);
    _current = sid == null ? null : findById(sid);
    _save();
  }

  AppUser? findById(String id) {
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> _save() => StorageService.writeList(_usersKey, _users.map((u) => u.toJson()).toList());

  String _key(String s) => s.replaceAll(RegExp(r'[^0-9a-zA-Z@.]'), '').toLowerCase();

  /// Returns an error message, or null on success.
  Future<String?> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String city,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_users.any((u) => _key(u.phone) == _key(phone))) {
      return 'An account with this phone number already exists.';
    }
    if (email.isNotEmpty && _users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'An account with this email already exists.';
    }
    final u = AppUser(
      id: StorageService.newId('u'),
      name: name.trim(),
      phone: phone,
      email: email.trim(),
      password: password,
      city: city,
    );
    _users.add(u);
    _current = u;
    await StorageService.setString(_sessionKey, u.id);
    await _save();
    notifyListeners();
    return null;
  }

  Future<String?> login(String phoneOrEmail, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final k = _key(phoneOrEmail);
    AppUser? found;
    for (final u in _users) {
      final local = k.replaceFirst(RegExp(r'^(232|0)'), '');
      final phoneMatch = local.length >= 8 && _key(u.phone).endsWith(local);
      if (phoneMatch || u.email.toLowerCase() == phoneOrEmail.trim().toLowerCase()) {
        found = u;
        break;
      }
    }
    if (found == null) return 'No account found. Please sign up.';
    if (found.password != password) return 'Incorrect password.';
    _current = found;
    await StorageService.setString(_sessionKey, found.id);
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _current = null;
    await StorageService.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? email, String? city, String? bio, String? avatarPath}) async {
    final u = _current;
    if (u == null) return;
    if (name != null) u.name = name;
    if (email != null) u.email = email;
    if (city != null) u.city = city;
    if (bio != null) u.bio = bio;
    if (avatarPath != null) u.avatarPath = avatarPath;
    await _save();
    notifyListeners();
  }
}
