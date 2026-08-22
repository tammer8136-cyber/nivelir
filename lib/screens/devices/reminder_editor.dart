import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../services/nivelir/algorithms/leveling_class.dart';
import '../../theme/app_theme.dart';

/// Настройка напоминания по конкретному прибору. Расписание произвольное:
/// интервал + день + время. По умолчанию выключено.
class ReminderEditor extends StatefulWidget {
  final int deviceId;
  final Reminder? initial;

  const ReminderEditor({super.key, required this.deviceId, this.initial});

  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  late bool _enabled;
  late String _kind;
  late int _count;
  int? _dayOfWeek;
  int? _dayOfMonth;
  late TimeOfDay _time;

  static const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _enabled = r?.enabled ?? false;
    _kind = r?.intervalKind ?? 'month';
    _count = r?.intervalCount ?? 6;
    _dayOfWeek = r?.dayOfWeek ?? 1;
    _dayOfMonth = r?.dayOfMonth;
    _time = TimeOfDay(hour: r?.hour ?? 9, minute: r?.minute ?? 0);
  }

  /// Список значений счётчика. Для дней доходит до 31: норматив требует
  /// интервал 15 дней, а он не выражается ни в неделях, ни в месяцах.
  /// Текущее значение добавляется всегда — иначе Dropdown падает на
  /// ассерте, если выбранного элемента нет в списке.
  List<int> get _countOptions {
    final max = _kind == 'day' ? 31 : 12;
    final options = <int>{for (var i = 1; i <= max; i++) i, _count}.toList()
      ..sort();
    return options;
  }

  bool get _matchesDaily => _kind == 'day' && _count == 1;

  bool get _matchesSteady =>
      _kind == 'day' && _count == VerificationSchedule.steadyIntervalDays;

  Reminder _build() => Reminder(
        id: widget.initial?.id,
        deviceId: widget.deviceId,
        enabled: _enabled,
        intervalKind: _kind,
        intervalCount: _count,
        dayOfWeek: _kind == 'week' ? _dayOfWeek : null,
        dayOfMonth: (_kind == 'month' || _kind == 'year') ? _dayOfMonth : null,
        monthOfYear: null,
        hour: _time.hour,
        minute: _time.minute,
      );

  @override
  Widget build(BuildContext context) {
    final preview = _build();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Напоминание о поверке',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: const Text('Включено'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            const Text('Норматив',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              '${VerificationSchedule.source}: '
              '${VerificationSchedule.description}',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Ежедневно, первая неделя'),
                  selected: _matchesDaily,
                  onSelected: (_) => setState(() {
                    _kind = 'day';
                    _count = 1;
                  }),
                ),
                ChoiceChip(
                  label: const Text(
                      'Раз в ${VerificationSchedule.steadyIntervalDays} дней'),
                  selected: _matchesSteady,
                  onSelected: (_) => setState(() {
                    _kind = 'day';
                    _count = VerificationSchedule.steadyIntervalDays;
                  }),
                ),
              ],
            ),
            if (_matchesDaily) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Через ${VerificationSchedule.dailyDays} дней переключите '
                  'на второй режим — но только если убедились в постоянстве '
                  'юстировки. Норматив ставит переход в зависимость от '
                  'результата, а не от календаря, поэтому приложение не '
                  'переключает режим само.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text('Расписание',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Раз в'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('count_$_count'),
                    initialValue: _count,
                    items: [
                      for (final i in _countOptions)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                    onChanged: (v) => setState(() => _count = v ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('kind_$_kind'),
                    initialValue: _kind,
                    items: const [
                      DropdownMenuItem(value: 'day', child: Text('дн.')),
                      DropdownMenuItem(value: 'week', child: Text('нед.')),
                      DropdownMenuItem(value: 'month', child: Text('мес.')),
                      DropdownMenuItem(value: 'year', child: Text('г.')),
                    ],
                    onChanged: (v) => setState(() {
                      _kind = v ?? 'month';
                      // 15 дней осмысленны, 15 месяцев — вряд ли: при
                      // переключении на более крупную единицу поджимаем.
                      if (_kind != 'day' && _count > 12) _count = 12;
                    }),
                  ),
                ),
              ],
            ),
            if (_kind == 'week') ...[
              const SizedBox(height: 16),
              const Text('День недели'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 7; i++)
                    ChoiceChip(
                      label: Text(_weekdays[i]),
                      selected: _dayOfWeek == i + 1,
                      onSelected: (_) => setState(() => _dayOfWeek = i + 1),
                    ),
                ],
              ),
            ],
            if (_kind == 'month' || _kind == 'year') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Число месяца'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('dom_$_dayOfMonth'),
                      initialValue: _dayOfMonth,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('как есть')),
                        for (var i = 1; i <= 28; i++)
                          DropdownMenuItem(value: i, child: Text('$i')),
                      ],
                      onChanged: (v) => setState(() => _dayOfMonth = v),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text('Время: ${_time.format(context)}'),
              onTap: () async {
                final picked =
                    await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Следующее срабатывание: '
                '${_format(preview.computeNextFire(DateTime.now()))}\n'
                'Время приблизительное — система может сдвинуть уведомление '
                'ради экономии батареи.',
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _build()),
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
