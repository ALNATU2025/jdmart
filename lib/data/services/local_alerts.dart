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

  /// Sponsored-ad reminders (users can turn these off).
  static const promoChannel = AndroidNotificationChannel(
    'jdmart_promos',
    'Sponsored offers',
    description: 'Deals and products advertised on JDMart',
    importance: Importance.high,
    playSound: true,
  );

  static FlutterLocalNotificationsPlugin get plugin => _plugin;
  static bool get ready => _ready;

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
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(promoChannel);
    _ready = true;
    // Opened the app by tapping a scheduled reminder while it was closed.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && p != null && p.isNotEmpty) {
        final m = (jsonDecode(p) as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
        Future.delayed(const Duration(seconds: 2), () => onTap?.call(m));
      }
    } catch (_) {}
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
