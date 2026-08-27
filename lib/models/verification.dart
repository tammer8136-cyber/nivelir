import '../services/nivelir/algorithms/collimation.dart';
import '../services/nivelir/algorithms/classification.dart';
import 'method_preset.dart';

/// Отсчёты одного приёма. В способе "вперёд" отсчёт по рейке в точке стояния
/// заменяется высотой визирной оси над точкой.
class VerificationRun {
  final int? id;
  final int runIndex;
  final int station1AMm;
  final int station1BMm;
  final int station2AMm;
  final int station2BMm;
  final double iArcsec;

  const VerificationRun({
    this.id,
    required this.runIndex,
    required this.station1AMm,
    required this.station1BMm,
    required this.station2AMm,
    required this.station2BMm,
    required this.iArcsec,
  });

  Map<String, dynamic> toMap(int verificationId) => {
        if (id != null) 'id': id,
        'verification_id': verificationId,
        'run_index': runIndex,
        'station1_a_mm': station1AMm,
        'station1_b_mm': station1BMm,
        'station2_a_mm': station2AMm,
        'station2_b_mm': station2BMm,
        'i_arcsec': iArcsec,
      };

  factory VerificationRun.fromMap(Map<String, dynamic> m) => VerificationRun(
        id: m['id'] as int?,
        runIndex: (m['run_index'] as num).toInt(),
        station1AMm: (m['station1_a_mm'] as num).toInt(),
        station1BMm: (m['station1_b_mm'] as num).toInt(),
        station2AMm: (m['station2_a_mm'] as num).toInt(),
        station2BMm: (m['station2_b_mm'] as num).toInt(),
        iArcsec: (m['i_arcsec'] as num).toDouble(),
      );
}

/// Запись поверки. Вычисленные величины хранятся посчитанными — дешевле для
/// истории и экспорта, чем пересчитывать при каждом открытии списка.
///
/// Допуск и его основание снимаются целиком: единого норматива нет, число
/// берётся из РЭ конкретной модели, а карточку модели могут поправить.
/// Протокол обязан остаться тем, чем был в день поверки.
///
/// `toleranceArcsecSnapshot` — снимок допуска на момент поверки, а не ссылка
/// на живую запись прибора: правка custom-прибора не должна задним числом
/// менять исторические вердикты.
class Verification {
  final int? id;
  final int deviceId;
  final String deviceLabel;
  final DateTime createdAt;

  final String methodPreset;
  final MethodGeometry geometry;
  final double distanceDiffM;

  final List<VerificationRun> runs;

  final double hTrueMm;
  final double iAngleArcsec;
  final double? spreadArcsec;
  final double spreadLimitArcsec;

  final double toleranceArcsecSnapshot;

  /// Снимок ОСНОВАНИЯ вердикта: `reMillimetres`, `reConverted` или
  /// `executor`. Без него число выше нечитаемо — 12,9" из РЭ RGK и 12,9",
  /// введённые исполнителем от руки, выглядят одинаково.
  final String toleranceBasisSnapshot;

  /// Снимок строки происхождения допуска целиком, как она пойдёт в протокол.
  /// Снимок, а не ссылка на карточку модели: карточку могут поправить, а
  /// протокол должен остаться тем, чем был в день поверки.
  final String toleranceProvenanceSnapshot;

  /// Снимок допуска в миллиметрах. Заполнен, когда вердикт вынесен
  /// сравнением в миллиметрах по РЭ. null — вердикт шёл в секундах.
  final double? toleranceMmSnapshot;

  /// Среднее расхождение (a2-b2)-(a1-b1) по приёмам, мм. Та величина,
  /// которую РЭ сравнивает со своим допуском.
  final double deltaMm;
  final String verdict;
  final bool anomalyFlagged;

  final bool adjusted;
  final double? farTheoreticalMm;

  /// Основание, по которому набиралось число приёмов (см. RunsNorm).
  final String runsNormId;

  /// Кто выполнял поверку. Свойство ПОВЕРКИ, а не прибора: один и тот же
  /// прибор в разные дни поверяют разные исполнители, и в протоколе должен
  /// стоять тот, кто её делал.
  final String? performedBy;

  /// Класс нивелирования, для которого выполнялась поверка (1..4).
  /// null — поверка «вообще», без привязки к классу работ.
  final int? levelingClass;

  final String? notes;

