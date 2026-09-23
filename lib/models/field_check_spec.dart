/// Схема и допуск полевой поверки угла i, взятые из РЭ конкретной модели.
///
/// Почему это отдельный объект, а не пара полей в [DeviceModel]:
/// допуск в РЭ задан в МИЛЛИМЕТРАХ и осмыслен только вместе со схемой,
/// на которой он намерен. Оторвать число от геометрии нельзя — те же 3 мм
/// на разной разности плеч дают угол от 6,9″ до 23,8″.
///
/// Единой нормы на полевое определение угла i не существует. 10″ по
/// ГОСТ 10528-90 п. 2.3 — лабораторная характеристика прибора (коллиматор,
/// метрологическая служба), в полевом вердикте не участвует.
///
/// РЭ бывают трёх степеней полноты, и все три надо уметь хранить:
///   * схема + база + допуск — RGK, Vega, Bosch, Leica, Nikon, УОМЗ;
///   * схема + база, допуска нет — Topcon AT-B («повторяйте, пока разность
///     не станет малой»);
///   * только схема, ни базы, ни допуска — Sokkia B, ADA Ruber.
/// Пустое поле значит «в РЭ этого нет», и протокол обязан это сказать.
/// Заполнять его по прибору-близнецу нельзя: Sokkia B и Topcon AT-B
/// совпадают дословно вплоть до нумерации разделов, но базу называет
/// только Topcon.
///
/// Проверено по 30 РЭ и паспортам, 25.08.2026. Ни один РЭ не задаёт полевой
/// допуск в угловых секундах.
enum FieldCheckScheme {
  /// Станция 1 — посередине между рейками A и B.
  /// Станция 2 — ВНУТРИ отрезка, в [offsetMinM]..[offsetMaxM] от ближней рейки.
  /// Разность плеч ΔL = база − 2·offset.
  ///
  /// Геометрия сверена по рисункам РЭ RGK C (рис. 10), RGK N (рис. 9),
  /// GEOBOX N7 и Sokkia B (рис. 7.6): прибор стоит между рейками, не за
  /// ближней.
  midThenNear,

  /// Станция 1 — посередине. Станция 2 — ЗА передней рейкой, в
  /// [offsetMinM]..[offsetMaxM] от неё. Ближнее плечо offset, дальнее
  /// база + offset, поэтому ΔL = база и от offset не зависит.
  ///
  /// Паспорта УОМЗ, п. 9.2.6.
  midThenBeyond,

  /// Отрезок делится на ТРИ равные части d. Рейки A и B в точках 1/3 и 2/3,
  /// станции — на обоих концах. Посередине не стоят вообще.
  ///
  /// На станции 1 плечи d и 2d, на станции 2 — 2d и d, поэтому угол входит
  /// в оба результата с противоположным знаком и расхождение выходит
  /// удвоенным: ΔL = 2d = 2/3 общей длины.
  ///
  /// РЭ Leica NA2/NAK2, «Checking and adjusting of the line-of-sight».
  /// Контроль: A2ном = A1 − B1 + B2.
  thirdsSymmetric,
}

class FieldCheckSpec {
  final FieldCheckScheme scheme;

  /// Расстояние между рейками A и B, разрешённое РЭ.
  /// null — РЭ базу не называет (Sokkia B, ADA Ruber).
  final double? baseMinM;
  final double? baseMaxM;

  /// Вынос смещённой станции от рейки.
  /// null — РЭ его не оцифровывает (GeoMax ZAL300: руководство целиком
  /// в пиктограммах, схема нарисована, но ни база, ни вынос не подписаны)
  /// либо схема выноса не использует (thirdsSymmetric).
  final double? offsetMinM;
  final double? offsetMaxM;

  /// Допуск на |(a2−b2)−(a1−b1)|, мм, как записан в РЭ.
  /// null — РЭ числа не даёт; допуск задаёт исполнитель.
  final double? toleranceMm;

  /// Разность плеч на краях разрешённой геометрии.
  /// strict — максимальная ΔL (даёт наименьший, самый жёсткий угол),
  /// soft   — минимальная ΔL. null, если базы в РЭ нет.
  final double? deltaLStrictM;
  final double? deltaLSoftM;

  /// Пункт РЭ, откуда взята схема. Печатается в протоколе.
  final String source;

  const FieldCheckSpec({
    required this.scheme,
    this.baseMinM,
    this.baseMaxM,
    this.offsetMinM,
    this.offsetMaxM,
    this.toleranceMm,
    this.deltaLStrictM,
    this.deltaLSoftM,
    required this.source,
  });

