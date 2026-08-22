import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_instance.dart';
import '../../models/reminder.dart';
import '../../models/verification.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import '../verification_detail_screen.dart';
import 'instance_form_screen.dart';
import 'model_detail_screen.dart';
import 'reminder_editor.dart';

/// Карточка СВОЕГО ПРИБОРА: учётные данные, история поверок, напоминания.
///
/// Характеристики здесь не правятся — они принадлежат модели, ссылка на
/// её карточку рядом.
class InstanceDetailScreen extends StatefulWidget {
  final DeviceInstance instance;
  const InstanceDetailScreen({super.key, required this.instance});

  @override
  State<InstanceDetailScreen> createState() => _InstanceDetailScreenState();
}

class _InstanceDetailScreenState extends State<InstanceDetailScreen> {
  late DeviceInstance _instance;
  Reminder? _reminder;
  late Future<List<Verification>> _history;

  @override
  void initState() {
    super.initState();
    _instance = widget.instance;
    _load();
  }

  void _load() {
    final db = context.read<DatabaseService>();
    _history = db.getVerifications(deviceId: _instance.id);
    db.getReminder(_instance.id!).then((r) {
      if (mounted) setState(() => _reminder = r);
    });
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<DeviceInstance>(
      context,
      MaterialPageRoute(
        builder: (_) => InstanceFormScreen(instance: _instance),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _instance = updated;
        _load();
      });
    }
  }

  /// История поверок при удалении остаётся: у протоколов своя копия
  /// названия прибора.
  Future<void> _delete() async {
    final db = context.read<DatabaseService>();
    await NotificationService.instance.cancelForDevice(_instance.id!);
    await db.deleteInstance(_instance.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _editReminder() async {
    final result = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReminderEditor(
        deviceId: _instance.id!,
        initial: _reminder,
      ),
    );
    if (result == null || !mounted) return;

    final db = context.read<DatabaseService>();
    final next = result.enabled
        ? result.copyWith(nextFireAt: result.computeNextFire(DateTime.now()))
        : result;

    await db.saveReminder(next);

    if (next.enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (granted) {
        await NotificationService.instance
            .schedule(next, _instance.displayName);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Уведомления запрещены в настройках системы'),
          ),
        );
      }
    } else {
      await NotificationService.instance.cancel(next);
    }

    if (mounted) setState(() => _reminder = next);
  }

  @override
  Widget build(BuildContext context) {
    final d = _instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.model.title),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('УЧЁТНЫЕ ДАННЫЕ',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  _row('Модель', d.model.title),
                  _row('Номер', d.serialNumber ?? '—'),
                  _row('За кем закреплён', d.assignedTo ?? '—'),
                  if (d.notes != null && d.notes!.isNotEmpty)
                    _row('Примечание', d.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ХАРАКТЕРИСТИКИ МОДЕЛИ',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  _row('СКО', '${d.skoMmKm} мм/км'),
                  _row('Класс по ГОСТ 10528-90', d.gostClass),
                  _row('Допуск угла i', Units.arcsec(d.toleranceArcsec)),
                  if (d.magnification != null)
                    _row('Увеличение', '${d.magnification}×'),
                  _row('Компенсатор', d.compensatorLabel),
                  _row('Исправление угла i', d.adjustmentMethodLabel),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModelDetailScreen(model: d.model),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Карточка модели'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                _reminder?.enabled == true
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: _reminder?.enabled == true
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
              title: const Text('Напоминание о поверке'),
              subtitle: Text(
                _reminder?.enabled == true
                    ? _reminder!.intervalLabel
                    : 'Выключено',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editReminder,
            ),
          ),
          const SizedBox(height: 20),
          const Text('ИСТОРИЯ ПОВЕРОК',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          FutureBuilder<List<Verification>>(
            future: _history,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Поверок ещё не было',
                      style: TextStyle(color: AppTheme.textSecondary)),
                );
              }
              return Column(
                children: [
                  for (final v in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(Units.arcsec(v.iAngleArcsec)),
                        subtitle: Text(
                          Units.dateTime.format(v.createdAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Icon(
                          v.verdict == 'pass'
                              ? Icons.check_circle
                              : Icons.error,
                          color: v.verdict == 'pass'
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VerificationDetailScreen(verification: v),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
