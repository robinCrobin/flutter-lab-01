import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../models/task.dart';

class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._init();

  SyncQueueService._init();

  Future<Database> get _db async => await DatabaseService.instance.database;

  Future<void> addToQueue(Task task, String action) async {
    final db = await _db;

    await db.insert('sync_queue', {
      'taskId': task.id,
      'action': action,
      'payload': jsonEncode(task.toMap()),
      'timestamp': DateTime.now().toIso8601String(),
    });

    print('📌 Adicionado à fila: ${task.title} ($action)');
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final db = await _db;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  Future<void> remove(int id) async {
    final db = await _db;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _db;
    await db.delete('sync_queue');
  }
}
