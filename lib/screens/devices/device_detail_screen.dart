import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/reminder.dart';
import '../../models/verification.dart';
import '../../services/database_service.dart';
import '../../services/nivelir/algorithms/leveling_class.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import '../verification_detail_screen.dart';
import 'device_form_screen.dart';
import 'reminder_editor.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late Device _device;
  Reminder? _reminder;
  late Future<List<Verification>> _history;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _load();
  }

  void _load() {
    final db = context.read<DatabaseService>();
    _history = db.getVerifications(deviceId: _device.id);
    db.getReminder(_device.id!).then((r) {
      if (mounted) setState(() => _reminder = r);
    });
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<Device>(
      context,
      MaterialPageRoute(builder: (_) => DeviceFormScreen(device: _device)),
    );
    if (updated != null && mounted) {
      setState(() {
        _device = updated;
        _load();
      });
    }
  }

  /// Удаление без подтверждений — решение зафиксировано в спеке.
  /// История поверок при этом остаётся: у протоколов своя копия названия.
  Future<void> _delete() async {
    final db = context.read<DatabaseService>();
    await NotificationService.instance.cancelForDevice(_device.id!);
    await db.deleteDevice(_device.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _editReminder() async {
    final result = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReminderEditor(
        deviceId: _device.id!,
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
        await NotificationService.instance.schedule(next, _device.displayName);
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
    final d = _device;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.model),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          if (!d.isCatalog)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _row('Класс (ГОСТ 10528-90)',
                      '${d.gostClass} (${d.designationHint})'),
                  _row('СКО', '${d.skoMmKm} мм/км'),
                  _row('Допуск угла i', Units.arcsec(d.toleranceArcsec)),
                  _row('Предел расхождения приёмов',
                      Units.arcsec(d.runSpreadLimitArcsec)),
                  _row('Дрейф угла i',
                      '${Units.arcsec(d.tempDriftArcsecPerC)} на 1 °С'),
                  if (d.magnification != null)
                    _row('Увеличение', '${d.magnification}×'),
                  _row('Компенсатор', d.compensatorLabel),
                  _row('Исправление угла i', d.adjustmentMethodLabel),
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
                  _admissionSection(d),
                  if (d.minFocusM != null)
                    _row('Мин. фокус', '${d.minFocusM} м'),
                  if (d.minFocusNote != null)
                    _row('Примечание', d.minFocusNote!),
                  _row('Источник', d.isCatalog ? 'каталог' : 'добавлен вручную'),
                ],
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(
                _reminder?.enabled == true
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined,
                color: _reminder?.enabled == true
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
              title: const Text('Напоминание о поверке'),
              subtitle: Text(
                _reminder?.enabled == true
                    ? '${_reminder!.intervalLabel}, следующее — '
                        '${_reminder!.nextFireAt == null ? "—" : Units.dateOnly.format(_reminder!.nextFireAt!)}'
                    : 'выключено',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editReminder,
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'ИСТОРИЯ ПОВЕРОК',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          FutureBuilder<List<Verification>>(
            future: _history,
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
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text('Поверок по этому прибору ещё не было',
                      style: TextStyle(color: AppTheme.textSecondary)),
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
                        title: Text(
                          'i = ${Units.signedArcsec(v.iAngleArcsec)}'
                          '${v.adjusted ? " · юстирован" : ""}',
                        ),
                        subtitle: Text(Units.dateTime.format(v.createdAt)),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VerificationDetailScreen(verification: v),
                            ),
                          );
                          if (mounted) setState(_load);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Допуск прибора к классам работ по ГКИНП 03-010-03, п. 21.1, табл. 4.
  ///
  /// Живёт в карточке прибора, а не в мастере: пригодность выводится из СКП
  /// и увеличения, то есть это постоянное свойство прибора, а не решение,
  /// принимаемое в момент поверки. На вердикт поверки не влияет — угол i
  /// табл. 4 не нормирует.
  Widget _admissionSection(Device d) {
    final highest = LevelingClass.highestAdmittedClass(
      skoMmKm: d.skoMmKm,
      magnification: d.magnification,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ДОПУСК К КЛАССАМ РАБОТ',
            style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.8,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        const Text('ГКИНП 03-010-03, табл. 4',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        for (var cls = 1; cls <= 4; cls++)
          Builder(builder: (context) {
            final check = LevelingClass.check(
              levelingClass: cls,
              skoMmKm: d.skoMmKm,
              magnification: d.magnification,
            );
            final req = LevelingClassRequirements.byClass(cls);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    check.admitted ? Icons.check_circle : Icons.remove_circle,
                    size: 18,
                    color: check.admitted
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(LevelingClass.roman(cls),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(
                      'СКП ≤ ${req.maxSkoMmKm} мм/км, '
                      'увеличение ≥ ${req.minMagnification}×',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 10),
        Text(
          highest == null
              ? d.magnification == null
                  ? 'Увеличение трубы не указано — проверка по этому '
                      'параметру не выполнена, поэтому допуск не подтверждён '
                      'ни для одного класса.'
                  : 'По табл. 4 прибор не проходит ни по одному классу.'
              : 'Наивысший класс — ${LevelingClass.roman(highest)}.',
          style: const TextStyle(fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 6),
        const Text(
          'Диапазон компенсатора и температурный дрейф угла i табл. 4 тоже '
          'нормирует, но приложение их не измеряет.',
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
