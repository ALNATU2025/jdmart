import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';

/// Registers this device for push notifications (new orders, order updates,
/// chat messages). Messages are sent by Cloud Functions.
class PushService {
  PushService(this._users);
  final UserRepository _users;
  StreamSubscription<String>? _refresh;

  Future<void> register(String uid) async {
    if (kIsWeb) return; // Web push needs a VAPID key; add it later if you launch on web.
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await m.getToken();
      if (token != null) await _users.addPushToken(uid, token);
      await _refresh?.cancel();
      _refresh = m.onTokenRefresh.listen((t) => _users.addPushToken(uid, t));
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> unregister(String uid) async {
    await _refresh?.cancel();
    _refresh = null;
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _users.removePushToken(uid, token);
    } catch (_) {}
  }
}
