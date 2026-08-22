import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/device_instance.dart';
import '../../../models/method_preset.dart';
import '../../../services/database_service.dart';
import '../../../services/settings_service.dart';
import '../../../state/wizard_state.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/units.dart';
import '../../devices/device_picker_screen.dart';

class StepParams extends StatefulWidget {
  const StepParams({super.key});

  @override
  State<StepParams> createState() => _StepParamsState();
}

class _StepParamsState extends State<StepParams> {
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    _restoreLastChoice();
  }

  /// Подставляем прибор и метод из прошлой поверки — в поле это чаще всего
  /// один и тот же прибор.
  Future<void> _restoreLastChoice() async {
    final wizard = context.read<WizardState>();
    final db = context.read<DatabaseService>();

    final presetId = await SettingsService.loadLastPreset();
    if (presetId != null && mounted) {
      wizard.setPreset(MethodPreset.byId(presetId));
    }

    final deviceId = await SettingsService.loadLastDeviceId();
    if (deviceId != null && mounted) {
      final device = await db.getInstance(deviceId);
      if (device != null && mounted) wizard.setDevice(device);
    }
  }

  Future<void> _pickDevice() async {
    final device = await Navigator.push<DeviceInstance>(
      context,
      MaterialPageRoute(builder: (_) => const DevicePickerScreen()),
    );
    if (device != null && mounted) {
      context.read<WizardState>().setDevice(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<WizardState>();
    final device = wizard.device;
    final preset = wizard.preset;

    return Form(
      key: wizard.paramsFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Прибор'),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                device == null ? Icons.help_outline : Icons.straighten,
                color:
                    device == null ? AppTheme.textSecondary : AppTheme.primary,
              ),
              title: Text(device?.displayName ?? 'Выберите прибор'),
              subtitle: device == null
                  ? null
                  : Text(
                      '${device.gostClass} · СКО ${device.skoMmKm} мм/км · '
                      'допуск угла i ${Units.arcsec(device.toleranceArcsec)}',
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDevice,
            ),
          ),
          if (device != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Дайте прибору акклиматизироваться: угол i уходит на '
                '${Units.arcsec(device.tempDriftArcsecPerC)} на каждый градус '
                'разницы температур.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
              ),
            ),
          const SizedBox(height: 24),

          const _SectionTitle('Метод'),
          DropdownButtonFormField<String>(
            // Ключ по id: пресет может смениться извне (восстановление
            // прошлого выбора), а FormField читает initialValue только при
            // создании — без ключа список показывал бы устаревшее значение.
            key: ValueKey('preset_${preset.id}'),
            initialValue: preset.id,
            // Названия способов длинные (со ссылкой на документ) и не
            // помещаются в ширину по умолчанию — без isExpanded строка
            // вылезает за край.
            isExpanded: true,
            items: [
              for (final p in MethodPreset.all)
                DropdownMenuItem(value: p.id, child: Text(p.title)),
            ],
            onChanged: (id) {
              if (id != null) {
                context.read<WizardState>().setPreset(MethodPreset.byId(id));
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            preset.description,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),

          const _SectionTitle(
            'Приёмы',
            info: 'Между приёмами меняют высоту прибора — это ловит просчёт '
                'при взятии отсчёта и ошибку фокусировки.\n\n'
                'Требования к числу приёмов расходятся:\n\n'
                '• ГКИНП (ГНТА) 17-195-99, п. 4.2.5 — не менее трёх в любом '
                'способе, за результат берётся среднее;\n'
                '• ГКИНП (ГНТА) 03-010-03, приложение 9 — два приёма, '
                'не снимая нивелир со штатива.\n\n'
                'Основание выбирать не нужно: три приёма проходят по обоим '
                'документам, два — только по приложению 9, один — ни по '
                'одному. Приложение само запишет в протокол, чему '
                'соответствует набранное число.',
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
            ],
            selected: {wizard.runCount},
            onSelectionChanged: (selected) =>
                context.read<WizardState>().setRunCount(selected.first),
          ),
          const SizedBox(height: 8),
          Text(
            wizard.runsNorm == null
                ? 'Один приём — экспресс-проверка. Не соответствует ни '
                    'одному из действующих документов; протокол будет помечен.'
                : 'Соответствует: ${wizard.runsNorm!.source}',
            style: TextStyle(
              fontSize: 12,
              color: wizard.runsNorm == null
                  ? AppTheme.warning
                  : AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          const _SectionTitle('Плечи, м'),
          const Text(
            'Рейки A и B — неподвижные точки створа. Расстояния задаются от '
            'каждой станции до каждой рейки; какая рейка ближе, приложение '
            'определит само.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          _geometryRow(
            label: 'Станция 1',
            aCtrl: wizard.s1ACtrl,
            bCtrl: wizard.s1BCtrl,
            enabled: preset.editableGeometry,
          ),
          const SizedBox(height: 12),
          _geometryRow(
            label: 'Станция 2',
            aCtrl: wizard.s2ACtrl,
            bCtrl: wizard.s2BCtrl,
            enabled: preset.editableGeometry,
          ),
          if (preset.usesInstrumentHeight) ...[
            const SizedBox(height: 10),
            const Text(
              'Плечо 0 м означает, что нивелир стоит над точкой: вместо '
              'отсчёта вводится высота визирной оси, измеренная рулеткой.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Знаменатель формулы угла i: '
              '${Units.meters(wizard.geometry.distanceDiffM.abs())}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              if (device == null) {
                _snack('Сначала выберите прибор');
                return;
              }
              if (!wizard.pullGeometryFromControllers()) {
                _snack(
                  'Проверьте плечи: разности плеч на станциях не должны '
                  'совпадать, иначе угол i не определяется',
                );
                return;
              }
              wizard.nextStep();
            },
            child: const Text('Далее — станция 1'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _geometryRow({
    required String label,
    required TextEditingController aCtrl,
    required TextEditingController bCtrl,
    required bool enabled,
  }) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: TextFormField(
            controller: aCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'до рейки A'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: bCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'до рейки B'),
          ),
        ),
      ],
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  /// Нормативное обоснование раздела. Если задано — рядом с заголовком
  /// появляется ⓘ, открывающая текст в диалоге. На экране остаются только
  /// органы управления, а ссылки на документы не занимают полполосы.
  final String? info;

  const _SectionTitle(this.text, {this.info});

  @override
  Widget build(BuildContext context) {
    final title = Text(text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

    if (info == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: title,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          title,
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            color: AppTheme.textSecondary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.only(left: 6),
            constraints: const BoxConstraints(),
            tooltip: 'Обоснование',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(text),
                content: SingleChildScrollView(
                  child: Text(info!, style: const TextStyle(height: 1.4)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
