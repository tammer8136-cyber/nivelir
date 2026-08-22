import '../../../models/method_preset.dart';
import 'classification.dart';

/// Расчётное ядро: определение угла i (коллимационной ошибки) нивелира.
///
/// СОГЛАШЕНИЕ О ЗНАКАХ (действует во всём приложении):
///
///   h = отсчёт_по_рейке_A - отсчёт_по_рейке_B
///
/// Рейки A и B — неподвижные точки местности; какая из них ближе, зависит от
/// станции и роли не играет.
///
/// Вывод. Наклон визирной оси на угол i (рад) завышает отсчёт по рейке на
/// расстоянии s на величину i*s, поэтому на станции с плечами s_A, s_B:
///
///   h_изм = h_ист + i * (s_A - s_B)
///
/// Для двух станций с разностями плеч D1 и D2:
///
///   i = (h2 - h1) / (D2 - D1)
///
/// Частные случаи:
///   рабочий метод (50/50, 25/75):  D1 = 0,   D2 = -50  -> знаменатель -50 м
///   разные плечи (4/54, 54/4):     D1 = -50, D2 = +50  -> знаменатель 100 м
///   вперёд (0/50, 50/0):           D1 = -50, D2 = +50  -> знаменатель 100 м
///
/// Проверено на числовом примере ГКИНП (ГНТА) 17-195-99, приложение 4
/// (способ 3): X = +4,9 деления
/// инварной рейки (0,5 мм) = 2,45 мм при s = 50 м даёт i = +10,1", что
/// совпадает с приведённым в инструкции значением.
///
/// Все отсчёты — в МИЛЛИМЕТРАХ (целые). Расстояния — в МЕТРАХ.
class Collimation {
  Collimation._();

  /// Градусная мера радиана, ГКИНП: 206265".
  static const double radToArcsec = 206265.0;

  /// Порог мягкого предупреждения — десятикратный допуск ГОСТ.
  static const double anomalyArcsec = 100.0;

  /// Расчёт одного приёма.
  static RunResult computeRun({
    required MethodGeometry geometry,
    required int station1AMm,
    required int station1BMm,
    required int station2AMm,
    required int station2BMm,
  }) {
    final int h1Mm = station1AMm - station1BMm;
    final int h2Mm = station2AMm - station2BMm;
    final int xMm = h2Mm - h1Mm;

    final double denominatorM = geometry.distanceDiffM;

    // мм / м -> радианы: делим на 1000.
    final double iRad = (xMm / denominatorM) / 1000.0;
    final double iArcsec = iRad * radToArcsec;

    // Истинное превышение: снимаем с h1 ошибку её собственных плеч.
    final double hTrueMm = h1Mm - iRad * 1000.0 * geometry.station1DiffM;

    // Целевой отсчёт по ДАЛЬНЕЙ рейке станции 2 для юстировки сетки нитей.
    //
    // Поворот сетки нитей на -i меняет отсчёт по рейке на расстоянии s на
    // -i*s, поэтому целевое значение считается от СОБСТВЕННОГО наблюдённого
    // отсчёта дальней рейки: far_цель = far_набл - i*s_far.
    //
    // Выводить цель через ближнюю рейку (far = near -+ h_ист) нельзя: отсчёт
    // по ближней рейке сам содержит ошибку i*s_near, и она целиком уходит в
    // результат. При плече 25 м и i = 10" это 1,2 мм. Ноль эта разница даёт
    // только в способе "вперёд", где ближнее плечо равно нулю.
    final double farDistanceM = geometry.farRodAtStation2IsA
        ? geometry.station2ToA
        : geometry.station2ToB;
    final int farObservedMm =
        geometry.farRodAtStation2IsA ? station2AMm : station2BMm;
    final double farTheoreticalMm =
        farObservedMm - iRad * 1000.0 * farDistanceM;

    return RunResult(
      h1Mm: h1Mm,
      h2Mm: h2Mm,
      xMm: xMm,
      hTrueMm: hTrueMm,
      iArcsec: iArcsec,
      farTheoreticalMm: farTheoreticalMm,
    );
  }

