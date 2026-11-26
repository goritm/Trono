import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/bathroom_log.dart';

/// Abstract repository so V2 cloud sync / multiplayer can plug in cleanly.
abstract class BathroomRepository {
  Future<List<BathroomLog>> getAllLogs();
  Future<List<BathroomLog>> getAllLogsIncludingDeleted();
  Future<List<BathroomLog>> getPendingSyncLogs();
  Future<void> markLogsSynced(List<String> ids);
  Future<void> upsertLog(BathroomLog log);
  Future<void> upsertLogsBatch(List<BathroomLog> logs);
  Future<void> softDeleteLog(String id);
  Future<void> clearAll();
}

class LocalBathroomRepository implements BathroomRepository {
  LocalBathroomRepository._();
  static final LocalBathroomRepository instance = LocalBathroomRepository._();

  static const _dbName = 'trono.db';
  static const _dbVersion = 2;
  static const _table = 'bathroom_logs';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            bristol_type INTEGER,
            size TEXT,
            effort TEXT,
            duration_seconds INTEGER,
            color TEXT,
            tags TEXT,
            note TEXT,
            location_kind TEXT,
            latitude REAL,
            longitude REAL,
            place_label TEXT,
            share_level TEXT NOT NULL DEFAULT 'summary_only',
            sync_status TEXT NOT NULL DEFAULT 'local_only',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_logs_timestamp ON $_table (timestamp DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_logs_deleted ON $_table (deleted_at)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN location_kind TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN latitude REAL');
          await db.execute('ALTER TABLE $_table ADD COLUMN longitude REAL');
          await db.execute('ALTER TABLE $_table ADD COLUMN place_label TEXT');
        }
      },
    );
    return _db!;
  }

  @override
  Future<List<BathroomLog>> getAllLogs() async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'timestamp DESC',
    );
    return rows.map(BathroomLog.fromDbMap).toList();
  }

  @override
  Future<List<BathroomLog>> getAllLogsIncludingDeleted() async {
    final db = await database;
    final rows = await db.query(
      _table,
      orderBy: 'timestamp DESC',
    );
    return rows.map(BathroomLog.fromDbMap).toList();
  }

  @override
  Future<List<BathroomLog>> getPendingSyncLogs() async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'sync_status != ?',
      whereArgs: [SyncStatus.synced.dbValue],
      orderBy: 'updated_at ASC',
    );
    return rows.map(BathroomLog.fromDbMap).toList();
  }

  @override
  Future<void> markLogsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.update(
          _table,
          {'sync_status': SyncStatus.synced.dbValue},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> upsertLog(BathroomLog log) async {
    final db = await database;
    await db.insert(
      _table,
      log.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> upsertLogsBatch(List<BathroomLog> logs) async {
    if (logs.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final log in logs) {
        batch.insert(
          _table,
          log.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> softDeleteLog(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      _table,
      {
        'deleted_at': now,
        'updated_at': now,
        'sync_status': SyncStatus.pendingSync.dbValue,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_table);
  }
}