  const Verification({
    this.id,
    required this.deviceId,
    required this.deviceLabel,
    required this.createdAt,
    required this.methodPreset,
    required this.geometry,
    required this.distanceDiffM,
    required this.runs,
    required this.hTrueMm,
    required this.iAngleArcsec,
    required this.spreadArcsec,
    required this.spreadLimitArcsec,
    required this.toleranceArcsecSnapshot,
    required this.toleranceBasisSnapshot,
    required this.toleranceProvenanceSnapshot,
    required this.deltaMm,
    this.toleranceMmSnapshot,
    required this.verdict,
    required this.anomalyFlagged,
    this.adjusted = false,
    this.farTheoreticalMm,
    this.levelingClass,
    this.performedBy,
    this.runsNormId = RunsNorm.technologicalId,
    this.notes,
  });

  bool get isPass => verdict == 'pass';

  /// Вердикт вынесен сравнением в миллиметрах по РЭ, а не пересчётом
  /// в секунды.
  bool get comparedInMillimetres =>
      toleranceBasisSnapshot == 'reMillimetres' &&
      toleranceMmSnapshot != null;

  /// Допуск для протокола: в тех единицах, в которых он применён.
  String get toleranceLabel {
    final mm = toleranceMmSnapshot;
    if (comparedInMillimetres && mm != null) {
      final t = mm == mm.roundToDouble() ? mm.toStringAsFixed(0) : '$mm';
      return '$t мм по РЭ '
          '(${toleranceArcsecSnapshot.toStringAsFixed(1)}" на фактической '
          'разности плеч)';
    }
    return '${toleranceArcsecSnapshot.toStringAsFixed(1)}"';
  }

  /// На каком основании вынесен вердикт — одной строкой.
  String get toleranceBasisLabel {
    switch (toleranceBasisSnapshot) {
      case 'reMillimetres':
        return 'по РЭ прибора, сравнение в миллиметрах';
      case 'reConverted':
        return 'допуск РЭ, пересчитанный на методику исполнителя';
      case 'executor':
        return 'допуск задан исполнителем';
      default:
        return 'основание не сохранено (поверка до перехода на данные РЭ)';
    }
  }
  int get runCount => runs.length;

  /// Основание, которому удовлетворяет число приёмов. null — ни одно.
  RunsNorm? get runsNorm => RunsNorm.byIdOrNull(runsNormId);

  bool get meetsRunsNorm => runsNorm != null;
  MethodPreset get preset => MethodPreset.byId(methodPreset);

  bool get spreadExceeded =>
      spreadArcsec != null && spreadArcsec! > spreadLimitArcsec;

  factory Verification.fromResult({
    required int deviceId,
    required String deviceLabel,
    required String methodPreset,
    required CollimationResult result,
    required List<VerificationRun> runs,
    bool adjusted = false,
    int? levelingClass,
    String? performedBy,
    String runsNormId = RunsNorm.technologicalId,
    String? notes,
  }) {
    return Verification(
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      createdAt: DateTime.now(),
      methodPreset: methodPreset,
      geometry: result.geometry,
      distanceDiffM: result.distanceDiffM,
      runs: runs,
      hTrueMm: result.hTrueMm,
      iAngleArcsec: result.iArcsec,
      spreadArcsec: result.spreadArcsec,
      spreadLimitArcsec: result.spreadLimitArcsec,
      toleranceArcsecSnapshot: result.toleranceArcsec,
      toleranceBasisSnapshot: result.tolerance.basis.name,
      toleranceProvenanceSnapshot: result.tolerance.provenance,
      toleranceMmSnapshot: result.tolerance.toleranceMm,
      deltaMm: result.deltaMm,
      verdict: result.verdict,
      anomalyFlagged: result.anomalyFlagged,
      adjusted: adjusted,
      farTheoreticalMm: adjusted ? result.farTheoreticalMm : null,
      levelingClass: levelingClass,
      performedBy: performedBy,
      runsNormId: runsNormId,
      notes: notes,
    );
  }

