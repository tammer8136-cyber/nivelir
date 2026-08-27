import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/device_instance.dart';
import '../models/verification.dart';
import '../services/nivelir/algorithms/classification.dart';
import '../services/nivelir/algorithms/leveling_class.dart';
import '../utils/units.dart';

/// Протокол поверки в PDF. Загрузка шрифтов и общая структура — из
/// export_service.dart донора: кириллица в PDF требует TTF из assets.
class ExportService {
  static Future<_Fonts> _loadFonts() async {
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      return _Fonts(pw.Font.ttf(regular), pw.Font.ttf(bold));
    } catch (_) {
      return _Fonts(
        await PdfGoogleFonts.robotoRegular(),
        await PdfGoogleFonts.robotoBold(),
      );
    }
  }

  static Future<pw.Document> buildProtocol({
    required Verification v,
    DeviceInstance? device,
    required bool isMillimeters,
  }) async {
    final fonts = await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        build: (context) => [
          pw.Text(
            'Протокол поверки главного условия нивелира',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Определение угла i (ГОСТ 10528-90, ГКИНП (ГНТА) 17-195-99)',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Дата поверки: ${Units.dateTime.format(v.createdAt)}'),
          if (v.performedBy != null && v.performedBy!.isNotEmpty)
            pw.Text('Поверку выполнил: ${v.performedBy}'),
          pw.SizedBox(height: 16),

          _section('ПРИБОР', [
            _row('Марка, модель', v.deviceLabel),
            if (device != null) _row('СКО', '${device.skoMmKm} мм/км'),
            if (device != null)
              _row('Класс (ГОСТ 10528-90)',
                  '${device.gostClass} (${device.designationHint})'),
            if (device?.magnification != null)
              _row('Увеличение', '${device!.magnification}×'),
            if (device?.compensatorType != null)
              _row('Компенсатор', device!.compensatorLabel),
            if (device != null)
              _row('Допуск угла i по РЭ', device.fieldToleranceLabel),
          ]),
          pw.SizedBox(height: 12),

          _section('МЕТОД', [
            _row('Схема', v.preset.title),
            _row('Станция 1: до реек A / B',
                '${Units.meters(v.geometry.station1ToA)} / '
                '${Units.meters(v.geometry.station1ToB)}'),
            _row('Станция 2: до реек A / B',
                '${Units.meters(v.geometry.station2ToA)} / '
                '${Units.meters(v.geometry.station2ToB)}'),
            _row('Знаменатель формулы', Units.meters(v.distanceDiffM.abs())),
            _row(
              'Число приёмов',
              v.runsNorm == null
                  ? '${v.runCount} — НИЖЕ НОРМЫ '
                      '(минимум ${RunsNorm.laboratory.minRuns} по '
                      '${RunsNorm.laboratory.source})'
                  : '${v.runCount} — соответствует '
                      '${v.runsNorm!.source}',
            ),
            _row(
              'Класс нивелирования',
              v.levelingClass == null
                  ? 'не задан'
                  : '${LevelingClass.roman(v.levelingClass!)} '
                      '(ГКИНП 03-010-03, табл. 4)',
            ),
          ]),
          pw.SizedBox(height: 12),

          pw.Text('ОТСЧЁТЫ',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('Приём'),
                  _cell('Ст.1 рейка A'),
                  _cell('Ст.1 рейка B'),
                  _cell('Ст.2 рейка A'),
                  _cell('Ст.2 рейка B'),
                  _cell('Угол i'),
                ],
              ),
              for (final run in v.runs)
                pw.TableRow(children: [
                  _cell('${run.runIndex}'),
                  _cell(Units.reading(run.station1AMm, isMillimeters)),
                  _cell(Units.reading(run.station1BMm, isMillimeters)),
                  _cell(Units.reading(run.station2AMm, isMillimeters)),
                  _cell(Units.reading(run.station2BMm, isMillimeters)),
                  _cell(Units.signedArcsec(run.iArcsec)),
                ]),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Отсчёты в ${isMillimeters ? "миллиметрах" : "метрах"}. '
            'Рейки A и B — неподвижные точки створа.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),

          _section('РЕЗУЛЬТАТ', [
            _row('Истинное превышение A − B',
                Units.signed(v.hTrueMm, isMillimeters)),
            _row('Угол i (среднее по приёмам)',
                Units.signedArcsec(v.iAngleArcsec)),
            if (v.spreadArcsec != null)
              _row('Расхождение приёмов',
                  '${Units.arcsec(v.spreadArcsec!)} при ориентире '
                  '${Units.arcsec(v.spreadLimitArcsec)} (справочно)'),
            if (v.comparedInMillimetres)
              _row('Расхождение (a2−b2)−(a1−b1)',
                  '${v.deltaMm.toStringAsFixed(1)} мм'),
            _row('Допуск', v.toleranceLabel),
            _row('Вердикт',
                v.isPass ? 'В ДОПУСКЕ' : 'ВНЕ ДОПУСКА — требуется юстировка'),
            if (v.anomalyFlagged)
              _row('Примечание',
                  'Значение многократно превышает допуск — проверьте отсчёты'),
          ]),
          pw.SizedBox(height: 12),

          // Основание вердикта. Единой нормы на полевое определение угла i
          // не существует, поэтому протокол не ссылается на норму, а
          // называет источник каждого числа.
          _section('ОСНОВАНИЕ ДОПУСКА', [
            _row('Способ', v.toleranceBasisLabel),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(v.toleranceProvenanceSnapshot,
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ]),

          if (v.adjusted && v.farTheoreticalMm != null) ...[
            pw.SizedBox(height: 12),
            _section('ЮСТИРОВКА', [
              _row('Теоретический отсчёт по дальней рейке',
                  Units.readingWithUnit(v.farTheoreticalMm!, isMillimeters)),
              _row('Выполнена', 'да, сеткой нитей'),
            ]),
          ],

          if (v.notes != null && v.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Примечания: ${v.notes}'),
          ],

          pw.SizedBox(height: 36),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Исполнитель ______________________'),
              pw.Text('Подпись ______________'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Печать / системный диалог сохранения.
  static Future<void> printProtocol({
    required Verification v,
    DeviceInstance? device,
    required bool isMillimeters,
  }) async {
    final pdf = await buildProtocol(
      v: v,
      device: device,
      isMillimeters: isMillimeters,
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Сохранение во временный файл и шаринг.
  static Future<void> shareProtocol({
    required Verification v,
    DeviceInstance? device,
    required bool isMillimeters,
  }) async {
    final pdf = await buildProtocol(
      v: v,
      device: device,
      isMillimeters: isMillimeters,
    );
    final dir = await getTemporaryDirectory();
    final stamp = v.createdAt.toIso8601String().substring(0, 10);
    final file = File('${dir.path}/protokol_poverki_$stamp.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Протокол поверки нивелира',
    );
  }

  static pw.Widget _section(String title, List<pw.Widget> rows) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 210,
            child: pw.Text('$label:',
                style: const pw.TextStyle(color: PdfColors.grey800)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}

class _Fonts {
  final pw.Font regular;
  final pw.Font bold;
  const _Fonts(this.regular, this.bold);
}
