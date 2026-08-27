import '../../models/field_check_spec.dart';

/// На каком основании вынесен вердикт.
///
/// Единой нормы на полевое определение угла i нет, поэтому основание —
/// не константа, а свойство конкретной поверки: оно зависит от того, что
/// написано в РЭ прибора и как исполнитель поставил прибор в поле.
enum ToleranceBasis {
  /// Допуск в миллиметрах прямо из РЭ, и расстановка попала в геометрию,
  /// для которой РЭ этот допуск назначил. Сравнение идёт в миллиметрах —
  /// ровно так, как написано у производителя, без пересчётов.
  reMillimetres,

  /// Допуск из РЭ, но расстановка своя. Миллиметры производителя намерены
  /// на его геометрии, поэтому переносятся в секунды по строгому краю
  /// разрешённой РЭ разности плеч и дальше применяются к фактической.
  reConverted,

  /// Число задал исполнитель: РЭ на модель нет, либо в РЭ допуска нет
  /// (Topcon AT-B, Sokkia B, ADA пишут «юстируйте, пока разность не станет
  /// малой»), либо в РЭ нет базы и пересчитывать не на чем.
  executor,
}

/// Допуск, фактически применённый в поверке, вместе с его происхождением.
///
/// Смысл класса в том, что число и его основание нельзя разлучать: 3 мм
/// у RGK и 3 мм у УОМЗ дают 12,9" и 6,9", потому что намерены на разной
/// разности плеч. В протокол идёт [provenance] целиком.
class AppliedTolerance {
  final ToleranceBasis basis;

  /// Допуск в миллиметрах. Заполнен только при [ToleranceBasis.reMillimetres].
  final double? toleranceMm;

  /// Допуск в секундах. Заполнен всегда — в режиме миллиметров считается
  /// от фактической разности плеч и служит для печати, не для вердикта.
  final double toleranceArcsec;

  /// Фактическая разность плеч поверки, м.
  final double actualDeltaLM;

  /// Строка происхождения для протокола.
  final String provenance;

  /// Попала ли расстановка в геометрию РЭ.
  /// null — в РЭ нет базы, проверять не на чем.
  final bool? geometryWithinRe;

  const AppliedTolerance({
    required this.basis,
    required this.toleranceArcsec,
    required this.actualDeltaLM,
    required this.provenance,
    this.toleranceMm,
    this.geometryWithinRe,
  });

  bool get comparesInMillimetres => basis == ToleranceBasis.reMillimetres;

  /// Вердикт. [deltaMm] — среднее расхождение (a2-b2)-(a1-b1) по приёмам,
  /// [iArcsec] — средний угол i.
  ///
  /// В режиме миллиметров сравнивается ровно то, что сравнивает РЭ, и
  /// пересчёт в вердикт не входит вовсе.
  bool passes({required double deltaMm, required double iArcsec}) =>
      comparesInMillimetres && toleranceMm != null
          ? deltaMm.abs() <= toleranceMm!
          : iArcsec.abs() <= toleranceArcsec;

  /// Основание вердикта одной строкой — для шапки протокола.
  String get basisLabel {
    switch (basis) {
      case ToleranceBasis.reMillimetres:
        return 'по РЭ прибора, сравнение в миллиметрах';
      case ToleranceBasis.reConverted:
        return 'допуск РЭ, пересчитанный на методику исполнителя';
      case ToleranceBasis.executor:
        return 'допуск задан исполнителем';
    }
  }

  /// Собирает применённый допуск из карточки модели и фактической геометрии.
  ///
  /// [spec] — данные РЭ, null если их нет.
  /// [executorArcsec] — число, введённое исполнителем; используется, когда
  /// РЭ не даёт ни допуска, ни возможности его пересчитать.
  static AppliedTolerance resolve({
    required FieldCheckSpec? spec,
    required double actualDeltaLM,
    required double? actualBaseM,
    required double? actualOffsetM,
    required double? executorArcsec,
  }) {
    final within = (spec != null && actualBaseM != null)
        ? spec.geometryWithinRe(baseM: actualBaseM, offsetM: actualOffsetM)
        : null;

    // 1. РЭ даёт число, и мы стоим там, где РЭ велит. Сравниваем в мм.
    if (spec != null && spec.hasTolerance && within == true) {
      return AppliedTolerance(
        basis: ToleranceBasis.reMillimetres,
        toleranceMm: spec.toleranceMm,
        toleranceArcsec:
            FieldCheckSpec.arcsecFromMm(spec.toleranceMm!, actualDeltaLM),
        actualDeltaLM: actualDeltaLM,
        geometryWithinRe: true,
        provenance: 'Вердикт в миллиметрах по РЭ. ${spec.provenanceLine}. '
            'Фактическая разность плеч ${_m(actualDeltaLM)} м.',
      );
    }

    // 2. РЭ даёт число, но расстановка своя либо в РЭ нет базы. Переносим
    //    в секунды по строгому краю и говорим, откуда взялся пересчёт.
    final converted = spec?.toleranceArcsecStrict;
    if (spec != null && converted != null) {
      final why = within == false
          ? 'расстановка вне геометрии РЭ'
          : 'геометрию РЭ проверить не по чему: база в РЭ не указана';
      return AppliedTolerance(
        basis: ToleranceBasis.reConverted,
        toleranceArcsec: converted,
        actualDeltaLM: actualDeltaLM,
        geometryWithinRe: within,
        provenance: 'Вердикт в секундах: $why. ${spec.provenanceLine}. '
            'Фактическая разность плеч ${_m(actualDeltaLM)} м.',
      );
    }

    // 3. Числа нет. Его обязан задать исполнитель, и протокол это печатает.
    final tol = executorArcsec ?? 0;
    final missing = spec == null
        ? 'данных РЭ на модель нет'
        : (spec.hasTolerance
            ? 'в РЭ нет базы, пересчитать допуск не на чем'
            : 'в РЭ прибора допуск не указан');
    return AppliedTolerance(
      basis: ToleranceBasis.executor,
      toleranceArcsec: tol,
      actualDeltaLM: actualDeltaLM,
      geometryWithinRe: within,
      provenance: 'Допуск ${tol.toStringAsFixed(1)}" задан исполнителем: '
          '$missing.${spec != null ? ' Схема: ${spec.schemeLabel}; '
              'источник схемы: ${spec.source}.' : ''} '
          'Фактическая разность плеч ${_m(actualDeltaLM)} м.',
    );
  }

  static String _m(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
