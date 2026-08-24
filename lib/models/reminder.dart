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
  ///
  /// Правило одно на все единицы: дата [from] плюс интервал, во столько-то
  /// часов. Никаких «минус один», потому что смешивать сдвиг на день со
  /// сдвигом на неделю нельзя — раньше «раз в неделю» давало срабатывание
  /// на следующий день, а не через семь.
  ///
  /// Для недельного интервала с заданным днём недели точка отсчёта иная:
  /// ближайший нужный день недели, затем целые недели.
  DateTime computeNextFire(DateTime from) {
    switch (intervalKind) {
      case 'day':
        return _atTime(
          DateTime(from.year, from.month, from.day)
              .add(Duration(days: intervalCount)),
        );

      case 'week':
        final wd = dayOfWeek;
        if (wd != null && wd >= 1 && wd <= 7) {
          // Ближайший нужный день недели, начиная со следующего дня.
          var d = DateTime(from.year, from.month, from.day)
              .add(const Duration(days: 1));
          // Ограничитель обязателен: при испорченном dayOfWeek вне 1..7
          // цикл был бы бесконечным.
          for (var i = 0; i < 7 && d.weekday != wd; i++) {
            d = d.add(const Duration(days: 1));
          }
          return _atTime(d.add(Duration(days: 7 * (intervalCount - 1))));
        }
        return _atTime(
          DateTime(from.year, from.month, from.day)
              .add(Duration(days: 7 * intervalCount)),
        );

      case 'month':
        return _shiftMonths(from, intervalCount, dayOfMonth ?? from.day);

      case 'year':
        return _shiftMonths(
          from,
          12 * intervalCount,
          dayOfMonth ?? from.day,
          monthOfYear: monthOfYear,
        );

      default:
        return _atTime(
          DateTime(from.year, from.month, from.day)
              .add(const Duration(days: 1)),
        );
    }
  }

  DateTime _atTime(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// Сдвиг на целое число месяцев с ОБРЕЗКОЙ дня по длине месяца.
  ///
  /// Без обрезки Dart переносит переполнение вперёд: DateTime(2026, 2, 31)
  /// даёт 3 марта. Для напоминания, поставленного 31 января, это означало
  /// бы уход на начало марта вместо конца февраля.
  DateTime _shiftMonths(
    DateTime from,
    int months,
    int day, {
    int? monthOfYear,
  }) {
    var year = from.year;
    var month = (monthOfYear ?? from.month) + months;

    // Приведение месяца к 1..12 вручную: полагаться на нормализацию Dart
    // здесь нельзя, день обрезается по УЖЕ известному месяцу.
    year += (month - 1) ~/ 12;
    month = (month - 1) % 12 + 1;

    final lastDay = _daysInMonth(year, month);
    final safeDay = day > lastDay ? lastDay : day;

    return DateTime(year, month, safeDay, hour, minute);
  }

  static int _daysInMonth(int year, int month) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeap(year)) return 29;
    return lengths[month - 1];
  }

  static bool _isLeap(int y) =>
      (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

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
