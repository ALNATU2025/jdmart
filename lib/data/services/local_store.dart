import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Small on-device storage for things that don't need a server: the cart,
/// recent searches and whether onboarding was shown.
class LocalStore {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> writeList(String key, List<Map<String, dynamic>> list) =>
      _prefs.setString(key, jsonEncode(list));

  static Future<void> remove(String key) => _prefs.remove(key);

  static List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  static Future<void> setStringList(String key, List<String> v) => _prefs.setStringList(key, v);

  static String? getString(String key) => _prefs.getString(key);
  static Future<void> setString(String key, String v) => _prefs.setString(key, v);

  static bool getBool(String key) => _prefs.getBool(key) ?? false;
  static Future<void> setBool(String key, bool v) => _prefs.setBool(key, v);
}
