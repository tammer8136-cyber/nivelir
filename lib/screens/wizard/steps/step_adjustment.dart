import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_settings.dart';
import '../../../state/wizard_state.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/units.dart';

/// Юстировка компенсаторного нивелира. Ветка с цилиндрическим уровнем в
/// приложении отсутствует намеренно.
///
/// Способ исправления берётся из карточки прибора: по прил. 9 ГКИНП
/// 03-010-03 он указан в описании конкретного нивелира и различается —
/// сетка нитей, поворот защитного стекла, либо только мастерская.
class StepAdjustment extends StatelessWidget {
  const StepAdjustment({super.key});

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<WizardState>();
    final isMm = context.select<AppSettings, bool>((s) => s.isMillimeters);
    final result = wizard.result;

    if (result == null) {
      return const Center(child: Text('Сначала выполните расчёт'));
    }

    if (result.withinTolerance) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Прибор в допуске — юстировка не требуется.',
              textAlign: TextAlign.center),
        ),
      );
    }

    final device = wizard.device;

    if (device != null && device.adjustmentInFieldForbidden) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.build_circle_outlined, color: AppTheme.error),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Юстировка в поле не выполняется',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'В карточке прибора «${device.displayName}» указано, что '
                  'угол i исправляется только в мастерской. По приложению 9 '
                  'ГКИНП 03-010-03 у отдельных нивелиров (например Ni-002) '
                  'исправить угол i в полевых условиях нельзя.',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Угол i вне допуска: ${Units.arcsec(result.iArcsec)} при '
                  'допуске ${Units.arcsec(result.toleranceArcsec)}. Прибор '
                  'к работе не допускается до юстировки в мастерской.',
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              wizard.setAdjusted(false);
              final saved = await wizard.save();
              if (!context.mounted) return;
              if (saved != null) Navigator.pop(context);
            },
            child: const Text('Сохранить протокол'),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    final farIsA = result.geometry.farRodAtStation2IsA;
    final farLabel = farIsA ? 'A' : 'B';
    final nearLabel = farIsA ? 'B' : 'A';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Теоретически верный отсчёт по рейке $farLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                Units.readingWithUnit(result.farTheoreticalMm, isMm),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'на станции 2, дальняя рейка',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Порядок действий',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _step(1,
            'Не сдвигая нивелир со станции 2, наведитесь на рейку $farLabel.'),
        _step(
          2,
          device?.adjustmentMethod == 'wedge'
              ? 'Открепите стопорный винт и вращайте защитное стекло перед '
                  'объективом, пока отсчёт не станет равен теоретическому. '
                  'Следите, чтобы изображения концов пузырька уровня не '
                  'расходились.'
              : device?.adjustmentMethod == 'manual'
                  ? 'Выполните исправление по инструкции по эксплуатации '
                      'прибора, приведя отсчёт к теоретическому.'
                  : 'Юстировочными винтами сетки нитей подведите среднюю '
                      'нить к теоретическому отсчёту — не к тому, что видно '
                      'сейчас.',
        ),
        _step(3,
            'Закрепите винты и повторите поверку для контроля: угол i должен '
            'уложиться в допуск.'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Целевой отсчёт получен из наблюдённого отсчёта по самой рейке '
            '$farLabel за вычетом ошибки i·s на её плече. Отсчёт по ближней '
            'рейке $nearLabel для этого не используется: он содержит '
            'собственную ошибку i·s, и она ушла бы в результат.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            wizard.setAdjusted(true);
            final saved = await wizard.save();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(saved == null
                    ? 'Не удалось сохранить'
                    : 'Протокол сохранён, юстировка отмечена'),
              ),
            );
            if (saved != null) Navigator.pop(context);
          },
          icon: const Icon(Icons.check),
          label: const Text('Юстировка выполнена — сохранить'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () async {
            wizard.setAdjusted(false);
            final saved = await wizard.save();
            if (!context.mounted) return;
            if (saved != null) Navigator.pop(context);
          },
          child: const Text('Сохранить без юстировки'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _step(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppTheme.primary,
            child: Text('$number',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
