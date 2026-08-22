import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_settings.dart';
import '../../../state/wizard_state.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/units.dart';

class StepResult extends StatelessWidget {
  const StepResult({super.key});

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<WizardState>();
    final isMm = context.select<AppSettings, bool>((s) => s.isMillimeters);
    final result = wizard.result;

    if (result == null) {
      return const Center(child: Text('Введите отсчёты на обеих станциях'));
    }

    final pass = result.withinTolerance;
    final color = pass ? AppTheme.success : AppTheme.error;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(pass ? Icons.check_circle : Icons.error,
                  color: color, size: 40),
              const SizedBox(height: 10),
              Text(
                Units.signedArcsec(result.iArcsec),
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                pass
                    ? 'В допуске ${Units.arcsec(result.toleranceArcsec)} '
                        '(ГОСТ 10528-90 п. 2.3, ГКИНП 17-195-99 п. 4.2.5)'
                    : 'Вне допуска ${Units.arcsec(result.toleranceArcsec)} — '
                        'требуется юстировка',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'наклон визирной оси '
                '${Units.signed(result.mmPer100m, true)} на 100 м',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        if (result.anomalyFlagged) ...[
          const SizedBox(height: 12),
          _warning(
            'Значение превышает допуск более чем в десять раз. Для '
            'компенсаторного нивелира это почти всегда опечатка в отсчётах — '
            'проверьте ввод. Сохранить результат это не мешает.',
          ),
        ],

        if (!result.runCountMeetsNorm) ...[
          const SizedBox(height: 12),
          _warning(
            'Выполнен один приём. Минимум по действующим документам — два '
            '(ГКИНП 03-010-03, приложение 9) либо три '
            '(ГКИНП 17-195-99, п. 4.2.5). Результат ни одному из них не '
            'соответствует и годится как экспресс-проверка.',
          ),
        ],

        if (result.spreadExceeded) ...[
          const SizedBox(height: 12),
          _warning(
            'Размах значений угла i по приёмам — '
            '${Units.arcsec(result.spreadArcsec!)} при пределе '
            '${Units.arcsec(result.spreadLimitArcsec)} (ГКИНП 03-010-03, прил. 9). '
            'На вердикт не влияет, но измерения стоит повторить.',
          ),
        ],

        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('РАСЧЁТ',
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                _row('Истинное превышение A − B',
                    Units.signed(result.hTrueMm, isMm)),
                _row('Знаменатель формулы',
                    Units.meters(result.distanceDiffM.abs())),
                _row(
                  'Приёмов',
                  result.runsNorm == null
                      ? '${result.runCount} — ниже нормы'
                      : '${result.runCount} (${result.runsNorm!.source})',
                ),
                if (result.spreadArcsec != null)
                  _row('Размах по приёмам',
                      '${Units.arcsec(result.spreadArcsec!)} '
                      '(предел ${Units.arcsec(result.spreadLimitArcsec)})'),
                const Divider(height: 20),
                _row('Угол i (среднее)', Units.signedArcsec(result.iArcsec)),
                _row('Допуск ГОСТ', Units.arcsec(result.toleranceArcsec)),
              ],
            ),
          ),
        ),

        if (result.runCount > 1) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ПО ПРИЁМАМ',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < result.runs.length; i++)
                    _row('Приём ${i + 1}',
                        Units.signedArcsec(result.runs[i].iArcsec)),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        // Класс работ — метаданные протокола, а не параметр расчёта:
        // на вердикт он не влияет (табл. 4 угол i не нормирует), поэтому
        // спрашивается здесь, рядом с примечаниями, а не в мастере.
        DropdownButtonFormField<int?>(
          key: ValueKey('lclass_${wizard.levelingClass}'),
          initialValue: wizard.levelingClass,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Класс нивелирования (необязательно)',
            helperText: 'Записывается в протокол. Допуск прибора к классам '
                'смотрите в его карточке',
            helperMaxLines: 3,
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('не указан')),
            DropdownMenuItem(value: 1, child: Text('I класс')),
            DropdownMenuItem(value: 2, child: Text('II класс')),
            DropdownMenuItem(value: 3, child: Text('III класс')),
            DropdownMenuItem(value: 4, child: Text('IV класс')),
          ],
          onChanged: (v) =>
              context.read<WizardState>().setLevelingClass(v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: wizard.notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Примечания (необязательно)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),

        if (!pass) ...[
          ElevatedButton.icon(
            onPressed: wizard.nextStep,
            icon: const Icon(Icons.build_outlined),
            label: const Text('Перейти к юстировке'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () async {
            final saved = await wizard.save();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(saved == null
                    ? 'Не удалось сохранить'
                    : 'Протокол сохранён в историю'),
              ),
            );
            if (saved != null) Navigator.pop(context);
          },
          icon: const Icon(Icons.save_outlined),
          label: Text(pass ? 'Сохранить и закрыть' : 'Сохранить без юстировки'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _warning(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(text, style: const TextStyle(height: 1.35, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