  Verification copyWith({
    int? id,
    bool? adjusted,
    double? farTheoreticalMm,
    String? notes,
    List<VerificationRun>? runs,
  }) {
    return Verification(
      id: id ?? this.id,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      createdAt: createdAt,
      methodPreset: methodPreset,
      geometry: geometry,
      distanceDiffM: distanceDiffM,
      runs: runs ?? this.runs,
      hTrueMm: hTrueMm,
      iAngleArcsec: iAngleArcsec,
      spreadArcsec: spreadArcsec,
      spreadLimitArcsec: spreadLimitArcsec,
      toleranceArcsecSnapshot: toleranceArcsecSnapshot,
      toleranceBasisSnapshot: toleranceBasisSnapshot,
      toleranceProvenanceSnapshot: toleranceProvenanceSnapshot,
      toleranceMmSnapshot: toleranceMmSnapshot,
      deltaMm: deltaMm,
      verdict: verdict,
      anomalyFlagged: anomalyFlagged,
      adjusted: adjusted ?? this.adjusted,
      farTheoreticalMm: farTheoreticalMm ?? this.farTheoreticalMm,
      levelingClass: levelingClass,
      performedBy: performedBy,
      runsNormId: runsNormId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'device_id': deviceId,
        'device_label': deviceLabel,
        'created_at': createdAt.toIso8601String(),
        'method_preset': methodPreset,
        's1_a_m': geometry.station1ToA,
        's1_b_m': geometry.station1ToB,
        's2_a_m': geometry.station2ToA,
        's2_b_m': geometry.station2ToB,
        'distance_diff_m': distanceDiffM,
        'run_count': runs.length,
        'h_true_mm': hTrueMm,
        'i_angle_arcsec': iAngleArcsec,
        'spread_arcsec': spreadArcsec,
        'spread_limit_arcsec': spreadLimitArcsec,
        'tolerance_arcsec_snapshot': toleranceArcsecSnapshot,
        'tolerance_basis_snapshot': toleranceBasisSnapshot,
        'tolerance_provenance_snapshot': toleranceProvenanceSnapshot,
        'tolerance_mm_snapshot': toleranceMmSnapshot,
        'delta_mm': deltaMm,
        'verdict': verdict,
        'anomaly_flagged': anomalyFlagged ? 1 : 0,
        'adjusted': adjusted ? 1 : 0,
        'far_theoretical_mm': farTheoreticalMm,
        'leveling_class': levelingClass,
        'performed_by': performedBy,
        'runs_norm': runsNormId,
        'notes': notes,
      };

  factory Verification.fromMap(
    Map<String, dynamic> m, {
    List<VerificationRun> runs = const [],
  }) =>
      Verification(
        id: m['id'] as int?,
        deviceId: (m['device_id'] as num).toInt(),
        deviceLabel: (m['device_label'] as String?) ?? 'Прибор удалён',
        createdAt: DateTime.parse(m['created_at'] as String),
        methodPreset: m['method_preset'] as String,
        geometry: MethodGeometry(
          station1ToA: (m['s1_a_m'] as num).toDouble(),
          station1ToB: (m['s1_b_m'] as num).toDouble(),
          station2ToA: (m['s2_a_m'] as num).toDouble(),
          station2ToB: (m['s2_b_m'] as num).toDouble(),
        ),
        distanceDiffM: (m['distance_diff_m'] as num).toDouble(),
        runs: runs,
        hTrueMm: (m['h_true_mm'] as num).toDouble(),
        iAngleArcsec: (m['i_angle_arcsec'] as num).toDouble(),
        spreadArcsec: (m['spread_arcsec'] as num?)?.toDouble(),
        spreadLimitArcsec: (m['spread_limit_arcsec'] as num?)?.toDouble() ?? 5.0,
        toleranceArcsecSnapshot:
            (m['tolerance_arcsec_snapshot'] as num).toDouble(),
        // Поверки, записанные до схемы v8, основания не несут. Врать про
        // них нельзя: пишем прямо, что источник числа не сохранён.
        toleranceBasisSnapshot:
            (m['tolerance_basis_snapshot'] as String?) ?? 'legacy',
        toleranceProvenanceSnapshot:
            (m['tolerance_provenance_snapshot'] as String?) ??
                'Основание допуска не сохранено: поверка выполнена до '
                    'перехода на данные РЭ.',
        toleranceMmSnapshot:
            (m['tolerance_mm_snapshot'] as num?)?.toDouble(),
        deltaMm: (m['delta_mm'] as num?)?.toDouble() ?? 0,
        verdict: m['verdict'] as String,
        anomalyFlagged: (m['anomaly_flagged'] as int? ?? 0) == 1,
        adjusted: (m['adjusted'] as int? ?? 0) == 1,
        farTheoreticalMm: (m['far_theoretical_mm'] as num?)?.toDouble(),
        levelingClass: (m['leveling_class'] as num?)?.toInt(),
        performedBy: m['performed_by'] as String?,
        runsNormId:
            (m['runs_norm'] as String?) ?? RunsNorm.technologicalId,
        notes: m['notes'] as String?,
      );
}
