import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/method_preset.dart';
import '../models/verification.dart';
import '../services/database_service.dart';
import '../services/nivelir/algorithms/classification.dart';
import '../services/nivelir/algorithms/collimation.dart';
import '../services/nivelir/algorithms/leveling_class.dart';
import '../services/settings_service.dart';
import '../utils/units.dart';

enum WizardStep { preflight, params, station1, station2, result, adjustment }

/// Контроллеры одного приёма. Живут в WizardState, а не в виджетах шагов.
class RunControllers {
  final TextEditingController station1A = TextEditingController();
  final TextEditingController station1B = TextEditingController();
  final TextEditingController station2A = TextEditingController();
  final TextEditingController station2B = TextEditingController();

  void dispose() {
    station1A.dispose();
    station1B.dispose();
    station2A.dispose();
    station2B.dispose();
  }
}

/// ЕДИНЫЙ источник правды мастера.
///
/// ЖЁСТКОЕ ПРАВИЛО (нарушение = потеря введённых отсчётов при листании):
///   1. TextEditingController создаётся ТОЛЬКО здесь, никогда — внутри
///      State виджета шага. PageView уничтожает ушедшие за экран страницы
///      вместе с их локальным состоянием.
///   2. Виджет шага только читает контроллер через context.read<WizardState>().
///   3. TextFormField(initialValue:) ЗАПРЕЩЁН — только controller:.
class WizardState extends ChangeNotifier {
  WizardState({
    required this.db,
    required bool isMillimeters,
    required bool skipPreflight,
  })  : _isMillimeters = isMillimeters,
        _skipPreflight = skipPreflight {
    _steps = _buildSteps();
    pageController = PageController();
    _applyGeometryToControllers(_geometry);
    _syncRunControllers();
  }

  final DatabaseService db;

  bool _isMillimeters;
  bool get isMillimeters => _isMillimeters;

  final bool _skipPreflight;

  late final PageController pageController;
  late List<WizardStep> _steps;
  List<WizardStep> get steps => _steps;

  int _index = 0;
  int get index => _index;
  WizardStep get current => _steps[_index];
  bool get isFirst => _index == 0;

  // --- Приёмы ---
  /// Основание не выбирается — оно следует из числа приёмов.
  /// null — не выполнено ни одно (один приём).
  RunsNorm? get runsNorm => RunsNorm.strictestSatisfiedBy(_runCount);

  bool get meetsRunsNorm => runsNorm != null;

  /// Три приёма по умолчанию: ГКИНП (ГНТА) 17-195-99, п. 4.2.5 требует не
  /// менее трёх приёмов в любом способе. Один приём остаётся доступен как
  /// экспресс-проверка, но помечается в протоколе как не соответствующий
  /// нормативу.
  int _runCount = DeviceClassification.minRunsByNorm;
  int get runCount => _runCount;

  final List<RunControllers> _runs = [];
  List<RunControllers> get runs => _runs;

  // --- Геометрия (метры) ---
  final s1ACtrl = TextEditingController();
  final s1BCtrl = TextEditingController();
  final s2ACtrl = TextEditingController();
  final s2BCtrl = TextEditingController();

  final notesCtrl = TextEditingController();

  final paramsFormKey = GlobalKey<FormState>();
  final station1FormKey = GlobalKey<FormState>();
  final station2FormKey = GlobalKey<FormState>();

  Device? _device;
  Device? get device => _device;

  MethodPreset _preset = MethodPreset.all.first;
  MethodPreset get preset => _preset;

  MethodGeometry _geometry = MethodPreset.all.first.defaultGeometry;
  MethodGeometry get geometry => _geometry;

  /// Класс нивелирования, под который выполняется поверка (1..4).
  /// null — поверка без привязки к классу работ; это допустимо, вердикт по
  /// углу i от класса не зависит (табл. 4 угол i не нормирует вовсе).
  int? _levelingClass;
  int? get levelingClass => _levelingClass;

