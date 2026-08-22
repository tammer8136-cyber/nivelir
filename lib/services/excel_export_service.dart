import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/verification.dart';
import '../services/nivelir/algorithms/leveling_class.dart';
import '../utils/units.dart';

/// Журнал поверок в .xlsx — для табличного учёта, отдельно от PDF-протокола.
/// Пакет `excel` (базовый, не excel_plus): объём данных здесь на порядки
/// меньше того, где разница в производительности заметна.
class ExcelExportService {
  static const List<String> _headers = [
    'Дата',
    'Прибор',
    'Метод',
    'Класс нивел.',
    'Поверку выполнил',
    'Основание приёмов',
    'Приём',
    'Ст.1 рейка A',
    'Ст.1 рейка B',
    'Ст.2 рейка A',
    'Ст.2 рейка B',
    'i приёма, ″',
    'i среднее, ″',
    'Размах, ″',
    'Предел размаха, ″',
    'Допуск, ″',
    'Знаменатель, м',
    'Превышение A−B',
    'Вердикт',
    'Юстировка',
    'Примечания',
  ];

  static Future<File> buildFile({
    required List<Verification> verifications,
    required bool isMillimeters,
    String sheetName = 'Поверки',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheet = excel[sheetName];
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.delete(defaultSheet);
    }

    final unit = isMillimeters ? 'мм' : 'м';
    sheet.appendRow([
      TextCellValue('Журнал поверок нивелиров (отсчёты в $unit)'),
    ]);
    sheet.appendRow([
      TextCellValue('Допуск угла i — ГОСТ 10528-90 п. 2.3 и ГКИНП 17-195-99 п. 4.2.5. '
          'Предел расхождения приёмов — ГКИНП 03-010-03, приложение 9.'),
    ]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow(_headers.map(TextCellValue.new).toList());

    double conv(num mm) => isMillimeters ? mm.toDouble() : mm / 1000.0;
    double r2(double v) => double.parse(v.toStringAsFixed(2));

    for (final v in verifications) {
      // Одна строка на приём: так журнал остаётся плоской таблицей,
      // пригодной для сводных.
      final runs = v.runs.isEmpty ? [null] : v.runs;
      for (final run in runs) {
        sheet.appendRow([
          TextCellValue(Units.dateTime.format(v.createdAt)),
          TextCellValue(v.deviceLabel),
          TextCellValue(v.preset.title),
          TextCellValue(v.levelingClass == null
              ? '—'
              : LevelingClass.roman(v.levelingClass!)),
          TextCellValue(v.performedBy ?? '—'),
          TextCellValue(v.runsNorm?.source ?? 'ниже нормы'),
          run == null ? TextCellValue('—') : IntCellValue(run.runIndex),
          run == null
              ? TextCellValue('—')
              : DoubleCellValue(conv(run.station1AMm)),
          run == null
              ? TextCellValue('—')
              : DoubleCellValue(conv(run.station1BMm)),
          run == null
              ? TextCellValue('—')
              : DoubleCellValue(conv(run.station2AMm)),
          run == null
              ? TextCellValue('—')
              : DoubleCellValue(conv(run.station2BMm)),
          run == null
              ? TextCellValue('—')
              : DoubleCellValue(r2(run.iArcsec)),
          DoubleCellValue(r2(v.iAngleArcsec)),
          v.spreadArcsec == null
              ? TextCellValue('—')
              : DoubleCellValue(r2(v.spreadArcsec!)),
          DoubleCellValue(v.spreadLimitArcsec),
          DoubleCellValue(v.toleranceArcsecSnapshot),
          DoubleCellValue(v.distanceDiffM.abs()),
          DoubleCellValue(conv(v.hTrueMm)),
          TextCellValue(v.isPass ? 'в допуске' : 'вне допуска'),
          TextCellValue(v.adjusted ? 'выполнена' : '—'),
          TextCellValue(v.notes ?? ''),
        ]);
      }
    }

    final bytes = excel.encode();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/zhurnal_poverok_$stamp.xlsx');
    await file.writeAsBytes(bytes ?? <int>[]);
    return file;
  }

  static Future<void> shareJournal({
    required List<Verification> verifications,
    required bool isMillimeters,
  }) async {
    final file = await buildFile(
      verifications: verifications,
      isMillimeters: isMillimeters,
    );
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Журнал поверок нивелиров',
    );
  }
}
