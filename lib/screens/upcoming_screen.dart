import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_instance.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import 'devices/instance_detail_screen.dart';
import 'devices/reminder_editor.dart';

/// Раздел «К поверке» — единственное место, где живут напоминания.
///
/// История поверок отвечает на вопрос «что уже сделано», этот раздел — на
/// вопрос «что пора делать». Поэтому список сортируется по сроку, а
/// просроченное поднимается наверх.
///
/// Приборы без настроенного напоминания показываются здесь же, внизу:
/// иначе настроить напоминание было бы негде.
class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _fetch();
  }

  Future<_Data> _fetch() async {
    final db = context.read<DatabaseService>();
    final instances = await db.getInstances();
    final reminders = await db.getAllReminders();
    return _Data(instances: instances, reminders: reminders);
  }

  Future<void> _editReminder(DeviceInstance instance, Reminder? current) async {
    final result = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReminderEditor(
        deviceId: instance.id!,
        initial: current,
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
        await NotificationService.instance.schedule(next, instance.displayName);
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

    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('К поверке')),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.instances.isEmpty) {
            return const _Empty();
          }

          final now = DateTime.now();
          final scheduled = <_Row>[];
          final unscheduled = <_Row>[];

          for (final instance in data.instances) {
            final reminder = data.reminders[instance.id];
            final row = _Row(instance: instance, reminder: reminder);
            if (reminder != null && reminder.enabled) {
              scheduled.add(row);
            } else {
              unscheduled.add(row);
            }
          }

          // Ближайший срок первым; у кого срок не рассчитан — в конец.
          scheduled.sort((a, b) {
            final x = a.reminder!.nextFireAt;
            final y = b.reminder!.nextFireAt;
            if (x == null && y == null) return 0;
            if (x == null) return 1;
            if (y == null) return -1;
            return x.compareTo(y);
          });

          final overdue =
              scheduled.where((r) => r.isOverdue(now)).toList();
          final upcoming =
              scheduled.where((r) => !r.isOverdue(now)).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (overdue.isNotEmpty) ...[
                const _SectionHeader('Просрочено', color: AppTheme.error),
                for (final r in overdue) _tile(r, now),
              ],
              if (upcoming.isNotEmpty) ...[
                const _SectionHeader('Предстоит'),
                for (final r in upcoming) _tile(r, now),
              ],
              if (unscheduled.isNotEmpty) ...[
                const _SectionHeader('Напоминание не настроено'),
                for (final r in unscheduled) _tile(r, now),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _tile(_Row row, DateTime now) {
    final reminder = row.reminder;
    final enabled = reminder != null && reminder.enabled;
    final overdue = row.isOverdue(now);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          overdue
              ? Icons.notification_important
              : enabled
                  ? Icons.notifications_active
                  : Icons.notifications_none,
          color: overdue
              ? AppTheme.error
              : enabled
                  ? AppTheme.primary
                  : AppTheme.textSecondary,
        ),
        title: Text(row.instance.displayName),
        subtitle: Text(
          row.subtitle(now),
          style: TextStyle(
            fontSize: 12,
            color: overdue ? AppTheme.error : AppTheme.textSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_notifications_outlined),
          tooltip: 'Настроить напоминание',
          onPressed: () => _editReminder(row.instance, reminder),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InstanceDetailScreen(instance: row.instance),
            ),
          );
          if (mounted) setState(_load);
        },
      ),
    );
  }
}

class _Data {
  final List<DeviceInstance> instances;
  final Map<int, Reminder> reminders;
  const _Data({required this.instances, required this.reminders});
}

class _Row {
  final DeviceInstance instance;
  final Reminder? reminder;
  const _Row({required this.instance, this.reminder});

  bool isOverdue(DateTime now) {
    final r = reminder;
    if (r == null || !r.enabled) return false;
    final next = r.nextFireAt;
    return next != null && next.isBefore(now);
  }

  String subtitle(DateTime now) {
    final r = reminder;
    if (r == null || !r.enabled) return 'Напоминание выключено';

    final next = r.nextFireAt;
    if (next == null) return r.intervalLabel;

    final days = DateTime(next.year, next.month, next.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (days < 0) {
      return 'Просрочено на ${_days(-days)} · ${r.intervalLabel}';
    }
    if (days == 0) return 'Сегодня · ${r.intervalLabel}';
    if (days == 1) return 'Завтра · ${r.intervalLabel}';
    return 'Через ${_days(days)} · ${Units.dateOnly.format(next)}';
  }

  static String _days(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$n дней';
    if (mod10 == 1) return '$n день';
    if (mod10 >= 2 && mod10 <= 4) return '$n дня';
    return '$n дней';
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionHeader(this.text, {this.color = AppTheme.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Приборов пока нет',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text(
              'Заведите прибор в разделе «Приборы» — здесь появится его '
              'срок поверки.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