  /// Проверка прибора по табл. 4 ГКИНП 03-010-03. null — класс не выбран
  /// или прибор не выбран, проверять нечего.
  LevelingClassCheck? get levelingClassCheck {
    final cls = _levelingClass;
    final dev = _device;
    if (cls == null || dev == null) return null;
    return LevelingClass.check(
      levelingClass: cls,
      skoMmKm: dev.skoMmKm,
      magnification: dev.magnification,
    );
  }

  /// Наивысший класс, к которому прибор допущен по табл. 4. null — не
  /// проходит даже по IV классу.
  int? get highestAdmittedClass {
    final dev = _device;
    if (dev == null) return null;
    return LevelingClass.highestAdmittedClass(
      skoMmKm: dev.skoMmKm,
      magnification: dev.magnification,
    );
  }

  CollimationResult? _result;
  CollimationResult? get result => _result;

  bool _adjusted = false;
  bool get adjusted => _adjusted;

  int? _savedVerificationId;
  int? get savedVerificationId => _savedVerificationId;

  bool _dontShowPreflightAgain = false;
  bool get dontShowPreflightAgain => _dontShowPreflightAgain;

  List<WizardStep> _buildSteps() => [
        if (!_skipPreflight) WizardStep.preflight,
        WizardStep.params,
        WizardStep.station1,
        WizardStep.station2,
        WizardStep.result,
        WizardStep.adjustment,
      ];

  // ==========================================================================
  // ПАРАМЕТРЫ
  // ==========================================================================

  void setDevice(Device? device) {
    _device = device;
    notifyListeners();
  }

  void setLevelingClass(int? levelingClass) {
    _levelingClass = levelingClass;
    notifyListeners();
  }

  void setPreset(MethodPreset preset) {
    _preset = preset;
    _geometry = preset.defaultGeometry;
    _applyGeometryToControllers(_geometry);
    notifyListeners();
  }

  void setRunCount(int count) {
    if (count < 1 || count == _runCount) return;
    _runCount = count;
    _syncRunControllers();
    notifyListeners();
  }

  void _syncRunControllers() {
    while (_runs.length < _runCount) {
      _runs.add(RunControllers());
    }
    while (_runs.length > _runCount) {
      _runs.removeLast().dispose();
    }
  }

  void _applyGeometryToControllers(MethodGeometry g) {
    s1ACtrl.text = _trimNumber(g.station1ToA);
    s1BCtrl.text = _trimNumber(g.station1ToB);
    s2ACtrl.text = _trimNumber(g.station2ToA);
    s2BCtrl.text = _trimNumber(g.station2ToB);
  }

  static String _trimNumber(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Считывает плечи из полей. false, если геометрия вырождена: разности
  /// плеч на станциях совпали и знаменатель формулы обратился в ноль.
  bool pullGeometryFromControllers() {
    double? parse(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));

    final s1a = parse(s1ACtrl);
    final s1b = parse(s1BCtrl);
    final s2a = parse(s2ACtrl);
    final s2b = parse(s2BCtrl);
    if (s1a == null || s1b == null || s2a == null || s2b == null) return false;

    final g = MethodGeometry(
      station1ToA: s1a,
      station1ToB: s1b,
      station2ToA: s2a,
      station2ToB: s2b,
    );
    if (!g.isValid) return false;

    _geometry = g;
    return true;
  }

  void setDontShowPreflightAgain(bool value) {
    _dontShowPreflightAgain = value;
    notifyListeners();
  }

  /// Экраны станций дёргают это при вводе, чтобы обновить подсказку.
  void notifyReadingChanged() => notifyListeners();

  // ==========================================================================
  // ЕДИНИЦЫ
  // ==========================================================================

  /// Переключение мм/м на лету: значения пересчитываются, а не затираются.
  void syncUnits(bool isMillimeters) {
    if (_isMillimeters == isMillimeters) return;

    for (final run in _runs) {
      for (final ctrl in [
        run.station1A,
        run.station1B,
        run.station2A,
        run.station2B,
      ]) {
        final mm = Units.parseReading(ctrl.text, _isMillimeters);
        ctrl.text = mm == null ? '' : Units.formatForInput(mm, isMillimeters);
      }
    }

    _isMillimeters = isMillimeters;
    notifyListeners();
  }

