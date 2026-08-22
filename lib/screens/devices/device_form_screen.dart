import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../services/database_service.dart';
import '../../services/nivelir/algorithms/classification.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';

/// Добавление/правка прибора.
///
/// Каталожные записи не редактируются — у них можно задать только серийный
/// номер экземпляра. Класс и допуск не вводятся никогда: считаются из СКО.
class DeviceFormScreen extends StatefulWidget {
  final Device? device;
  const DeviceFormScreen({super.key, this.device});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _magnificationCtrl;
  late final TextEditingController _skoCtrl;
  late final TextEditingController _minFocusCtrl;

  String? _compensatorType;
  String? _adjustmentMethod;
  double? _sko;

  bool get _isCatalog => widget.device?.isCatalog ?? false;
  bool get _isEdit => widget.device != null;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _brandCtrl = TextEditingController(text: d?.brand ?? '');
    _modelCtrl = TextEditingController(text: d?.model ?? '');
    _serialCtrl = TextEditingController(text: d?.serialNumber ?? '');
    _magnificationCtrl =
        TextEditingController(text: d?.magnification?.toString() ?? '');
    _skoCtrl = TextEditingController(text: d?.skoMmKm.toString() ?? '');
    _minFocusCtrl = TextEditingController(text: d?.minFocusM?.toString() ?? '');
    _compensatorType = d?.compensatorType;
    _adjustmentMethod = d?.adjustmentMethod;
    _sko = d?.skoMmKm;
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _magnificationCtrl.dispose();
    _skoCtrl.dispose();
    _minFocusCtrl.dispose();
    super.dispose();
  }

  double? _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final db = context.read<DatabaseService>();
    final serial = _serialCtrl.text.trim();

    final device = Device(
      id: widget.device?.id,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      serialNumber: serial.isEmpty ? null : serial,
      magnification: int.tryParse(_magnificationCtrl.text.trim()),
      skoMmKm: _parse(_skoCtrl.text)!,
      compensatorType: _compensatorType,
      minFocusM: _parse(_minFocusCtrl.text),
      minFocusNote: widget.device?.minFocusNote,
      adjustmentMethod: _adjustmentMethod,
      source: widget.device?.source ?? 'custom',
    );

    Device saved;
    if (_isEdit) {
      await db.updateDevice(device);
      saved = device;
    } else {
      final id = await db.insertDevice(device);
      saved = device.copyWith(id: id);
    }

    if (!mounted) return;
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final sko = _sko;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Прибор' : 'Новый прибор'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isCatalog)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Запись из каталога: характеристики не редактируются. '
                  'Можно указать серийный/инвентарный номер экземпляра.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            TextFormField(
              controller: _brandCtrl,
              enabled: !_isCatalog,
              decoration: const InputDecoration(labelText: 'Марка'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите марку' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelCtrl,
              enabled: !_isCatalog,
              decoration: const InputDecoration(labelText: 'Модель'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите модель' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serialCtrl,
              decoration: const InputDecoration(
                labelText: 'Серийный / инвентарный номер',
                helperText: 'Необязательно, для различения одинаковых приборов',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skoCtrl,
              enabled: !_isCatalog,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'СКО, мм на 1 км двойного хода',
                helperText: 'Из паспорта прибора — определяет класс и допуск',
              ),
              onChanged: (v) => setState(() => _sko = _parse(v)),
              validator: (v) {
                final value = _parse(v ?? '');
                if (value == null) return 'Укажите СКО';
                if (value <= 0 || value > 50) return 'Похоже на опечатку';
                return null;
              },
            ),
            if (sko != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Класс: ${DeviceClassification.gostClass(sko)} '
                      '(${DeviceClassification.designationHint(sko)})',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Допуск угла i: '
                      '${Units.arcsec(DeviceClassification.toleranceArcsec)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _magnificationCtrl,
              enabled: !_isCatalog,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Увеличение, ×'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('compensator_$_compensatorType'),
              initialValue: _compensatorType,
              decoration: const InputDecoration(labelText: 'Компенсатор'),
              items: const [
                DropdownMenuItem(value: null, child: Text('не указан')),
                DropdownMenuItem(value: 'air', child: Text('воздушное демпфирование')),
                DropdownMenuItem(
                    value: 'magnetic', child: Text('магнитное демпфирование')),
                DropdownMenuItem(value: 'pendulum', child: Text('маятниковый')),
              ],
              onChanged: _isCatalog
                  ? null
                  : (v) => setState(() => _compensatorType = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minFocusCtrl,
              enabled: !_isCatalog,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Минимальное фокусное расстояние, м',
              ),
            ),
            const SizedBox(height: 12),

            // Способ юстировки редактируется и у каталожных приборов:
            // в каталоге этого поля нет, а без него шаг юстировки не может
            // предупредить, что прибор в поле исправлять нельзя.
            DropdownButtonFormField<String?>(
              key: ValueKey('adjustment_$_adjustmentMethod'),
              initialValue: _adjustmentMethod,
              decoration: const InputDecoration(
                labelText: 'Исправление угла i',
                helperText: 'Указано в описании прибора (ГКИНП 03-010-03, '
                    'прил. 9)',
                helperMaxLines: 3,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('не указан')),
                DropdownMenuItem(
                    value: 'reticle', child: Text('перемещением сетки нитей')),
                DropdownMenuItem(
                    value: 'wedge',
                    child: Text('поворотом защитного стекла')),
                DropdownMenuItem(
                    value: 'workshop', child: Text('только в мастерской')),
                DropdownMenuItem(
                    value: 'manual',
                    child: Text('по инструкции по эксплуатации')),
              ],
              onChanged: (v) => setState(() => _adjustmentMethod = v),
            ),
            if (_adjustmentMethod == 'workshop') ...[
              const SizedBox(height: 8),
              const Text(
                'Шаг юстировки для такого прибора покажет запрет вместо '
                'инструкции: угол i в полевых условиях не исправляется.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
