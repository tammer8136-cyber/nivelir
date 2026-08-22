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
  final String verdict;
  final bool anomalyFlagged;

  final bool adjusted;
  final double? farTheoreticalMm;

  /// Основание, по которому набиралось число приёмов (см. RunsNorm).
  final String runsNormId;

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
    required this.verdict,
    required this.anomalyFlagged,
    this.adjusted = false,
    this.farTheoreticalMm,
    this.levelingClass,
    this.runsNormId = RunsNorm.technologicalId,
    this.notes,
  });

  bool get isPass => verdict == 'pass';
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
      verdict: result.verdict,
      anomalyFlagged: result.anomalyFlagged,
      adjusted: adjusted,
      farTheoreticalMm: adjusted ? result.farTheoreticalMm : null,
      levelingClass: levelingClass,
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
      verdict: verdict,
      anomalyFlagged: anomalyFlagged,
      adjusted: adjusted ?? this.adjusted,
      farTheoreticalMm: farTheoreticalMm ?? this.farTheoreticalMm,
      levelingClass: levelingClass,
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
        'verdict': verdict,
        'anomaly_flagged': anomalyFlagged ? 1 : 0,
        'adjusted': adjusted ? 1 : 0,
        'far_theoretical_mm': farTheoreticalMm,
        'leveling_class': levelingClass,
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
        verdict: m['verdict'] as String,
        anomalyFlagged: (m['anomaly_flagged'] as int? ?? 0) == 1,
        adjusted: (m['adjusted'] as int? ?? 0) == 1,
        farTheoreticalMm: (m['far_theoretical_mm'] as num?)?.toDouble(),
        levelingClass: (m['leveling_class'] as num?)?.toInt(),
        runsNormId:
            (m['runs_norm'] as String?) ?? RunsNorm.technologicalId,
        notes: m['notes'] as String?,
      );
}