  // ==========================================================================
  // РАСЧЁТ
  // ==========================================================================

  int? readingMm(TextEditingController ctrl) =>
      Units.parseReading(ctrl.text, _isMillimeters);

  bool get canCompute {
    if (_device == null || !_geometry.isValid) return false;
    for (final run in _runs) {
      if (readingMm(run.station1A) == null) return false;
      if (readingMm(run.station1B) == null) return false;
      if (readingMm(run.station2A) == null) return false;
      if (readingMm(run.station2B) == null) return false;
    }
    return true;
  }

  void compute() {
    if (!canCompute) return;

    final runResults = <RunResult>[];
    for (final run in _runs) {
      runResults.add(
        Collimation.computeRun(
          geometry: _geometry,
          station1AMm: readingMm(run.station1A)!,
          station1BMm: readingMm(run.station1B)!,
          station2AMm: readingMm(run.station2A)!,
          station2BMm: readingMm(run.station2B)!,
        ),
      );
    }

    _result = Collimation.summarize(
      runs: runResults,
      geometry: _geometry,
      toleranceArcsec: _device!.toleranceArcsec,
      runSpreadLimitArcsec: _device!.runSpreadLimitArcsec,
    );
    _adjusted = false;
    _savedVerificationId = null;
    notifyListeners();
  }

  void setAdjusted(bool value) {
    _adjusted = value;
    notifyListeners();
  }

  List<VerificationRun> _buildRunRecords() {
    final records = <VerificationRun>[];
    for (var i = 0; i < _runs.length; i++) {
      final run = _runs[i];
      records.add(
        VerificationRun(
          runIndex: i + 1,
          station1AMm: readingMm(run.station1A)!,
          station1BMm: readingMm(run.station1B)!,
          station2AMm: readingMm(run.station2A)!,
          station2BMm: readingMm(run.station2B)!,
          iArcsec: _result!.runs[i].iArcsec,
        ),
      );
    }
    return records;
  }

  /// Сохраняет протокол. Повторный вызов обновляет уже созданную запись —
  /// чтобы отметка "юстировка выполнена" не плодила дубли.
  Future<Verification?> save() async {
    if (_result == null || _device == null) return null;

    var verification = Verification.fromResult(
      deviceId: _device!.id!,
      deviceLabel: _device!.displayName,
      methodPreset: _preset.id,
      result: _result!,
      runs: _buildRunRecords(),
      adjusted: _adjusted,
      levelingClass: _levelingClass,
      runsNormId: RunsNorm.idForRunCount(_runCount),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );

    if (_savedVerificationId != null) {
      verification = verification.copyWith(id: _savedVerificationId);
      await db.updateVerification(verification);
    } else {
      final id = await db.insertVerification(verification);
      _savedVerificationId = id;
      verification = verification.copyWith(id: id);
    }

    await SettingsService.saveLastDeviceId(_device!.id!);
    await SettingsService.saveLastPreset(_preset.id);

    notifyListeners();
    return verification;
  }

  // ==========================================================================
  // НАВИГАЦИЯ
  // ==========================================================================

  void goTo(WizardStep step) {
    final target = _steps.indexOf(step);
    if (target < 0) return;
    _animateTo(target);
  }

  void nextStep() {
    if (_index >= _steps.length - 1) return;
    _animateTo(_index + 1);
  }

  /// false — отступать некуда, мастер надо закрыть.
  bool previousStep() {
    if (_index == 0) return false;
    _animateTo(_index - 1);
    return true;
  }

  void _animateTo(int target) {
    _index = target;
    pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final run in _runs) {
      run.dispose();
    }
    notesCtrl.dispose();
    s1ACtrl.dispose();
    s1BCtrl.dispose();
    s2ACtrl.dispose();
    s2BCtrl.dispose();
    super.dispose();
  }
}
