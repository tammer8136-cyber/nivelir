import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/help_articles.dart';
import '../../../state/app_settings.dart';
import '../../../state/wizard_state.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/diagrams/level_diagrams.dart';

/// Шаг 0 — не вычисляемый. Поверка угла i бессмысленна при сбитом круглом
/// уровне: компенсатор работает на пределе диапазона (обычно ±15′).
/// Приложение только напоминает, проверяет пользователь сам.
class StepPreflight extends StatelessWidget {
  const StepPreflight({super.key});

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<WizardState>();
    final settings = context.read<AppSettings>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Перед определением угла i',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Убедитесь, что круглые уровни нивелира и рейки в порядке. '
          'При сбитом круглом уровне компенсатор работает на краю своего '
          'диапазона, и результат поверки будет недостоверным.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        _checkCard(
          context,
          icon: Icons.adjust,
          title: 'Круглый уровень нивелира',
          summary:
              'Повернуть трубу на 180°. Пузырёк ушёл из центра — нужна юстировка.',
          details: HelpArticles.roundLevelInstrument,
          diagrams: const [
            RoundLevelCheckDiagram(),
            HalfRuleDiagram(),
          ],
        ),
        _checkCard(
          context,
          icon: Icons.straighten,
          title: 'Круглый уровень рейки',
          summary:
              'Совместить ребро рейки с отвесной нитью сетки, выверить уровень рейки.',
          details: HelpArticles.roundLevelRod,
          diagrams: const [RodLevelDiagram()],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: wizard.dontShowPreflightAgain,
          onChanged: (v) => wizard.setDontShowPreflightAgain(v ?? false),
          title: const Text('Больше не показывать'),
          subtitle: const Text(
            'Инструкции останутся доступны в разделе «Справка»',
            style: TextStyle(fontSize: 12),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            if (wizard.dontShowPreflightAgain) {
              await settings.setSkipPreflight(true);
            }
            wizard.nextStep();
          },
          child: const Text('Понятно, продолжить'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _checkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String summary,
    required String details,
    required List<Widget> diagrams,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title),
          subtitle: Text(summary, style: const TextStyle(fontSize: 12)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details, style: const TextStyle(height: 1.45)),
            for (final d in diagrams) ...[
              const SizedBox(height: 16),
              d,
            ],
          ],
        ),
      ),
    );
  }
}