  /// Свод по приёмам. При одном приёме размах не определён.
  ///
  /// ГКИНП (ГНТА) 17-195-99, п. 4.2.5: количество приёмов в любом способе —
  /// не менее трёх, за окончательное значение угла i принимают среднее.
  /// Размах отдельных значений (предел 3"/5" по ГКИНП 03-010-03, прил. 9)
  /// показывается справочно и на вердикт не влияет — вердикт даёт порог
  /// 10" (ГОСТ 10528-90 п. 2.3, ГКИНП 17-195-99 п. 4.2.5).
  static CollimationResult summarize({
    required List<RunResult> runs,
    required MethodGeometry geometry,
    required double toleranceArcsec,
    required double runSpreadLimitArcsec,
  }) {
    final n = runs.length;
    final iMean = runs.map((r) => r.iArcsec).reduce((a, b) => a + b) / n;
    final hMean = runs.map((r) => r.hTrueMm).reduce((a, b) => a + b) / n;
    final farMean =
        runs.map((r) => r.farTheoreticalMm).reduce((a, b) => a + b) / n;

    double? spread;
    if (n > 1) {
      final values = runs.map((r) => r.iArcsec).toList()..sort();
      spread = values.last - values.first;
    }

    return CollimationResult(
      runs: runs,
      geometry: geometry,
      iArcsec: iMean,
      hTrueMm: hMean,
      farTheoreticalMm: farMean,
      spreadArcsec: spread,
      spreadLimitArcsec: runSpreadLimitArcsec,
      toleranceArcsec: toleranceArcsec,
      anomalyFlagged: iMean.abs() > anomalyArcsec,
    );
  }
}

/// Результат одного приёма.
class RunResult {
  final int h1Mm;
  final int h2Mm;
  final int xMm;
  final double hTrueMm;
  final double iArcsec;
  final double farTheoreticalMm;

  const RunResult({
    required this.h1Mm,
    required this.h2Mm,
    required this.xMm,
    required this.hTrueMm,
    required this.iArcsec,
    required this.farTheoreticalMm,
  });
}

class CollimationResult {
  final List<RunResult> runs;
  final MethodGeometry geometry;

  /// Среднее по приёмам, угловые секунды (знак сохраняется).
  final double iArcsec;

  /// Среднее истинное превышение A-B, мм.
  final double hTrueMm;

  /// Целевой отсчёт по дальней рейке станции 2, мм.
  final double farTheoreticalMm;

  /// Размах значений угла i по приёмам, секунды. null при одном приёме.
  final double? spreadArcsec;

  /// Предел размаха по ГКИНП (3"/5") — справочно.
  final double spreadLimitArcsec;

  /// Допуск ГОСТ 10528-90, п. 2.3.
  final double toleranceArcsec;

  final bool anomalyFlagged;

  const CollimationResult({
    required this.runs,
    required this.geometry,
    required this.iArcsec,
    required this.hTrueMm,
    required this.farTheoreticalMm,
    required this.spreadArcsec,
    required this.spreadLimitArcsec,
    required this.toleranceArcsec,
    required this.anomalyFlagged,
  });

  int get runCount => runs.length;

  /// Основание, которому удовлетворяет число приёмов. null — ни одно.
  /// Три приёма проходят по 17-195-99, два — по приложению 9 к 03-010-03,
  /// один — ни по одному.
  RunsNorm? get runsNorm => RunsNorm.strictestSatisfiedBy(runs.length);

  bool get runCountMeetsNorm => runsNorm != null;

  bool get withinTolerance => iArcsec.abs() <= toleranceArcsec;

  String get verdict => withinTolerance ? 'pass' : 'fail';

  /// Размах вышел за предел ГКИНП — повод переизмерить, но не брак.
  bool get spreadExceeded =>
      spreadArcsec != null && spreadArcsec! > spreadLimitArcsec;

  /// Наклон визирной оси в мм на 100 м — нагляднее секунд.
  double get mmPer100m => iArcsec / Collimation.radToArcsec * 100000.0;

  double get distanceDiffM => geometry.distanceDiffM;
}
