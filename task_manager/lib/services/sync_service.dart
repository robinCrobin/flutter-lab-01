import 'dart:convert';
import '../models/task.dart';
import 'database_service.dart';
import 'connectivity_service.dart';
import 'task_api_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Registra uma ação offline na tabela sync_queue
  Future<void> queueAction({
    required int taskId,
    required String action,
    required Task task,
  }) async {
    await DatabaseService.instance.insertSyncAction(
      taskId: taskId,
      action: action,
      payload: jsonEncode(task.toMap()),
    );
  }

  /// Registra mudança local e coloca na fila
  Future<void> registerLocalChange(Task task, String action) async {
    // aplica alteração local com marca de sync pendente
    print('cheguei aqui: taskId=${task.id}, action=$action');
    await DatabaseService.instance.upsert(task.copyWith(syncAction: action, isSynced: false));
    // adiciona na fila
    await queueAction(taskId: task.id!, action: action, task: task);
  }

  Future<void> sync() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!online) return;

    // PULL
    final localAll = await DatabaseService.instance.readAll();
    final since = localAll.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0).toUtc()
        : (localAll.map((t) => t.serverUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toList()..sort()).last.toUtc();

    try {
      final remoteTasks = await TaskApiService.instance.fetchAllSince(since);
      for (final remote in remoteTasks) {
        // compara serverUpdatedAt e lastModified
        final local = localAll.firstWhere((l) => l.id == remote.id, orElse: () => remote);
        final serverTs = remote.serverUpdatedAt ?? remote.lastModified;
        final localTs = local.lastModified;
        if (serverTs.isAfter(localTs)) {
          await DatabaseService.instance.upsertFromServer(remote);
        }
      }
    } catch (_) {}

    // PUSH
    final queue = await DatabaseService.instance.getSyncQueue();
    for (final item in queue) {
      final action = item['action'] as String;
      final payload = jsonDecode(item['payload']);
      final task = Task.fromMap(payload);
      try {
        switch (action) {
          case 'create':
            final created = await TaskApiService.instance.create(task);
            await DatabaseService.instance.upsertFromServer(created);
            break;
          case 'update':
            final updated = await TaskApiService.instance.update(task);
            await DatabaseService.instance.upsertFromServer(updated);
            break;
          case 'delete':
            if (task.id != null) await TaskApiService.instance.delete(task.id!);
            await DatabaseService.instance.delete(task.id!);
            break;
        }
        await DatabaseService.instance.removeSyncAction(item['id'] as int);
      } catch (e) {
        break; // para no primeiro erro
      }
    }
  }
}
