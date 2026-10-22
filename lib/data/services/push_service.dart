import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';
import 'local_alerts.dart';

/// Registers this device for push notifications (new orders, order updates,
/// chat messages). Messages are sent by Cloud Functions.
class PushService {
  PushService(this._users);
  final UserRepository _users;
  StreamSubscription<String>? _refresh;
  static bool _listening = false;

  /// Opens the screen a notification is about (set by the app).
  static void Function(Map<String, String> data)? onOpen;

  /// Banners while the app is open, and taps on notifications.
  static Future<void> listen() async {
    if (kIsWeb || _listening) return;
    _listening = true;
    FirebaseMessaging.onMessage.listen(LocalAlerts.show);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(m.data.map((k, v) => MapEntry(k, '$v'))));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Opened from a notification while the app was closed: wait for the first screen.
      Future<void>.delayed(const Duration(seconds: 3), () => onOpen?.call(initial.data.map((k, v) => MapEntry(k, '$v'))));
    }
  }

  Future<void> register(String uid) async {
    if (kIsWeb) return; // Web push needs a VAPID key; add it later if you launch on web.
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission(alert: true, badge: true, sound: true);
      await listen();
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
