import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8, // bump version for new columns
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------
  // CREATE DATABASE
  // ---------------------------------------------------------
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER';

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        completed $intType NOT NULL,
        createdAt TEXT NOT NULL,
        photoPath TEXT,
        photoPaths TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        dueDate TEXT,
        lastModified TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        syncAction TEXT,
        serverUpdatedAt TEXT,
        deleted INTEGER NOT NULL DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // Tabela da fila de sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER,
        action TEXT NOT NULL, 
        payload TEXT NOT NULL, 
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------
  // UPGRADE DATABASE (MIGRAÇÕES)
  // ---------------------------------------------------------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPaths TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE tasks ADD COLUMN lastModified TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN isSynced INTEGER DEFAULT 1',
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN syncAction TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER,
          action TEXT NOT NULL,
          payload TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE tasks ADD COLUMN serverUpdatedAt TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN deviceId TEXT');
    }

    print("✅ Migrado de $oldVersion para $newVersion");
  }

  // ---------------------------------------------------------
  // CRUD METHODS COM PRONTO PARA SYNC
  // ---------------------------------------------------------

  // CREATE
  Future<Task> create(Task task) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc();
    final data = task.copyWith(lastModified: now, isSynced: false, syncAction: 'create').toMap();
    final id = await db.insert('tasks', data);
    return task.copyWith(id: id, lastModified: now, isSynced: false, syncAction: 'create');
  }

  // READ
  Future<Task?> read(int id) async {
    final db = await instance.database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) return Task.fromMap(maps.first);
    return null;
  }

  // READ ALL
  Future<List<Task>> readAll() async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'deleted = 0',
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  // UPDATE
  Future<int> update(Task task) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc();
    return db.update(
      'tasks',
      task
          .copyWith(lastModified: now, isSynced: false, syncAction: 'update')
          .toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // DELETE
  Future<int> delete(int id) async {
    final db = await instance.database;

    // Marca como "delete" para sync
    return db.update(
      'tasks',
      {
        'isSynced': 0,
        'syncAction': 'delete',
        'lastModified': DateTime.now().toUtc().toIso8601String(),
        'deleted': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------
  // CONSULTAS ESPECIAIS
  // ---------------------------------------------------------

  Future<List<Task>> readAllOrderedByDueDate() async {
    final db = await database;
    const orderBy = 'dueDate IS NULL, dueDate ASC, createdAt DESC';
    final result = await db.query(
      'tasks',
      where: 'deleted = 0',
      orderBy: orderBy,
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> readOverdueTasks() async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final result = await db.query(
      'tasks',
      where:
          'dueDate IS NOT NULL AND dueDate < ? AND completed = 0 AND deleted = 0',
      whereArgs: [nowIso],
      orderBy: 'dueDate ASC',
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> readTasksDueToday() async {
    final db = await database;

    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final end = DateTime(
      today.year,
      today.month,
      today.day,
      23,
      59,
      59,
    ).toIso8601String();

    final result = await db.query(
      'tasks',
      where: 'dueDate >= ? AND dueDate <= ? AND completed = 0 AND deleted = 0',
      whereArgs: [start, end],
      orderBy: 'dueDate ASC',
    );

    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final all = await readAll();

    return all.where((t) {
      if (!t.hasLocation) return false;

      final latDiff = (t.latitude! - latitude).abs();
      final lonDiff = (t.longitude! - longitude).abs();
      final distance = ((latDiff * 111000) + (lonDiff * 111000)) / 2;

      return distance <= radiusInMeters;
    }).toList();
  }

  Future<void> insertSyncAction({
    required int? taskId,
    required String action,
    required String payload,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'taskId': taskId,
      'action': action, // create, update, delete
      'payload': payload, // JSON da task
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  // UPDATE OR INSERT (local change)
  Future<void> upsert(Task task) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc();
    final data = task.copyWith(lastModified: now, isSynced: false).toMap();
    if (task.id == null) {
      await db.insert('tasks', data);
    } else {
      await db.update('tasks', data, where: 'id = ?', whereArgs: [task.id]);
    }
  }

  // UPSERT COM DADOS DO SERVIDOR (LWW)
  Future<void> upsertFromServer(Task incoming) async {
    final db = await instance.database;

    // Sempre garantir que venha como sincronizado
    Task serverTask = incoming.copyWith(isSynced: true, syncAction: null);

    if (serverTask.id == null) {
      // Se não há id, só insere
      await db.insert('tasks', serverTask.toMap());
      return;
    }

    final existingMap = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [serverTask.id],
      limit: 1,
    );

    if (existingMap.isEmpty) {
      await db.insert('tasks', serverTask.toMap());
      return;
    }

    final existing = Task.fromMap(existingMap.first);

    final incomingTs = serverTask.lastModified; // non-nullable
    final existingTs = existing.lastModified; // non-nullable

    // Last-Write-Wins: aplica se versão do servidor é mais nova
    if (incomingTs.isAfter(existingTs)) {
      await db.update(
        'tasks',
        serverTask.toMap(),
        where: 'id = ?',
        whereArgs: [serverTask.id],
      );
    }
  }

  Future<void> markDeletedLocal(int id) async {
    final db = await instance.database;
    await db.update(
      'tasks',
      {
        'deleted': 1,
        'isSynced': 0,
        'syncAction': 'delete',
        'lastModified': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeSyncAction(int id) async {
    final db = await instance.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------
  // CLOSE
  // ---------------------------------------------------------
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
