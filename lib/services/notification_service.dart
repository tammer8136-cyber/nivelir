import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import 'database_service.dart';
import 'settings_service.dart';

/// Локальные напоминания о поверке.
///
/// Сознательно используются НЕТОЧНЫЕ будильники
/// (AndroidScheduleMode.inexactAllowWhileIdle): напоминанию "пора поверить
/// нивелир" не нужна точность до минуты, а значит не нужно разрешение
/// SCHEDULE_EXACT_ALARM (deny-by-default с Android 14) и вся логика его
/// запроса. Пакет timezone всё равно нужен — для корректной математики
/// часовых поясов, а не для точности момента срабатывания.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'verification_reminders';
  static const String _channelName = 'Напоминания о поверке';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    final localName = await _resolveLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    await SettingsService.saveTimezone(localName);
    _initialized = true;
  }

  Future<String> _resolveLocalTimezone() async {
    // Без дополнительных плагинов достоверно доступно только смещение UTC.
    // Ищем зону с тем же текущим смещением — для напоминаний "раз в полгода
    // в 9:00" этой точности достаточно.
    final offset = DateTime.now().timeZoneOffset;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      final location = tz.getLocation(name);
      final now = tz.TZDateTime.now(location);
      if (now.timeZoneOffset == offset) return name;
    }
    return 'UTC';
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(alert: true, sound: true);

    return granted ?? iosGranted ?? true;
  }

  Future<void> schedule(Reminder reminder, String deviceLabel) async {
    await cancel(reminder);
    if (!reminder.enabled) return;

    final next = reminder.nextFireAt ?? reminder.computeNextFire(DateTime.now());
    final scheduled = tz.TZDateTime.from(next, tz.local);

    await _plugin.zonedSchedule(
      reminder.notificationId,
      'Пора выполнить поверку',
      '$deviceLabel — ${reminder.intervalLabel}',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Плановые напоминания о поверке главного условия нивелира',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'device:${reminder.deviceId}',
    );
  }

  Future<void> cancel(Reminder reminder) async {
    await _plugin.cancel(reminder.notificationId);
  }

  Future<void> cancelForDevice(int deviceId) async {
    await _plugin.cancel(100000 + deviceId);
  }

  /// Перепланирование всех активных напоминаний после смены часового пояса.
  Future<void> rescheduleIfTimezoneChanged(DatabaseService db) async {
    if (!_initialized) return;

    final stored = await SettingsService.loadTimezone();
    final current = await _resolveLocalTimezone();
    if (stored == current) return;

    tz.setLocalLocation(tz.getLocation(current));
    await SettingsService.saveTimezone(current);

    final reminders = await db.getEnabledReminders();
    for (final reminder in reminders) {
      final device = await db.getInstance(reminder.deviceId);
      if (device == null) continue;
      await schedule(reminder, device.displayName);
    }
  }
}
