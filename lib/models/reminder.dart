/// Напоминание о поверке — настраивается на уровне конкретного прибора,
/// не глобально, и по умолчанию выключено.
class Reminder {
  final int? id;
  final int deviceId;
  final bool enabled;

  /// 'day' | 'week' | 'month' | 'year'
  final String intervalKind;
  final int intervalCount;

  /// 1..7 (пн..вс), только для intervalKind == 'week'
  final int? dayOfWeek;

  /// 1..31, только для 'month' и 'year'
  final int? dayOfMonth;

  /// 1..12, только для 'year'
  final int? monthOfYear;

  final int hour;
  final int minute;
  final DateTime? nextFireAt;

  const Reminder({
    this.id,
    required this.deviceId,
    this.enabled = false,
    this.intervalKind = 'month',
    this.intervalCount = 6,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.hour = 9,
    this.minute = 0,
    this.nextFireAt,
  });

  /// ID уведомления в flutter_local_notifications — привязан к прибору,
  /// чтобы отмена/перепланирование не задевали чужие напоминания.
  int get notificationId => 100000 + deviceId;

  String get intervalLabel {
    final unit = switch (intervalKind) {
      'day' => _plural(intervalCount, 'день', 'дня', 'дней'),
      'week' => _plural(intervalCount, 'неделю', 'недели', 'недель'),
      'month' => _plural(intervalCount, 'месяц', 'месяца', 'месяцев'),
      'year' => _plural(intervalCount, 'год', 'года', 'лет'),
      _ => intervalKind,
    };
    return 'раз в $intervalCount $unit';
  }

  static String _plural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  /// Следующее срабатывание от заданной точки отсчёта.
  DateTime computeNextFire(DateTime from) {
    var base = DateTime(from.year, from.month, from.day, hour, minute);
    if (!base.isAfter(from)) {
      base = base.add(const Duration(days: 1));
    }

    switch (intervalKind) {
      case 'day':
        return base.add(Duration(days: intervalCount - 1));
      case 'week':
        var d = base;
        if (dayOfWeek != null) {
          while (d.weekday != dayOfWeek) {
            d = d.add(const Duration(days: 1));
          }
        }
        return d.add(Duration(days: 7 * (intervalCount - 1)));
      case 'month':
        final target = DateTime(
          from.year,
          from.month + intervalCount,
          dayOfMonth ?? from.day,
          hour,
          minute,
        );
        return target;
      case 'year':
        return DateTime(
          from.year + intervalCount,
          monthOfYear ?? from.month,
          dayOfMonth ?? from.day,
          hour,
          minute,
        );
      default:
        return base;
    }
  }

  Reminder copyWith({
    int? id,
    bool? enabled,
    String? intervalKind,
    int? intervalCount,
    int? dayOfWeek,
    int? dayOfMonth,
    int? monthOfYear,
    int? hour,
    int? minute,
    DateTime? nextFireAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      deviceId: deviceId,
      enabled: enabled ?? this.enabled,
      intervalKind: intervalKind ?? this.intervalKind,
      intervalCount: intervalCount ?? this.intervalCount,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      nextFireAt: nextFireAt ?? this.nextFireAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'device_id': deviceId,
        'enabled': enabled ? 1 : 0,
        'interval_kind': intervalKind,
        'interval_count': intervalCount,
        'day_of_week': dayOfWeek,
        'day_of_month': dayOfMonth,
        'month_of_year': monthOfYear,
        'hour': hour,
        'minute': minute,
        'next_fire_at': nextFireAt?.toIso8601String(),
      };

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
        id: m['id'] as int?,
        deviceId: m['device_id'] as int,
        enabled: (m['enabled'] as int? ?? 0) == 1,
        intervalKind: m['interval_kind'] as String? ?? 'month',
        intervalCount: (m['interval_count'] as num?)?.toInt() ?? 6,
        dayOfWeek: (m['day_of_week'] as num?)?.toInt(),
        dayOfMonth: (m['day_of_month'] as num?)?.toInt(),
        monthOfYear: (m['month_of_year'] as num?)?.toInt(),
        hour: (m['hour'] as num?)?.toInt() ?? 9,
        minute: (m['minute'] as num?)?.toInt() ?? 0,
        nextFireAt: m['next_fire_at'] == null
            ? null
            : DateTime.parse(m['next_fire_at'] as String),
      );
}
