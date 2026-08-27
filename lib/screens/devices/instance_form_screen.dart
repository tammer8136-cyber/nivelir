import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_instance.dart';
import '../../models/device_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'model_form_screen.dart';

/// Добавление и правка СВОЕГО ПРИБОРА (экземпляра).
///
/// Одна форма и для раздела «Приборы», и для мастера — дублировать экран
/// незачем.
///
/// Марка и модель выбираются шторками из справочника, после чего
/// характеристики подставляются автоматически и показываются только для
/// чтения: экземпляр не может отличаться от своей модели.
class InstanceFormScreen extends StatefulWidget {
  final DeviceInstance? instance;
  const InstanceFormScreen({super.key, this.instance});

  @override
  State<InstanceFormScreen> createState() => _InstanceFormScreenState();
}

class _InstanceFormScreenState extends State<InstanceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _serialCtrl;
  late final TextEditingController _assignedCtrl;
  late final TextEditingController _notesCtrl;

  List<String> _brands = [];
  List<DeviceModel> _models = [];

  String? _brand;
  DeviceModel? _model;
  bool _loading = true;

  bool get _isEdit => widget.instance != null;

  @override
  void initState() {
    super.initState();
    final i = widget.instance;
    _serialCtrl = TextEditingController(text: i?.serialNumber ?? '');
    _assignedCtrl = TextEditingController(text: i?.assignedTo ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
    _brand = i?.model.brand;
    _model = i?.model;
    _loadBrands();
  }

  @override
  void dispose() {
    _serialCtrl.dispose();
    _assignedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    final db = context.read<DatabaseService>();
    final brands = await db.getBrands();
    if (!mounted) return;
    setState(() {
      _brands = brands;
      _loading = false;
    });
    if (_brand != null) await _loadModels(_brand!, keepSelection: true);
  }

  Future<void> _loadModels(String brand, {bool keepSelection = false}) async {
    final db = context.read<DatabaseService>();
    final models = await db.getModelsByBrand(brand);
    if (!mounted) return;
    setState(() {
      _models = models;
      if (!keepSelection) _model = null;
      // При возврате из формы новой модели список перечитывается — надо
      // сохранить выбор по id, а не по ссылке на прежний объект.
      if (keepSelection && _model != null) {
        _model = models.firstWhere(
          (m) => m.id == _model!.id,
          orElse: () => _model!,
        );
      }
    });
  }

  /// Нужной модели в справочнике нет — заводим свою, не выходя из формы.
  Future<void> _addModel() async {
    final created = await Navigator.push<DeviceModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ModelFormScreen(initialBrand: _brand),
      ),
    );
    if (created == null || !mounted) return;

    final db = context.read<DatabaseService>();
    final brands = await db.getBrands();
    if (!mounted) return;
    setState(() {
      _brands = brands;
      _brand = created.brand;
    });
    await _loadModels(created.brand);
    if (mounted) setState(() => _model = created);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_model?.id == null) return;

    final db = context.read<DatabaseService>();
    final instance = DeviceInstance(
      id: widget.instance?.id,
      modelId: _model!.id!,
      model: _model!,
      serialNumber:
          _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
      assignedTo:
          _assignedCtrl.text.trim().isEmpty ? null : _assignedCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    DeviceInstance saved;
    if (_isEdit) {
      await db.updateInstance(instance);
      saved = instance;
    } else {
      final id = await db.insertInstance(instance);
      saved = instance.copyWith(id: id);
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Прибор' : 'Новый прибор')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('brand_$_brand'),
                    initialValue: _brand,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Марка'),
                    items: [
                      for (final b in _brands)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _brand = v);
                      _loadModels(v);
                    },
                    validator: (v) => v == null ? 'Выберите марку' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('model_${_model?.id}_${_models.length}'),
                    initialValue: _model?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Модель',
                      helperText: _brand == null
                          ? 'Сначала выберите марку'
                          : null,
                    ),
                    items: [
                      for (final m in _models)
                        DropdownMenuItem(value: m.id, child: Text(m.model)),
                    ],
                    onChanged: _brand == null
                        ? null
                        : (id) => setState(() {
                              _model = _models.firstWhere((m) => m.id == id);
                            }),
                    validator: (v) => v == null ? 'Выберите модель' : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addModel,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Нужной модели нет — добавить свою'),
                    ),
                  ),
                  if (_model != null) ...[
                    const SizedBox(height: 8),
                    _ModelSpecs(model: _model!),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _serialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Серийный / инвентарный номер',
                      helperText: 'Различает одинаковые приборы в списке',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assignedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'За кем закреплён',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Примечание',
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

/// Характеристики выбранной модели — только для чтения.
///
/// Показываются, чтобы человек убедился, что выбрал ту модель. Правятся
/// в справочнике: экземпляр не может отличаться от своей модели.
class _ModelSpecs extends StatelessWidget {
  final DeviceModel model;
  const _ModelSpecs({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Из справочника',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          _row('СКО', '${model.skoMmKm} мм/км · ${model.gostClass}'),
          _row('Допуск угла i по РЭ', model.fieldToleranceLabel),
          if (model.magnification != null)
            _row('Увеличение', '${model.magnification}×'),
          _row('Компенсатор', model.compensatorLabel),
          _row('Исправление угла i', model.adjustmentMethodLabel),
          if (model.minFocusM != null)
            _row('Мин. фокусное', '${model.minFocusM} м'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}