  static const double arcsecPerRadian = 206265.0;

  /// i″ = 206265 · Δ[мм] / ΔL[мм].
  ///
  /// Та же формула, что и для самого угла: отсчёт по рейке равен истинному
  /// плюс i·d, поэтому на станции с равными плечами ошибка сокращается,
  /// а на смещённой остаётся i·ΔL.
  static double arcsecFromMm(double mm, double deltaLM) {
    if (deltaLM <= 0) return double.nan;
    return arcsecPerRadian * mm / (deltaLM * 1000.0);
  }

  static double mmFromArcsec(double arcsec, double deltaLM) =>
      arcsec * deltaLM * 1000.0 / arcsecPerRadian;

  /// РЭ даёт число — вердикт можно вести в миллиметрах по РЭ.
  bool get hasTolerance => toleranceMm != null;

  /// РЭ называет базу — можно проверить, попадает ли фактическая
  /// расстановка в разрешённую геометрию.
  bool get hasBase => baseMinM != null && baseMaxM != null;

  bool get hasOffset => offsetMinM != null && offsetMaxM != null;

  /// Допуск, пересчитанный по строгому краю разрешённой РЭ геометрии.
  /// Это то число, с которым сравнивается результат в режиме произвольных
  /// плеч. Выбор края — решение исполнителя, а не производителя: РЭ задаёт
  /// базу диапазоном и вилку допуска не оговаривает.
  ///
  /// null, если РЭ не даёт допуска либо не даёт базы: пересчитывать нечего
  /// или не на чем.
  double? get toleranceArcsecStrict =>
      (toleranceMm != null && deltaLStrictM != null)
          ? arcsecFromMm(toleranceMm!, deltaLStrictM!)
          : null;

  /// Мягкий край вилки. В вердикте не участвует, печатается в протоколе,
  /// чтобы вилка была видна.
  double? get toleranceArcsecSoft =>
      (toleranceMm != null && deltaLSoftM != null)
          ? arcsecFromMm(toleranceMm!, deltaLSoftM!)
          : null;

  bool get hasRange =>
      deltaLSoftM != null &&
      deltaLStrictM != null &&
      deltaLSoftM != deltaLStrictM;

  /// Разность плеч для фактической геометрии.
  double deltaLFor({required double baseM, double offsetM = 0}) {
    switch (scheme) {
      case FieldCheckScheme.midThenNear:
        return baseM - 2 * offsetM;
      case FieldCheckScheme.midThenBeyond:
        return baseM;
      case FieldCheckScheme.thirdsSymmetric:
        // baseM здесь — полная длина отрезка (3d), а не расстояние A-B.
        return 2 * baseM / 3;
    }
  }

  /// Попадает ли фактическая расстановка в геометрию, для которой РЭ
  /// назначил свой допуск в миллиметрах.
  ///
  /// Если РЭ базы не называет — проверять нечего, возвращается null:
  /// это не «да» и не «нет», а «в РЭ нет данных для проверки».
  bool? geometryWithinRe({
    required double baseM,
    double? offsetM,
    double? actualDeltaLM,
  }) {
    if (!hasBase) return null;
    if (baseM < baseMinM! || baseM > baseMaxM!) return false;
    if (hasOffset && offsetM != null) {
      if (offsetM < offsetMinM! || offsetM > offsetMaxM!) return false;
    }

    // База и вынос в диапазоне — но это ещё не значит, что расстановка та.
    // У схемы «за передней рейкой» (УОМЗ, база 80-90, вынос 2-4) плечи
    // 45/45 и 2/88 дают базу 90 и вынос 2, оба в диапазоне, — а станция
    // при этом стоит ВНУТРИ отрезка, то есть по чужой схеме. Разность
    // плеч выходит 86 м вместо 90, и те же 3 мм означают уже 7,2", а не
    // 6,9".
    //
    // Сравнивать с диапазоном ΔL бесполезно: 86 м законны для базы 86.
    // Сравнивать надо с тем, что схема РЭ дала бы ПРИ ЭТИХ ЖЕ базе и
    // выносе — тогда подмена схемы видна сразу.
    if (actualDeltaLM != null) {
      final expected =
          deltaLFor(baseM: baseM, offsetM: offsetM ?? offsetMinM ?? 0).abs();
      if (expected > 0) {
        // Допуск на округление плеч в поле — 2 %.
        if ((actualDeltaLM.abs() - expected).abs() / expected > 0.02) {
          return false;
        }
      }
    }
    return true;
  }

