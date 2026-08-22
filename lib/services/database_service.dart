import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/device.dart';
import '../models/reminder.dart';
import '../models/verification.dart';

/// Слой данных. Структура повторяет database_service.dart донора
/// (drainage_app): один сервис, прямые запросы к sqflite, без ORM.
class DatabaseService {
  static Database? _database;

  static const String catalogAsset = 'assets/devices_catalog.json';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await init();
    return _database!;
  }

  Future<Database> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nivelir.db');

    final db = await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE verifications ADD COLUMN leveling_class INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE devices ADD COLUMN adjustment_method TEXT',
          );
        }
        if (oldVersion < 4) {
          // Существующие протоколы набирались по трёхприёмной норме.
          await db.execute(
            "ALTER TABLE verifications ADD COLUMN runs_norm TEXT "
            "NOT NULL DEFAULT 'gkinp_17_195_99'",
          );
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            brand TEXT NOT NULL,
            model TEXT NOT NULL,
            serial_number TEXT,
            magnification INTEGER,
            sko_mm_km REAL NOT NULL,
            compensator_type TEXT,
            min_focus_m REAL,
            min_focus_note TEXT,

            -- Способ исправления угла i (ГКИНП 03-010-03, прил. 9):
            -- reticle | wedge | workshop | manual | NULL (не указан).
            adjustment_method TEXT,

            gost_class TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'custom'
          )
        ''');

        // Допуск угла i (10" по ГОСТ 10528-90) в таблице приборов не хранится:
        // он одинаков для всех групп и выводится из класса в коде. В таблице
        // поверок снимок допуска остаётся — на случай пересмотра норматива.
        await db.execute('''
          CREATE TABLE verifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            device_label TEXT NOT NULL,
            created_at TEXT NOT NULL,

            method_preset TEXT NOT NULL,
            s1_a_m REAL NOT NULL,
            s1_b_m REAL NOT NULL,
            s2_a_m REAL NOT NULL,
            s2_b_m REAL NOT NULL,
            distance_diff_m REAL NOT NULL,

            run_count INTEGER NOT NULL DEFAULT 1,
            h_true_mm REAL NOT NULL,
            i_angle_arcsec REAL NOT NULL,
            spread_arcsec REAL,
            spread_limit_arcsec REAL NOT NULL,

            tolerance_arcsec_snapshot REAL NOT NULL,
            verdict TEXT NOT NULL,
            anomaly_flagged INTEGER NOT NULL DEFAULT 0,

            adjusted INTEGER NOT NULL DEFAULT 0,
            far_theoretical_mm REAL,

            -- Класс нивелирования по ГКИНП 03-010-03, табл. 4 (1..4).
            -- NULL — поверка без привязки к классу работ.
            leveling_class INTEGER,

            -- Основание для числа приёмов: gkinp_17_195_99 (3 приёма) или
            -- gkinp_03_010_03 (2 приёма). См. RunsNorm.
            runs_norm TEXT NOT NULL DEFAULT 'gkinp_17_195_99',

            notes TEXT
          )
        ''');

        // Отсчёты по приёмам. Один приём — обычный случай, три и больше —
        // режим по ГКИНП. Отсчёты именуются по рейкам A и B, а не по
        // "ближней/дальней": в способе с разными плечами рейки меняются
        // ролями между станциями.
        await db.execute('''
          CREATE TABLE verification_runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verification_id INTEGER NOT NULL,
            run_index INTEGER NOT NULL,
            station1_a_mm INTEGER NOT NULL,
            station1_b_mm INTEGER NOT NULL,
            station2_a_mm INTEGER NOT NULL,
            station2_b_mm INTEGER NOT NULL,
            i_arcsec REAL NOT NULL,
            FOREIGN KEY (verification_id)
              REFERENCES verifications(id) ON DELETE CASCADE
          )
        ''');

        // Поверки НЕ удаляются вместе с прибором: удаление custom-прибора
        // разрешено без ограничений, а протоколы остаются в истории —
        // поэтому device_label денормализован, а FK на devices намеренно нет.
        await db.execute(
          'CREATE INDEX idx_verifications_device ON verifications(device_id)',
        );
        await db.execute(
          'CREATE INDEX idx_runs_verification ON verification_runs(verification_id)',
        );

        await db.execute('''
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL UNIQUE,
            enabled INTEGER NOT NULL DEFAULT 0,
            interval_kind TEXT NOT NULL DEFAULT 'month',
            interval_count INTEGER NOT NULL DEFAULT 6,
            day_of_week INTEGER,
            day_of_month INTEGER,
            month_of_year INTEGER,
            hour INTEGER NOT NULL DEFAULT 9,
            minute INTEGER NOT NULL DEFAULT 0,
            next_fire_at TEXT,
            FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
          )
        ''');
      },
    );

    await _seedCatalogIfNeeded(db);
    return db;
  }

  // ==========================================================================
  // СИД КАТАЛОГА
  // ==========================================================================

  /// Каталог засевается один раз при первом запуске. Класс НЕ берётся из
  /// JSON — считается из СКО через Device, чтобы правило жило в одном месте.
  /// В JSON поля gost_class и i_angle_tolerance_arcsec остались от прежней
  /// (уровенной) классификации и сознательно игнорируются.
  Future<void> _seedCatalogIfNeeded(Database db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM devices WHERE source = 'catalog'"),
    );
    if (existing != null && existing > 0) return;

    try {
      final raw = await rootBundle.loadString(catalogAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['devices'] as List).cast<Map<String, dynamic>>();

      final batch = db.batch();
      for (final item in items) {
        final device = Device.fromMap({...item, 'source': 'catalog'});
        batch.insert('devices', device.toMap());
      }
      await batch.commit(noResult: true);
    } catch (e) {
      // Отсутствие ассета не должно ронять запуск — справочник просто пуст,
      // пользователь добавит свои приборы вручную.
      // ignore: avoid_print
      print('Не удалось загрузить каталог приборов: $e');
    }
  }

  // ==========================================================================
  // ПРИБОРЫ
  // ==========================================================================

  Future<List<Device>> getDevices({String? search}) async {
    final db = await database;
    final hasSearch = search != null && search.isNotEmpty;
    final rows = await db.query(
      'devices',
      where: hasSearch
          ? 'brand LIKE ? OR model LIKE ? OR serial_number LIKE ?'
          : null,
      whereArgs: hasSearch ? ['%$search%', '%$search%', '%$search%'] : null,
      orderBy: 'source ASC, brand ASC, model ASC',
    );
    return rows.map(Device.fromMap).toList();
  }

  Future<Device?> getDevice(int id) async {
    final db = await database;
    final rows = await db.query('devices', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Device.fromMap(rows.first);
  }

  Future<int> insertDevice(Device device) async {
    final db = await database;
    return db.insert('devices', device.toMap());
  }

  Future<int> updateDevice(Device device) async {
    final db = await database;
    return db.update(
      'devices',
      device.toMap(),
      where: 'id = ?',
      whereArgs: [device.id],
    );
  }

  /// Удаление без ограничений и подтверждений — даже при наличии истории.
  Future<void> deleteDevice(int id) async {
    final db = await database;
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================================
  // ПОВЕРКИ
  // ==========================================================================

  Future<int> insertVerification(Verification v) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('verifications', v.toMap());
      for (final run in v.runs) {
        await txn.insert('verification_runs', run.toMap(id));
      }
      return id;
    });
  }

  /// Обновление протокола: приёмы переписываются целиком — их немного,
  /// а точечная синхронизация здесь не стоит сложности.
  Future<void> updateVerification(Verification v) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'verifications',
        v.toMap(),
        where: 'id = ?',
        whereArgs: [v.id],
      );
      await txn.delete(
        'verification_runs',
        where: 'verification_id = ?',
        whereArgs: [v.id],
      );
      for (final run in v.runs) {
        await txn.insert('verification_runs', run.toMap(v.id!));
      }
    });
  }

  Future<List<Verification>> getVerifications({
    int? deviceId,
    int? limit,
    bool withRuns = false,
  }) async {
    final db = await database;
    final rows = await db.query(
      'verifications',
      where: deviceId == null ? null : 'device_id = ?',
      whereArgs: deviceId == null ? null : [deviceId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final result = <Verification>[];
    for (final row in rows) {
      final runs =
          withRuns ? await _loadRuns(db, row['id'] as int) : <VerificationRun>[];
      result.add(Verification.fromMap(row, runs: runs));
    }
    return result;
  }

  Future<Verification?> getVerification(int id) async {
    final db = await database;
    final rows =
        await db.query('verifications', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final runs = await _loadRuns(db, id);
    return Verification.fromMap(rows.first, runs: runs);
  }

  Future<List<VerificationRun>> _loadRuns(Database db, int verificationId) async {
    final rows = await db.query(
      'verification_runs',
      where: 'verification_id = ?',
      whereArgs: [verificationId],
      orderBy: 'run_index ASC',
    );
    return rows.map(VerificationRun.fromMap).toList();
  }

  Future<void> deleteVerification(int id) async {
    final db = await database;
    await db.delete('verifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<Verification?> getLastVerification(int deviceId) async {
    final list = await getVerifications(deviceId: deviceId, limit: 1);
    return list.isEmpty ? null : list.first;
  }

  // ==========================================================================
  // НАПОМИНАНИЯ
  // ==========================================================================

  Future<Reminder?> getReminder(int deviceId) async {
    final db = await database;
    final rows = await db.query(
      'reminders',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    return rows.isEmpty ? null : Reminder.fromMap(rows.first);
  }

  Future<List<Reminder>> getEnabledReminders() async {
    final db = await database;
    final rows = await db.query('reminders', where: 'enabled = 1');
    return rows.map(Reminder.fromMap).toList();
  }

  Future<void> saveReminder(Reminder reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReminder(int deviceId) async {
    final db = await database;
    await db.delete('reminders', where: 'device_id = ?', whereArgs: [deviceId]);
  }
}
