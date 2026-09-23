/// Допуск прибора к нивелированию I, II, III и IV классов.
///
/// СПРАВОЧНО. Требования к приборам по классам работ — не полевой допуск
/// и не основание вердикта: класс работ задаётся программой работ или СТО
/// исполнителя, а годность прибора определяется его РЭ. Таблица показана
/// в карточке модели как ориентир при подборе прибора под класс.
///
/// Источник: ГКИНП (ГНТА)-03-010-03, п. 21.1, табл. 4 — общие требования к
/// приборам, предназначенным для нивелирования соответствующего класса.
/// Инструкция утверждена 25.12.2003, введена с 01.02.2004, обязательна для
/// всех организаций независимо от формы собственности.
///
/// ВАЖНО, ЧЕГО В ТАБЛ. 4 НЕТ: допуска на величину угла i. Там нормируется
/// только его температурный дрейф (0,5″ на 1 °С для I и II классов, 0,8″ для
/// III и IV). Поэтому вердикт «в допуске / вне допуска» по-прежнему опирается
/// на ГОСТ 10528-90, п. 2.3 — не более 10″.
///
/// Проверка идёт по совокупности требований: прибор допущен к классу, только
/// если проходит по КАЖДОМУ параметру. Это не «вычисление класса прибора»
/// (такого понятия нет — по п. 21.1 нивелиры классифицируются по точности на
/// высокоточные, точные и технические), а допуск к конкретному виду работ.
class LevelingClassRequirements {
  /// Класс нивелирования: 1..4.
  final int levelingClass;

  /// Инструментальная СКП измерения превышений на 1 км двойного хода,
  /// мм, не более.
  final double maxSkoMmKm;

  /// Увеличение зрительной трубы, крат, не менее.
  ///
  /// Для проверки берётся это число. Для показа пользователю есть
  /// [magnificationLabel]: у IV класса в табл. 4 стоит не одно значение,
  /// а диапазон «20-22», и подменять его одним числом в тексте нельзя.
  final int minMagnification;

  /// Как требование к увеличению записано в табл. 4.
  final String magnificationLabel;

  /// Диапазон работы компенсатора, угл. мин, не менее.
  final double minCompensatorRangeArcmin;

  /// Изменение угла i при изменении температуры на 1 °С, угл. сек, не более.
  final double maxTempDriftArcsec;

  const LevelingClassRequirements({
    required this.levelingClass,
    required this.maxSkoMmKm,
    required this.minMagnification,
    required this.magnificationLabel,
    required this.minCompensatorRangeArcmin,
    required this.maxTempDriftArcsec,
  });

  static const List<LevelingClassRequirements> table4 = [
    LevelingClassRequirements(
      levelingClass: 1,
      maxSkoMmKm: 0.5,
      minMagnification: 40,
      magnificationLabel: '40',
      minCompensatorRangeArcmin: 8,
      maxTempDriftArcsec: 0.5,
    ),
    LevelingClassRequirements(
      levelingClass: 2,
      maxSkoMmKm: 1.5,
      minMagnification: 40,
      magnificationLabel: '40',
      minCompensatorRangeArcmin: 8,
      maxTempDriftArcsec: 0.5,
    ),
    LevelingClassRequirements(
      levelingClass: 3,
      maxSkoMmKm: 3.0,
      minMagnification: 24,
      magnificationLabel: '24',
      minCompensatorRangeArcmin: 15,
      maxTempDriftArcsec: 0.8,
    ),
    LevelingClassRequirements(
      levelingClass: 4,
      maxSkoMmKm: 6.0,
      // Табл. 4 даёт для IV класса диапазон «20-22» крат. Для проверки
      // берём нижнюю границу как «не менее», а показываем диапазон.
      minMagnification: 20,
      magnificationLabel: '20-22',
      minCompensatorRangeArcmin: 15,
      maxTempDriftArcsec: 0.8,
    ),
  ];

  static LevelingClassRequirements byClass(int levelingClass) =>
      table4.firstWhere((r) => r.levelingClass == levelingClass);
}

/// Результат проверки допуска прибора к классу работ.
class LevelingClassCheck {
  final int levelingClass;
  final bool skoOk;
  final bool magnificationOk;

  /// null — увеличение прибора неизвестно, проверка не выполнялась.
  final bool? magnificationKnown;

  const LevelingClassCheck({
    required this.levelingClass,
    required this.skoOk,
    required this.magnificationOk,
    required this.magnificationKnown,
  });

  bool get admitted => skoOk && magnificationOk;
}

class LevelingClass {
  LevelingClass._();

  static LevelingClassCheck check({
    required int levelingClass,
    required double skoMmKm,
    int? magnification,
  }) {
    final req = LevelingClassRequirements.byClass(levelingClass);
    final magKnown = magnification != null;
    return LevelingClassCheck(
      levelingClass: levelingClass,
      skoOk: skoMmKm <= req.maxSkoMmKm,
      // Неизвестное увеличение не должно молча «проходить» проверку:
      // считаем непройденной и показываем это отдельно.
      magnificationOk: magKnown && magnification >= req.minMagnification,
      magnificationKnown: magKnown,
    );
  }

  /// Наивысший (наименьший по номеру) класс, к которому допущен прибор.
  /// null — не проходит даже по IV классу.
  static int? highestAdmittedClass({
    required double skoMmKm,
    int? magnification,
  }) {
    for (final req in LevelingClassRequirements.table4) {
      final result = check(
        levelingClass: req.levelingClass,
        skoMmKm: skoMmKm,
        magnification: magnification,
      );
      if (result.admitted) return req.levelingClass;
    }
    return null;
  }

  static String roman(int levelingClass) {
    switch (levelingClass) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      default:
        return '$levelingClass';
    }
  }
}

/// Периодичность полевой поверки.
///
/// Обязательного числа нет. СП 317.1325800.2017 (с Изменениями № 1, № 2),
/// пункт 4.12 требует проверок
/// перед началом и в процессе работ, но интервала не задаёт, а РЭ приборов
/// периодичность, как правило, не оговаривают вовсе. Интервал устанавливает
/// исполнитель своим СТО или программой работ; приложение даёт значения
/// ниже как ориентир по умолчанию и не переключает режимы само.
///
/// Справочно: ГКИНП 03-010-03, п. 21.4.2.
///
/// Дословно: для угла i нивелира — в начале работы каждый день в течение
/// недели, в дальнейшем, убедившись в постоянстве юстировки, — не реже
/// одного раза в пятнадцать дней.
class VerificationSchedule {
  VerificationSchedule._();

  /// Ежедневно в течение первой недели работы.
  static const int dailyDays = 7;

  /// Далее — не реже одного раза в 15 дней.
  static const int steadyIntervalDays = 15;

  static const String source =
      'по умолчанию; справочно — ГКИНП 03-010-03, п. 21.4.2';

  static const String description =
      'Ежедневно в начале работы первую неделю, далее — не реже одного раза '
      'в 15 дней (убедившись в постоянстве юстировки).';

  /// Установочный уровень нивелира — ежедневно перед началом наблюдений;
  /// круглые уровни на рейках — ежедневно. Это часть шага «Подготовка».
  static const String dailyChecks =
      'Установочный уровень нивелира и круглые уровни реек поверяют ежедневно '
      'перед началом наблюдений.';
}
