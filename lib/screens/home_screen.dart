import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verification.dart';
import '../services/database_service.dart';
import '../state/app_settings.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import 'devices/devices_list_screen.dart';
import 'help/help_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'verification_detail_screen.dart';
import 'wizard/wizard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Verification>> _recent;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = context.read<DatabaseService>();
    _recent = db.getVerifications(limit: 3);
  }

  Future<void> _openWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WizardScreen()),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поверка нивелира'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _openWizard,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text('Новая поверка'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.straighten,
            title: 'Приборы',
            subtitle: 'Справочник моделей и свои приборы',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DevicesListScreen()),
              );
              if (mounted) setState(_reload);
            },
          ),
          _tile(
            icon: Icons.history,
            title: 'История поверок',
            subtitle: 'Протоколы, PDF и Excel',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
              if (mounted) setState(_reload);
            },
          ),
          _tile(
            icon: Icons.menu_book_outlined,
            title: 'Справка',
            subtitle: 'Методы, допуски, поверка круглого уровня',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'ПОСЛЕДНИЕ ПОВЕРКИ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          FutureBuilder<List<Verification>>(
            future: _recent,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'Поверок пока нет. Начните с кнопки «Новая поверка».',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              return Column(
                children: [
                  for (final v in items)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          v.isPass ? Icons.check_circle : Icons.error,
                          color: v.isPass ? AppTheme.success : AppTheme.error,
                        ),
                        title: Text(v.deviceLabel),
                        subtitle: Text(
                          '${Units.dateOnly.format(v.createdAt)} · '
                          'i = ${Units.signedArcsec(v.iAngleArcsec)} '
                          '(допуск ${Units.arcsec(v.toleranceArcsecSnapshot)})',
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VerificationDetailScreen(verification: v),
                            ),
                          );
                          if (mounted) setState(_reload);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Единицы отсчётов: ${settings.unitLabel}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
