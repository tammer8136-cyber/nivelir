import 'package:flutter_test/flutter_test.dart';
import 'package:nivelir_app/models/device_instance.dart';
import 'package:nivelir_app/models/device_model.dart';
import 'package:nivelir_app/models/method_preset.dart';
import 'package:nivelir_app/models/reminder.dart';
import 'package:nivelir_app/services/nivelir/algorithms/classification.dart';
import 'package:nivelir_app/services/nivelir/algorithms/collimation.dart';
import 'package:nivelir_app/services/nivelir/algorithms/leveling_class.dart';

void main() {
  group('Расчёт угла i', () {
    test('исправный прибор: равные превышения дают ноль', () {
      final preset = MethodPreset.byId(MethodPreset.workingId);
      final run = Collimation.computeRun(
        geometry: preset.defaultGeometry,
        station1AMm: 1500,
        station1BMm: 1200,
        station2AMm: 1700,
        station2BMm: 1400,
      );
      expect(run.iArcsec, closeTo(0, 1e-9));
      expect(run.hTrueMm, closeTo(300, 1e-9));
    });

    test('рабочий метод: знаменатель 50 м по модулю, знак минус', () {
      final preset = MethodPreset.byId(MethodPreset.workingId);
      // D2 - D1 = (25-75) - 0 = -50. Знак знаменателя часть формулы.
      expect(preset.defaultGeometry.distanceDiffM, closeTo(-50, 1e-9));

      // h1 = 300, h2 = 305 -> x = +5 мм. Дальняя рейка станции 2 (B, 75 м)
      // отсчитана НИЖЕ, чем должна: визирная ось наклонена вниз, i < 0.
      final run = Collimation.computeRun(
        geometry: preset.defaultGeometry,
        station1AMm: 1500,
        station1BMm: 1200,
        station2AMm: 1705,
        station2BMm: 1400,
      );
      expect(run.iArcsec, closeTo(-5 / 50000 * 206265, 1e-6));
    });

    test('способ с разными плечами: знаменатель равен удвоенной базе', () {
      final preset = MethodPreset.byId(MethodPreset.gkinpUnequalId);
      // Станции 4/54 и 54/4 при базе 50 м -> 100 м.
      expect(preset.defaultGeometry.distanceDiffM, closeTo(100, 1e-9));
    });

    test('числовой пример ГКИНП 17-195-99, приложение 4 (способ 3)', () {
      // X = +4,9 деления инварной рейки (0,5 мм) = 2,45 мм при s = 50 м
      // даёт i = +10,1". Здесь X — половина разности превышений станций,
      // поэтому разность превышений равна 4,9 мм.
      const geometry = MethodGeometry(
        station1ToA: 4,
        station1ToB: 54,
        station2ToA: 54,
        station2ToB: 4,
      );
      final run = Collimation.computeRun(
        geometry: geometry,
        station1AMm: 1000,
        station1BMm: 1000,
        station2AMm: 1004,
        station2BMm: 999,
      );
      // разность превышений 4,9 мм -> округляем ввод до целых мм: 5 мм
      expect(run.iArcsec, closeTo(5 / 100000 * 206265, 1e-6));
      expect(run.iArcsec, closeTo(10.3, 0.1));
    });

    test('способ вперёд: плечо 0 не ломает формулу', () {
      final preset = MethodPreset.byId(MethodPreset.gkinpForwardId);
      expect(preset.defaultGeometry.distanceDiffM, closeTo(100, 1e-9));
      expect(preset.usesInstrumentHeight, isTrue);
    });

    test('знак: наклон вверх завышает дальний отсчёт', () {
      final preset = MethodPreset.byId(MethodPreset.workingId);
      // На станции 2 дальняя — рейка B (75 м). При i > 0 её отсчёт завышен,
      // значит h = A − B занижается и x отрицателен. Знаменатель тоже
      // отрицателен, поэтому сам угол i выходит положительным — как и должно
      // быть при наклоне визирной оси вверх.
      final run = Collimation.computeRun(
        geometry: preset.defaultGeometry,
        station1AMm: 1500,
        station1BMm: 1200,
        station2AMm: 1700,
        station2BMm: 1405,
      );
      expect(run.xMm, lessThan(0));
      expect(run.iArcsec, greaterThan(0));
      expect(preset.defaultGeometry.farRodAtStation2IsA, isFalse);
    });

    test('целевой отсчёт считается от дальней рейки, а не через ближнюю', () {
      final preset = MethodPreset.byId(MethodPreset.workingId);
      final run = Collimation.computeRun(
        geometry: preset.defaultGeometry,
        station1AMm: 1500,
        station1BMm: 1200,
        station2AMm: 1700,
        station2BMm: 1405,
      );
      // i = +20,6265" -> iRad = 1e-4. Дальняя рейка B на 75 м, наблюдённый
      // отсчёт 1405, ошибка 1e-4 * 75000 = 7,5 мм -> цель 1397,5.
      expect(run.farTheoreticalMm, closeTo(1397.5, 1e-6));

      // Контроль: после поворота сетки нитей на -i оба отсчёта уменьшатся
      // на i*s, и превышение станции 2 станет равным истинному.
      const iRad = 1e-4;
      const aAdjusted = 1700 - iRad * 25000;
      expect(aAdjusted - run.farTheoreticalMm, closeTo(run.hTrueMm, 1e-6));
    });

    test('свод по приёмам: среднее и размах', () {
      final preset = MethodPreset.byId(MethodPreset.workingId);
      final runs = [
        Collimation.computeRun(
          geometry: preset.defaultGeometry,
          station1AMm: 1500,
          station1BMm: 1200,
          station2AMm: 1701,
          station2BMm: 1400,
        ),
        Collimation.computeRun(
          geometry: preset.defaultGeometry,
          station1AMm: 1500,
          station1BMm: 1200,
          station2AMm: 1703,
          station2BMm: 1400,
        ),
      ];
      final result = Collimation.summarize(
        runs: runs,
        geometry: preset.defaultGeometry,
        toleranceArcsec: DeviceClassification.toleranceArcsec,
        runSpreadLimitArcsec: 5.0,
      );
      expect(result.iArcsec, closeTo(-2 / 50000 * 206265, 1e-6));
      expect(result.spreadArcsec, closeTo(2 / 50000 * 206265, 1e-6));
      expect(result.runCount, 2);
    });
  });

  group('Результат знает про оба основания', () {
    CollimationResult build(int runCount) {
      final preset = MethodPreset.byId(MethodPreset.workingId);
      return Collimation.summarize(
        geometry: preset.defaultGeometry,
        runs: [
          for (var i = 0; i < runCount; i++)
            Collimation.computeRun(
              geometry: preset.defaultGeometry,
              station1AMm: 1500,
              station1BMm: 1200,
              station2AMm: 1701 + i,
              station2BMm: 1400,
            ),
        ],
        toleranceArcsec: 10,
        runSpreadLimitArcsec: 5,
      );
    }

    test('два приёма проходят по приложению 9', () {
      final r = build(2);
      expect(r.runCountMeetsNorm, isTrue);
      expect(r.runsNorm?.id, RunsNorm.laboratoryId);
    });

    test('три приёма проходят по 17-195-99', () {
      expect(build(3).runsNorm?.id, RunsNorm.technologicalId);
    });

    test('один приём не проходит ни по одному', () {
      final r = build(1);
      expect(r.runCountMeetsNorm, isFalse);
      expect(r.runsNorm, isNull);
    });
  });

  group('Основание для числа приёмов', () {
    test('оба документа доступны и дают разный минимум', () {
      expect(RunsNorm.all.length, 2);
      expect(RunsNorm.technological.minRuns, 3);
      expect(RunsNorm.laboratory.minRuns, 2);
    });

    test('два приёма проходят по прил. 9, но не по 17-195-99', () {
      expect(RunsNorm.laboratory.isSatisfiedBy(2), isTrue);
      expect(RunsNorm.technological.isSatisfiedBy(2), isFalse);
    });

    test('один приём не проходит ни по одному основанию', () {
      for (final norm in RunsNorm.all) {
        expect(norm.isSatisfiedBy(1), isFalse, reason: norm.source);
      }
    });

    test('неизвестный идентификатор откатывается на строгое основание', () {
      expect(RunsNorm.byId('нет такого').id, RunsNorm.technologicalId);
      expect(RunsNorm.byId(null).minRuns, 3);
      expect(RunsNorm.byIdOrNull('нет такого'), isNull);
    });

    test('основание выводится из числа приёмов, а не выбирается', () {
      expect(RunsNorm.strictestSatisfiedBy(3)?.id, RunsNorm.technologicalId);
      expect(RunsNorm.strictestSatisfiedBy(5)?.id, RunsNorm.technologicalId);
      expect(RunsNorm.strictestSatisfiedBy(2)?.id, RunsNorm.laboratoryId);
      expect(RunsNorm.strictestSatisfiedBy(1), isNull);
      expect(RunsNorm.idForRunCount(1), RunsNorm.noneId);
    });
  });

  group('Способ исправления угла i (прил. 9) — свойство модели', () {
    const base = DeviceModel(brand: 'Тест', model: 'X', skoMmKm: 2.0);

    test('не указан — юстировка в поле не запрещена', () {
      expect(base.adjustmentInFieldForbidden, isFalse);
      expect(base.adjustmentMethodLabel, 'не указан');
    });

    test('workshop запрещает юстировку в поле', () {
      const d = DeviceModel(
        brand: 'Carl Zeiss',
        model: 'Ni-002',
        skoMmKm: 0.5,
        adjustmentMethod: 'workshop',
      );
      expect(d.adjustmentInFieldForbidden, isTrue);
    });

    test('wedge не запрещает юстировку, но меняет способ', () {
      const d = DeviceModel(
        brand: 'Тест',
        model: 'Н-05',
        skoMmKm: 0.5,
        adjustmentMethod: 'wedge',
      );
      expect(d.adjustmentInFieldForbidden, isFalse);
      expect(d.adjustmentMethodLabel, contains('защитного стекла'));
    });

    test('экземпляр делегирует характеристики в модель', () {
      const m = DeviceModel(
        brand: 'Тест',
        model: 'Н-05',
        skoMmKm: 0.5,
        magnification: 31,
        adjustmentMethod: 'wedge',
      );
      const inst = DeviceInstance(
        modelId: 1,
        model: m,
        serialNumber: '12345',
        assignedTo: 'Иванов',
      );
      expect(inst.skoMmKm, 0.5);
      expect(inst.magnification, 31);
      expect(inst.adjustmentMethod, 'wedge');
      expect(inst.gostClass, m.gostClass);
      expect(inst.displayName, contains('12345'));
      expect(inst.assignmentLabel, contains('Иванов'));
    });

    test('экземпляр без номера показывает просто марку и модель', () {
      const inst = DeviceInstance(
        modelId: 1,
        model: DeviceModel(brand: 'Тест', model: 'X', skoMmKm: 2.0),
      );
      expect(inst.displayName, 'Тест X');
      expect(inst.assignmentLabel, isNull);
    });

    test('экземпляр переживает сериализацию в БД', () {
      const m = DeviceModel(brand: 'Тест', model: 'X', skoMmKm: 2.0, id: 7);
      const inst = DeviceInstance(
        id: 3,
        modelId: 7,
        model: m,
        serialNumber: '999',
        assignedTo: 'Петров',
        notes: 'в ремонте',
      );
      final restored = DeviceInstance.fromMap(inst.toMap(), model: m);
      expect(restored.modelId, 7);
      expect(restored.serialNumber, '999');
      expect(restored.assignedTo, 'Петров');
      expect(restored.notes, 'в ремонте');
      // Модель в карту экземпляра не пишется — она живёт в своей таблице.
      expect(inst.toMap().containsKey('sko_mm_km'), isFalse);
    });

    test('способ переживает сериализацию в БД', () {
      const d = DeviceModel(
        brand: 'Тест',
        model: 'X',
        skoMmKm: 2.0,
        adjustmentMethod: 'wedge',
      );
      final restored = DeviceModel.fromMap(d.toMap());
      expect(restored.adjustmentMethod, 'wedge');
    });
  });

  group('Периодичность поверки (ГКИНП 03-010-03, п. 21.4.2)', () {
    test('интервал 15 дней не выражается через недели или месяцы', () {
      // Проверка того, что пресет обязан жить в единице "день":
      // 15 не делится на 7 и не равно месяцу.
      expect(VerificationSchedule.steadyIntervalDays % 7, isNot(0));
      expect(VerificationSchedule.dailyDays, 7);
    });

    test('ежедневный режим: следующее срабатывание завтра или сегодня позже',
        () {
      const r = Reminder(
        deviceId: 1,
        enabled: true,
        intervalKind: 'day',
        intervalCount: 1,
        hour: 9,
      );
      final from = DateTime(2026, 3, 10, 12, 0);
      final next = r.computeNextFire(from);
      expect(next, DateTime(2026, 3, 11, 9, 0));
    });

    test('режим 15 дней отсчитывает ровно 15 суток', () {
      const r = Reminder(
        deviceId: 1,
        enabled: true,
        intervalKind: 'day',
        intervalCount: VerificationSchedule.steadyIntervalDays,
        hour: 9,
      );
      final from = DateTime(2026, 3, 10, 12, 0);
      final next = r.computeNextFire(from);
      expect(next.difference(DateTime(2026, 3, 10, 9, 0)).inDays, 15);
    });
  });

  group('Класс нивелирования в мастере', () {
    test('неизвестное увеличение не даёт допуска ни к какому классу', () {
      expect(
        LevelingClass.highestAdmittedClass(skoMmKm: 0.3, magnification: null),
        isNull,
      );
    });

    test('прибор проходит по СКО, но не по увеличению — не допущен', () {
      // СКП 0,5 мм/км проходит по I классу, но 24× меньше требуемых 40×.
      final check = LevelingClass.check(
        levelingClass: 1,
        skoMmKm: 0.5,
        magnification: 24,
      );
      expect(check.skoOk, isTrue);
      expect(check.magnificationOk, isFalse);
      expect(check.admitted, isFalse);
      // По III классу тот же прибор проходит.
      expect(
        LevelingClass.highestAdmittedClass(skoMmKm: 0.5, magnification: 24),
        3,
      );
    });
  });

  group('Классификация по ГОСТ 10528-90', () {
    test('компенсаторная колонка: 0,3 / 2,0 / 5,0', () {
      expect(DeviceClassification.gostClass(0.3), 'высокоточные');
      expect(DeviceClassification.gostClass(0.7), 'точные');
      expect(DeviceClassification.gostClass(2.0), 'точные');
      // По уровенной колонке это были бы "точные" — здесь технические.
      expect(DeviceClassification.gostClass(2.5), 'технические');
      expect(DeviceClassification.gostClass(3.0), 'технические');
    });

    test('допуск угла i — 10 секунд для всех групп', () {
      expect(DeviceClassification.toleranceArcsec, 10.0);
    });

    test('предел расхождения приёмов: 3 и 5 секунд', () {
      expect(DeviceClassification.runSpreadLimitArcsec(0.3), 3.0);
      expect(DeviceClassification.runSpreadLimitArcsec(1.5), 5.0);
      expect(DeviceClassification.runSpreadLimitArcsec(5.0), 5.0);
    });
  });

  group('Допуск к классу нивелирования (ГКИНП 03-010-03, табл. 4)', () {
    test('СКО и увеличение проверяются совместно', () {
      // Sokkia B30: СКО 1,5 проходит по II классу, но 28x < 40x.
      final check = LevelingClass.check(
        levelingClass: 2,
        skoMmKm: 1.5,
        magnification: 28,
      );
      expect(check.skoOk, isTrue);
      expect(check.magnificationOk, isFalse);
      expect(check.admitted, isFalse);

      expect(
        LevelingClass.highestAdmittedClass(skoMmKm: 1.5, magnification: 28),
        3,
      );
    });

    test('55-кратный прибор с СКО 0,7 допущен ко II классу', () {
      expect(
        LevelingClass.highestAdmittedClass(skoMmKm: 0.7, magnification: 55),
        2,
      );
    });

    test('I класс требует СКО не более 0,5 мм/км', () {
      expect(
        LevelingClass.highestAdmittedClass(skoMmKm: 0.7, magnification: 40),
        2,
      );
      expect(
        LevelingClass.highestAdmittedClass(skoMmKm: 0.5, magnification: 40),
        1,
      );
    });

    test('неизвестное увеличение не проходит молча', () {
      final check = LevelingClass.check(levelingClass: 4, skoMmKm: 2.0);
      expect(check.skoOk, isTrue);
      expect(check.magnificationKnown, isFalse);
      expect(check.admitted, isFalse);
    });
  });
}
