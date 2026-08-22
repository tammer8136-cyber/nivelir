import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_settings.dart';
import '../theme/app_theme.dart';
import 'help/help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Единицы отсчётов',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    'Только формат ввода и вывода: внутри отсчёты всегда '
                    'хранятся в целых миллиметрах.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'mm', label: Text('миллиметры')),
                      ButtonSegment(value: 'm', label: Text('метры')),
                    ],
                    selected: {settings.units},
                    onSelectionChanged: (s) => settings.setUnits(s.first),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              value: !settings.skipPreflight,
              onChanged: (v) => settings.setSkipPreflight(!v),
              title: const Text('Показывать подготовку к работе'),
              subtitle: const Text(
                'Напоминание про круглые уровни нивелира и рейки перед '
                'началом поверки',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.menu_book_outlined, color: AppTheme.primary),
              title: const Text('Справка'),
              subtitle: const Text('Методы, допуски, поверка уровней'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'Вердикт по углу i выносится по ГОСТ 10528-90 п. 2.3 и '
              'ГКИНП (ГНТА) 17-195-99 п. 4.2.5 — не более 10″. Предел '
              'расхождения приёмов 3″/5″ (ГКИНП 03-010-03, приложение 9) '
              'показывается справочно.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
