import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_model.dart';
import '../../services/database_service.dart';
import '../../services/nivelir/algorithms/leveling_class.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import 'model_form_screen.dart';

/// Карточка МОДЕЛИ: характеристики, допуск к классам работ, справка.
class ModelDetailScreen extends StatefulWidget {
  final DeviceModel model;
  const ModelDetailScreen({super.key, required this.model});

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  late DeviceModel _model;
  int _instanceCount = 0;

  @override
  void initState() {
    super.initState();
    _model = widget.model;
    _countInstances();
  }

  Future<void> _countInstances() async {
    if (_model.id == null) return;
    final count =
        await context.read<DatabaseService>().countInstancesOfModel(_model.id!);
    if (mounted) setState(() => _instanceCount = count);
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<DeviceModel>(
      context,
      MaterialPageRoute(builder: (_) => ModelFormScreen(model: _model)),
    );
    if (updated != null && mounted) setState(() => _model = updated);
  }

  Future<void> _delete() async {
    final db = context.read<DatabaseService>();

    if (_instanceCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Модель используется: приборов — $_instanceCount. Удалите '
            'сначала их, иначе приборы останутся без характеристик.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить модель?'),
        content: Text('«${_model.title}» будет удалена из справочника.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await db.deleteModel(_model.id!);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Модель используется приборами')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _model;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.title),
        actions: [
          if (!d.isCatalog) ...[
            IconButton(icon: const Icon(Icons.edit), onPressed: _edit),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Способ юстировки',
              onPressed: _edit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (d.isCatalog)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Модель из справочника. Характеристики не редактируются — '
                'правится только способ исправления угла i.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ХАРАКТЕРИСТИКИ',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  _row('СКО', '${d.skoMmKm} мм/км'),
                  _row('Класс по ГОСТ 10528-90', d.gostClass),
                  _row('Допуск угла i', Units.arcsec(d.toleranceArcsec)),
                  _row('Дрейф угла i',
                      '${Units.arcsec(d.tempDriftArcsecPerC)} на 1 °С'),
                  if (d.magnification != null)
                    _row('Увеличение', '${d.magnification}×'),
                  _row('Компенсатор', d.compensatorLabel),
                  if (d.minFocusM != null)
                    _row('Мин. фокусное расстояние', '${d.minFocusM} м'),
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
              child: _admissionSection(d),
            ),
          ),
          if (d.referenceInfo != null && d.referenceInfo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('СПРАВОЧНАЯ ИНФОРМАЦИЯ',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text(d.referenceInfo!,
                        style: const TextStyle(height: 1.4)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _instanceCount == 0
                ? 'Приборов этой модели не заведено.'
                : 'Заведено приборов этой модели: $_instanceCount.',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Допуск прибора к классам работ по ГКИНП 03-010-03, п. 21.1, табл. 4.
  ///
  /// Свойство МОДЕЛИ: пригодность выводится из СКП и увеличения. На вердикт
  /// поверки не влияет — угол i табл. 4 не нормирует, порог 10″ берётся из
  /// ГОСТ 10528-90, п. 2.3.
  Widget _admissionSection(DeviceModel d) {
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
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
                  : 'По табл. 4 модель не проходит ни по одному классу.'
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
