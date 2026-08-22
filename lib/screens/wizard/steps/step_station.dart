import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_settings.dart';
import '../../../state/wizard_state.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/units.dart';

/// Ввод отсчётов на станции — один экран на обе станции.
///
/// Контроллеры полей живут в WizardState (см. правило там); виджет только
/// читает их, поэтому листание страниц не стирает введённое.
class StepStation extends StatelessWidget {
  final int station;
  const StepStation({super.key, required this.station});

  bool get _isFirst => station == 1;

  /// «дважды» читается лучше, чем «2 раза», а дальше склонение уже не нужно:
  /// приёмов максимум три.
  static String _timesLabel(int times) {
    switch (times) {
      case 1:
        return 'один раз';
      case 2:
        return 'дважды';
      default:
        return '$times раза';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<WizardState>();
    final isMm = context.select<AppSettings, bool>((s) => s.isMillimeters);
    final g = wizard.geometry;

    final toA = _isFirst ? g.station1ToA : g.station2ToA;
    final toB = _isFirst ? g.station1ToB : g.station2ToB;
    final formKey = _isFirst ? wizard.station1FormKey : wizard.station2FormKey;
    final equalArms = (toA - toB).abs() < 0.001;
    final usesHeight = wizard.preset.usesInstrumentHeight;

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Станция $station',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  equalArms
                      ? 'До обеих реек — ${Units.meters(toA)}, плечи равны.'
                      : 'Рейка A — ${Units.meters(toA)} '
                          '(${toA > toB ? 'дальняя' : 'ближняя'}), '
                          'рейка B — ${Units.meters(toB)} '
                          '(${toB > toA ? 'дальняя' : 'ближняя'}).',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  equalArms
                      ? 'Плечи равны — наклон визирной оси гасится, превышение '
                          'получается истинным.'
                      : 'Рейки не переставляются — переносится только нивелир.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.35),
                ),
                if (wizard.runCount > 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Приёмов ${wizard.runCount} — высоту прибора меняют '
                    '${_timesLabel(wizard.runCount - 1)}, перед каждым '
                    'следующим приёмом. Точка стояния не меняется.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < wizard.runs.length; i++)
            _runBlock(context, wizard, i, isMm, toA, toB, usesHeight),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (_isFirst) {
                wizard.nextStep();
              } else {
                wizard.compute();
                wizard.nextStep();
              }
            },
            child: Text(_isFirst ? 'Далее — станция 2' : 'Рассчитать угол i'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Пометка «дальняя» в подписи поля. Именно по дальней рейке считается
  /// целевой отсчёт при юстировке, поэтому её стоит различать сразу при
  /// вводе, а не узнавать об этом через два шага.
  static String _armSuffix(double own, double other) {
    if ((own - other).abs() < 0.001) return '';
    return own > other ? ' (дальняя)' : ' (ближняя)';
  }

  Widget _runBlock(
    BuildContext context,
    WizardState wizard,
    int index,
    bool isMm,
    double toA,
    double toB,
    bool usesHeight,
  ) {
    final run = wizard.runs[index];
    final aCtrl = _isFirst ? run.station1A : run.station2A;
    final bCtrl = _isFirst ? run.station1B : run.station2B;

    final aMm = wizard.readingMm(aCtrl);
    final bMm = wizard.readingMm(bCtrl);
    final hMm = (aMm != null && bMm != null) ? aMm - bMm : null;

    final unit = isMm ? 'мм' : 'м';
    final aIsHeight = usesHeight && toA < 0.5;
    final bIsHeight = usesHeight && toB < 0.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wizard.runs.length > 1) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Приём ${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
            if (index > 0)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.height,
                        size: 15, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Перед этим приёмом измените высоту прибора',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 4),
          ],
          TextFormField(
            controller: aCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: aIsHeight
                  ? 'Высота визирной оси над точкой A, $unit'
                  : 'Отсчёт по рейке A${_armSuffix(toA, toB)}, $unit',
              prefixIcon: Icon(aIsHeight ? Icons.height : Icons.straighten),
            ),
            onChanged: (_) => wizard.notifyReadingChanged(),
            validator: (value) => _validate(value, isMm),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: bCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: bIsHeight
                  ? 'Высота визирной оси над точкой B, $unit'
                  : 'Отсчёт по рейке B${_armSuffix(toB, toA)}, $unit',
              prefixIcon: Icon(bIsHeight ? Icons.height : Icons.straighten),
            ),
            onChanged: (_) => wizard.notifyReadingChanged(),
            validator: (value) => _validate(value, isMm),
          ),
          if (hMm != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.functions,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'h = A − B: ${Units.signed(hMm, isMm)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _validate(String? value, bool isMm) {
    if (value == null || value.trim().isEmpty) return 'Введите отсчёт';
    final mm = Units.parseReading(value, isMm);
    if (mm == null) return 'Не похоже на число';
    if (mm < 0) return 'Отсчёт по рейке не бывает отрицательным';
    if (mm > 5000) return 'Больше длины рейки — проверьте ввод';
    return null;
  }
}
