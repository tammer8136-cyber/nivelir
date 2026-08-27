import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_model.dart';
import '../../services/database_service.dart';
import '../../services/nivelir/algorithms/classification.dart';
import '../../theme/app_theme.dart';

/// Добавление и правка МОДЕЛИ прибора.
///
/// Каталожные модели не редактируются: их характеристики приходят из
/// поставки. Нужны другие — заводится своя модель.
///
/// Класс и допуск здесь не вводятся никогда: они считаются из СКО, чтобы
/// правило жило в одном месте.
class ModelFormScreen extends StatefulWidget {
  final DeviceModel? model;

  /// Предзаполнение марки: форма открыта из формы экземпляра, где марка
  /// уже выбрана.
  final String? initialBrand;

  const ModelFormScreen({super.key, this.model, this.initialBrand});

  @override
  State<ModelFormScreen> createState() => _ModelFormScreenState();
}

class _ModelFormScreenState extends State<ModelFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _magnificationCtrl;
  late final TextEditingController _skoCtrl;
  late final TextEditingController _minFocusCtrl;
  late final TextEditingController _referenceCtrl;

  String? _compensatorType;
  String? _adjustmentMethod;
  double? _sko;

  bool get _isCatalog => widget.model?.isCatalog ?? false;
  bool get _isEdit => widget.model != null;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _brandCtrl = TextEditingController(text: m?.brand ?? widget.initialBrand ?? '');
    _modelCtrl = TextEditingController(text: m?.model ?? '');
    _magnificationCtrl =
        TextEditingController(text: m?.magnification?.toString() ?? '');
    _skoCtrl = TextEditingController(text: m?.skoMmKm.toString() ?? '');
    _minFocusCtrl = TextEditingController(text: m?.minFocusM?.toString() ?? '');
    _referenceCtrl = TextEditingController(text: m?.referenceInfo ?? '');
    _compensatorType = m?.compensatorType;
    _adjustmentMethod = m?.adjustmentMethod;
    _sko = m?.skoMmKm;
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _magnificationCtrl.dispose();
    _skoCtrl.dispose();
    _minFocusCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  double? _parse(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final db = context.read<DatabaseService>();
    final model = DeviceModel(
      id: widget.model?.id,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      magnification: int.tryParse(_magnificationCtrl.text.trim()),
      skoMmKm: _parse(_skoCtrl.text) ?? 0,
      compensatorType: _compensatorType,
      minFocusM: _parse(_minFocusCtrl.text),
      minFocusNote: widget.model?.minFocusNote,
      adjustmentMethod: _adjustmentMethod,
      referenceInfo: _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim(),
      source: widget.model?.source ?? 'custom',
    );

    DeviceModel saved;
    if (_isEdit) {
      await db.updateModel(model);
      saved = model;
    } else {
      final id = await db.insertModel(model);
      saved = model.copyWith(id: id);
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Модель прибора' : 'Новая модель'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isCatalog)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Модель из справочника — характеристики не редактируются. '
                  'Если у вашего прибора паспортные данные другие, добавьте '
                  'свою модель.',
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
              controller: _skoCtrl,
              enabled: !_isCatalog,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'СКО, мм на 1 км двойного хода',
                helperText: 'Из паспорта прибора — определяет класс и допуск',
                helperMaxLines: 2,
              ),
              onChanged: (v) => setState(() => _sko = _parse(v)),
              validator: (v) {
                final parsed = _parse(v ?? '');
                if (parsed == null || parsed <= 0) return 'Укажите СКО';
                return null;
              },
            ),
            if (_sko != null && _sko! > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Класс: ${DeviceClassification.gostClass(_sko!)}'),
                    // Полевой допуск задаётся не классом, а РЭ модели,
                    // и у новой карточки его ещё нет. Показывать здесь
                    // лабораторные 10" по ГОСТ значило бы выдать их за
                    // полевой предел.
                    const Text(
                      'Допуск полевой поверки: из РЭ модели, '
                      'заполняется отдельно',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(DeviceClassification.designationHint(_sko!),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _magnificationCtrl,
              enabled: !_isCatalog,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Увеличение, ×',
                helperText: 'Нужно для проверки допуска к классам работ',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('comp_$_compensatorType'),
              initialValue: _compensatorType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Компенсатор'),
              items: const [
                DropdownMenuItem(value: null, child: Text('не указан')),
                DropdownMenuItem(
                    value: 'air', child: Text('воздушное демпфирование')),
                DropdownMenuItem(
                    value: 'magnetic', child: Text('магнитное демпфирование')),
                DropdownMenuItem(
                    value: 'pendulum', child: Text('маятниковый')),
              ],
              onChanged: _isCatalog
                  ? null
                  : (v) => setState(() => _compensatorType = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minFocusCtrl,
              enabled: !_isCatalog,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Минимальное фокусное расстояние, м',
              ),
            ),
            const SizedBox(height: 12),

            // Способ юстировки правится и у каталожных моделей: в поставке
            // этого поля нет, а без него шаг юстировки не сможет
            // предупредить, что прибор в поле исправлять нельзя.
            DropdownButtonFormField<String?>(
              key: ValueKey('adjustment_$_adjustmentMethod'),
              initialValue: _adjustmentMethod,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Исправление угла i',
                helperText:
                    'Указано в описании прибора (ГКИНП 03-010-03, прил. 9)',
                helperMaxLines: 3,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('не указан')),
                DropdownMenuItem(
                    value: 'reticle', child: Text('перемещением сетки нитей')),
                DropdownMenuItem(
                    value: 'wedge', child: Text('поворотом защитного стекла')),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceCtrl,
              enabled: !_isCatalog,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Справочная информация',
                helperText: 'Особенности прибора, замечания по эксплуатации',
                helperMaxLines: 2,
                alignLabelWithHint: true,
              ),
            ),
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