  String get schemeLabel {
    final off = hasOffset ? '${_range(offsetMinM!, offsetMaxM!)} м' : null;
    switch (scheme) {
      case FieldCheckScheme.midThenNear:
        return off == null
            ? 'станция 1 посередине, станция 2 вплотную к ближней рейке '
                '(вынос в РЭ не указан)'
            : 'станция 1 посередине, станция 2 в $off от ближней рейки';
      case FieldCheckScheme.midThenBeyond:
        return off == null
            ? 'станция 1 посередине, станция 2 за передней рейкой '
                '(вынос в РЭ не указан)'
            : 'станция 1 посередине, станция 2 в $off за передней рейкой';
      case FieldCheckScheme.thirdsSymmetric:
        return 'отрезок делится на три равные части, рейки в точках 1/3 и 2/3, '
            'станции на концах';
    }
  }

  String get baseLabel {
    final word = scheme == FieldCheckScheme.thirdsSymmetric
        ? 'общая длина'
        : 'база';
    return hasBase
        ? '$word ${_range(baseMinM!, baseMaxM!)} м'
        : '$word в РЭ не указана';
  }

  /// Строка провенанса для протокола: что взято из РЭ, чего в РЭ нет
  /// и на какой геометрии посчитан пересчёт.
  ///
  /// Пропуски называются вслух. «Допуск не указан в РЭ» — такой же
  /// результат чтения документа, как и число, и скрывать его нельзя:
  /// иначе непонятно, откуда взялось значение, по которому вынесен вердикт.
  String get provenanceLine {
    final b = StringBuffer();

    if (toleranceMm == null) {
      b.write('допуск в РЭ не указан, значение задано исполнителем; ');
    } else {
      b.write('допуск ${_num(toleranceMm!)} мм; ');
    }

    b.write('$baseLabel, $schemeLabel');

    final strict = toleranceArcsecStrict;
    if (strict != null) {
      b.write('; ΔL ${_num(deltaLStrictM!)} м → ${strict.toStringAsFixed(1)}″');
      final soft = toleranceArcsecSoft;
      if (hasRange && soft != null) {
        b.write(' (вилка по РЭ ${strict.toStringAsFixed(1)}–'
            '${soft.toStringAsFixed(1)}″, взят строгий край)');
      }
    }

    b.write('; источник: $source');
    return b.toString();
  }

  static String _range(double a, double b) =>
      a == b ? _num(a) : '${_num(a)}–${_num(b)}';

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Map<String, dynamic> toMap() => {
        'field_check_scheme': scheme.name,
        'field_check_base_min_m': baseMinM,
        'field_check_base_max_m': baseMaxM,
        'field_check_offset_min_m': offsetMinM,
        'field_check_offset_max_m': offsetMaxM,
        'field_check_tolerance_mm': toleranceMm,
        'field_check_delta_l_strict_m': deltaLStrictM,
        'field_check_delta_l_soft_m': deltaLSoftM,
        'field_check_source': source,
      };

  /// Возвращает null только когда у модели нет САМОЙ схемы: РЭ нет либо
  /// полевой методики в нём нет. Отсутствие допуска схему не отменяет —
  /// расстановка из РЭ остаётся полезной, а число вводит исполнитель.
  static FieldCheckSpec? fromMap(Map<String, dynamic> m) {
    final source = m['field_check_source'] as String?;
    final schemeName = m['field_check_scheme'] as String?;
    if (source == null || schemeName == null) return null;

    // Терпим оба написания. toMap() пишет scheme.name, то есть midThenNear,
    // но в ассете каталога схемы записаны как mid_then_near. Сравнение
    // строк напрямую отключало данные РЭ у всех карточек разом.
    final wanted = schemeName.replaceAll('_', '').toLowerCase();
    FieldCheckScheme? scheme;
    for (final s in FieldCheckScheme.values) {
      if (s.name.toLowerCase() == wanted) scheme = s;
    }
    if (scheme == null) return null;

    return FieldCheckSpec(
      scheme: scheme,
      baseMinM: (m['field_check_base_min_m'] as num?)?.toDouble(),
      baseMaxM: (m['field_check_base_max_m'] as num?)?.toDouble(),
      offsetMinM: (m['field_check_offset_min_m'] as num?)?.toDouble(),
      offsetMaxM: (m['field_check_offset_max_m'] as num?)?.toDouble(),
      toleranceMm: (m['field_check_tolerance_mm'] as num?)?.toDouble(),
      deltaLStrictM: (m['field_check_delta_l_strict_m'] as num?)?.toDouble(),
      deltaLSoftM: (m['field_check_delta_l_soft_m'] as num?)?.toDouble(),
      source: source,
    );
  }
}
