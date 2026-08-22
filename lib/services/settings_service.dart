import 'package:shared_preferences/shared_preferences.dart';

/// Глобальные настройки приложения. Паттерн взят из settings_service.dart
/// донора: статические методы поверх shared_preferences.
class SettingsService {
  static const String _keyUnits = 'settings_units'; // 'mm' | 'm'
  static const String _keySkipPreflight = 'settings_skip_preflight';
  static const String _keyLastDeviceId = 'settings_last_device_id';
  static const String _keyLastPerformer = 'settings_last_performer';
  static const String _keyLastPreset = 'settings_last_preset';
  static const String _keyTimezone = 'settings_timezone';

  static Future<String> loadUnits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUnits) ?? 'mm';
  }

  static Future<void> saveUnits(String units) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUnits, units);
  }

  static Future<bool> loadSkipPreflight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySkipPreflight) ?? false;
  }

  static Future<void> saveSkipPreflight(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySkipPreflight, value);
  }

  static Future<int?> loadLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastDeviceId);
  }

  /// Исполнитель поверки обычно один и тот же — подставляем прошлого.
  static Future<String?> loadLastPerformer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastPerformer);
  }

  static Future<void> saveLastPerformer(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPerformer, name);
  }

  static Future<void> saveLastDeviceId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDeviceId, id);
  }

  static Future<String?> loadLastPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastPreset);
  }

  static Future<void> saveLastPreset(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPreset, presetId);
  }

  /// Сохранённая таймзона — сверяется при возврате приложения в foreground,
  /// чтобы перепланировать напоминания после смены часового пояса.
  static Future<String?> loadTimezone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTimezone);
  }

  static Future<void> saveTimezone(String tz) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimezone, tz);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUnits);
    await prefs.remove(_keySkipPreflight);
    await prefs.remove(_keyLastDeviceId);
    await prefs.remove(_keyLastPerformer);
    await prefs.remove(_keyLastPreset);
  }
}
