import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import '../../core/utils/formatters.dart';
import '../models/sponsored_ad.dart';
import 'local_alerts.dart';
import 'local_store.dart';

/// Shows paid ads as phone notifications every few hours (not at night),
/// rotating through the ads that are running. Each phone schedules its own
/// reminders whenever the app opens, so this works without the server.
class AdReminders {
  static const _firstId = 7000;
  static const _slots = 12;
  static const _offKey = 'ad_reminders_off';

  static bool get enabled => !LocalStore.getBool(_offKey);

  static Future<void> setEnabled(bool on) async {
    await LocalStore.setBool(_offKey, !on);
    await syncTopic();
    if (!on) await cancelAll();
  }

  /// Instant "new ad" pushes from the server go to the "sponsored" topic.
  static Future<void> syncTopic() async {
    if (kIsWeb) return;
    try {
      final m = FirebaseMessaging.instance;
      if (enabled) {
        await m.subscribeToTopic('sponsored');
      } else {
        await m.unsubscribeFromTopic('sponsored');
      }
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (kIsWeb || !LocalAlerts.ready) return;
    for (var i = 0; i < _slots; i++) {
      try {
        await LocalAlerts.plugin.cancel(_firstId + i);
      } catch (_) {}
    }
  }

  /// Next reminder times: every [hours] hours between 08:00 and 21:00.
  static List<DateTime> _times(int hours) {
    final out = <DateTime>[];
    var t = DateTime.now().add(const Duration(minutes: 40));
    while (out.length < _slots) {
      if (t.hour < 8) {
        t = DateTime(t.year, t.month, t.day, 8, 15);
      } else if (t.hour >= 21) {
        final next = t.add(const Duration(days: 1));
        t = DateTime(next.year, next.month, next.day, 8, 15);
      }
      out.add(t);
      t = t.add(Duration(hours: hours));
    }
    return out;
  }

  static Future<Uint8List?> _image(String? url) async {
    if (url == null || url.isEmpty) return null;
    final small = url.contains('/image/upload/') ? url.replaceFirst('/image/upload/', '/image/upload/w_720,c_limit/') : url;
    try {
      final r = await http.get(Uri.parse(small)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 && r.bodyBytes.length < 2500000) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Replaces the scheduled reminders with ones for [ads].
  static Future<void> refresh(List<SponsoredAd> ads, {int everyHours = 2}) async {
    if (kIsWeb || !LocalAlerts.ready) return;
    await cancelAll();
    unawaited(syncTopic());
    if (!enabled || ads.isEmpty) return;

    final images = <String, Uint8List?>{};
    for (final a in ads.take(6)) {
      images[a.id] = await _image(a.imageUrl);
    }

    final times = _times(everyHours.clamp(1, 12));
    var turn = 0;
    for (var i = 0; i < times.length; i++) {
      final at = times[i];
      // Next ad (in rotation) that is still running at that time.
      SponsoredAd? ad;
      for (var k = 0; k < ads.length; k++) {
        final c = ads[(turn + k) % ads.length];
        if (c.endsAt != null && c.endsAt!.isAfter(at)) {
          ad = c;
          turn = (turn + k + 1) % ads.length;
          break;
        }
      }
      if (ad == null) continue;
      final bytes = images[ad.id];
      final off = ad.discountPercent;
      final title = off > 0 ? '🔥 $off% OFF • ${ad.title}' : '⭐ ${ad.title}';
      final body = '${Fmt.price(ad.price)}${ad.city.isNotEmpty ? ' • ${ad.city}' : ''} — tap to see it on JDMart';
      try {
        await LocalAlerts.plugin.zonedSchedule(
          _firstId + i,
          title,
          body,
          tz.TZDateTime.from(at, tz.UTC),
          NotificationDetails(
            android: AndroidNotificationDetails(
              LocalAlerts.promoChannel.id,
              LocalAlerts.promoChannel.name,
              channelDescription: LocalAlerts.promoChannel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_jdmart',
              color: const Color(0xFFFB6401),
              subText: 'Sponsored',
              largeIcon: bytes == null ? null : ByteArrayAndroidBitmap(bytes),
              styleInformation: bytes == null
                  ? BigTextStyleInformation(body)
                  : BigPictureStyleInformation(
                      ByteArrayAndroidBitmap(bytes),
                      contentTitle: title,
                      summaryText: body,
                      hideExpandedLargeIcon: true,
                    ),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode({'type': 'product', 'productId': ad.productId, 'ad': ad.id}),
        );
      } catch (e) {
        debugPrint('Ad reminder not scheduled: $e');
      }
    }
  }
}
