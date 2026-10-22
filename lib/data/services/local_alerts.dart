import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Pop-up (heads-up) notifications on Android.
///
/// Push messages from the server use the high-importance "jdmart_alerts"
/// channel, so Android shows them as banners over other apps, on the lock
/// screen and with sound — even when JDMart is closed. While the app is open,
/// Android doesn't show push banners itself, so we show them here.
class LocalAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const channel = AndroidNotificationChannel(
    'jdmart_alerts',
    'JDMart alerts',
    description: 'Orders, messages, deliveries, jobs and account updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Called with the notification's data when the user taps a banner.
  static void Function(Map<String, String> data)? onTap;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_jdmart'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p == null || p.isEmpty) return;
        try {
          final m = (jsonDecode(p) as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
          onTap?.call(m);
        } catch (_) {}
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _ready = true;
  }

  /// Shows a push message as a banner while the app is in the foreground.
  static Future<void> show(RemoteMessage m) async {
    if (kIsWeb || !_ready) return;
    final n = m.notification;
    if (n == null) return;
    await _plugin.show(
      m.hashCode & 0x7fffffff,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_stat_jdmart',
          color: const Color(0xFF0029A8),
          styleInformation: BigTextStyleInformation(n.body ?? ''),
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }
}
