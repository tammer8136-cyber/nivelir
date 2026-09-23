import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_instance.dart';
import '../models/verification.dart';
import '../services/nivelir/algorithms/leveling_class.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/export_service.dart';
import '../state/app_settings.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';

class VerificationDetailScreen extends StatefulWidget {
  final Verification verification;
  const VerificationDetailScreen({super.key, required this.verification});

  @override
  State<VerificationDetailScreen> createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends State<VerificationDetailScreen> {
  Verification? _full;
  DeviceInstance? _device;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// В списке приёмы не загружаются — подтягиваем их при открытии протокола.
  Future<void> _load() async {
    final db = context.read<DatabaseService>();
    final id = widget.verification.id;
    final full = id == null ? widget.verification : await db.getVerification(id);
    final device = await db.getInstance(widget.verification.deviceId);
    if (!mounted) return;
    setState(() {
      _full = full ?? widget.verification;
      _device = device;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить протокол?'),
        content: const Text('Запись будет удалена без возможности вернуть.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = context.read<DatabaseService>();
    await db.deleteVerification(widget.verification.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = _full;
    final isMm = context.watch<AppSettings>().isMillimeters;

    if (v == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final color = v.isPass ? AppTheme.success : AppTheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Протокол'),
        actions: [
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => ExportService.shareProtocol(
              v: v,
              device: _device,
              isMillimeters: isMm,
            ),
          ),
          IconButton(
            tooltip: 'Excel',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: () => ExcelExportService.shareJournal(
              verifications: [v],
              isMillimeters: isMm,
            ),
          ),
          IconButton(
            tooltip: 'Удалить',
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
                children: [
                  Text(v.deviceLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Units.dateTime.format(v.createdAt),
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  Text(
                    Units.signedArcsec(v.iAngleArcsec),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                  Text(
                    v.isPass
                        ? 'в допуске ${Units.arcsec(v.toleranceArcsecSnapshot)}'
                        : 'вне допуска ${Units.arcsec(v.toleranceArcsecSnapshot)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('МЕТОД'),
                  _row('Схема', v.preset.title),
                  _row('Станция 1',
                      'A ${Units.meters(v.geometry.station1ToA)} · '
                      'B ${Units.meters(v.geometry.station1ToB)}'),
                  _row('Станция 2',
                      'A ${Units.meters(v.geometry.station2ToA)} · '
                      'B ${Units.meters(v.geometry.station2ToB)}'),
                  _row('Знаменатель',
                      Units.meters(v.distanceDiffM.abs())),
                  _row(
                    'Приёмов',
                    '${v.runCount}${v.meetsRunsNorm ? '' : ' — экспресс-проверка'}',
                  ),
                  _row('Число приёмов задал', v.runsNorm?.source ?? 'исполнитель'),
                  if (v.performedBy != null && v.performedBy!.isNotEmpty)
                    _row('Поверку выполнил', v.performedBy!),
                  _row(
                    'Класс нивелирования',
                    v.levelingClass == null
                        ? 'не задан'
                        : LevelingClass.roman(v.levelingClass!),
                  ),
                  if (v.spreadArcsec != null)
                    _row('Размах по приёмам',
                        '${Units.arcsec(v.spreadArcsec!)} '
                        '(предел ${Units.arcsec(v.spreadLimitArcsec)})'),
                  _row('Истинное превышение A − B',
                      Units.signed(v.hTrueMm, isMm)),
                  if (v.adjusted && v.farTheoreticalMm != null)
                    _row('Юстировка',
                        'выполнена, целевой отсчёт '
                        '${Units.readingWithUnit(v.farTheoreticalMm!, isMm)}'),
                ],
              ),
            ),
          ),
          if (v.runs.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('ОТСЧЁТЫ'),
                    for (final run in v.runs) ...[
                      if (v.runs.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text('Приём ${run.runIndex} · '
                              'i = ${Units.signedArcsec(run.iArcsec)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary)),
                        ),
                      _row('Ст. 1: A / B',
                          '${Units.reading(run.station1AMm, isMm)} / '
                          '${Units.readingWithUnit(run.station1BMm, isMm)}'),
                      _row('Ст. 2: A / B',
                          '${Units.reading(run.station2AMm, isMm)} / '
                          '${Units.readingWithUnit(run.station2BMm, isMm)}'),
                    ],
                  ],
                ),
              ),
            ),
          if (v.notes != null && v.notes!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('ПРИМЕЧАНИЯ'),
                    Text(v.notes!, style: const TextStyle(height: 1.4)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary)),
    );
  }
}
