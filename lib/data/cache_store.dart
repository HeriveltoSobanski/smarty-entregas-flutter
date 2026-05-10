import 'dart:convert';
import '../core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheStore {
  static const _prefix = 'cache_';

  static Future<void> save(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(data));
    } catch (e, st) { AppLogger.e('CacheStore', e, st); }
  }

  static Future<T?> load<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      return jsonDecode(raw) as T?;
    } catch (e, st) {
      AppLogger.e('CacheStore', e, st);
      return null;
    }
  }

  static Future<void> clear(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (e, st) { AppLogger.e('CacheStore', e, st); }
  }
}
