import 'package:intl/intl.dart';

/// Отсчёты хранятся канонически в ЦЕЛЫХ МИЛЛИМЕТРАХ. Метры — только формат
/// отображения и ввода; конвертация живёт здесь, чтобы округление было
/// в одном месте.
class Units {
  Units._();

  static final NumberFormat _mm = NumberFormat('#,##0', 'ru_RU');
  static final NumberFormat _m = NumberFormat('0.000', 'ru_RU');
  static final NumberFormat _arcsec = NumberFormat('0.0', 'ru_RU');
  static final DateFormat dateTime = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final DateFormat dateOnly = DateFormat('dd.MM.yyyy', 'ru_RU');

  /// Отсчёт из мм в строку в выбранных единицах (без подписи единицы).
  static String reading(num mm, bool isMillimeters) {
    return isMillimeters ? _mm.format(mm.round()) : _m.format(mm / 1000.0);
  }

  /// То же, но с подписью.
  static String readingWithUnit(num mm, bool isMillimeters) {
    return '${reading(mm, isMillimeters)} ${isMillimeters ? "мм" : "м"}';
  }

  /// Знаковая величина (превышение, разность) — со знаком плюс для наглядности.
  static String signed(num mm, bool isMillimeters) {
    final s = readingWithUnit(mm.abs(), isMillimeters);
    if (mm > 0) return '+$s';
    if (mm < 0) return '−$s';
    return s;
  }

  /// Разбор пользовательского ввода в целые мм. Принимает и точку, и запятую.
  /// В режиме "м" 1.234 -> 1234 мм. Возвращает null, если строка не число.
  static int? parseReading(String raw, bool isMillimeters) {
    final normalized = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return isMillimeters ? value.round() : (value * 1000).round();
  }

  /// Значение поля ввода при переключении единиц.
  static String formatForInput(int mm, bool isMillimeters) {
    return isMillimeters ? '$mm' : (mm / 1000.0).toStringAsFixed(3);
  }

  static String arcsec(double value) => '${_arcsec.format(value)}″';

  static String signedArcsec(double value) {
    final s = arcsec(value.abs());
    if (value > 0) return '+$s';
    if (value < 0) return '−$s';
    return s;
  }

  static String meters(double value) {
    final formatted = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$formatted м';
  }
}
