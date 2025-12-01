import 'dart:convert';
import '../models/task.dart';
import 'database_service.dart';
import 'connectivity_service.dart';
import 'task_api_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();
  bool _syncing = false; // evita sync concorrente

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
    // Debug
    // ignore: avoid_print
    print('[SYNC] queued action: taskId=$taskId action=$action');
  }

  /// Registra mudança local e coloca na fila
  Future<void> registerLocalChange(Task task, String action) async {
    // aplica alteração local com marca de sync pendente
    // ignore: avoid_print
    print('[SYNC] registerLocalChange: taskId=${task.id}, action=$action');
    await DatabaseService.instance.upsert(task.copyWith(syncAction: action, isSynced: false));
    // adiciona na fila
    await queueAction(taskId: task.id!, action: action, task: task);
  }

  Future<void> sync() async {
    if (_syncing) {
      // ignore: avoid_print
      print('[SYNC] abort: already in progress');
      return;
    }
    _syncing = true;
    // ignore: avoid_print
    print('[SYNC] start');
    final online = await ConnectivityService.instance.isOnline;
    // ignore: avoid_print
    print('[SYNC] online=$online');
    if (!online) {
      _syncing = false;
      return;
    }

    // PULL
    final localAll = await DatabaseService.instance.readAll();
    final since = localAll.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0).toUtc()
        : (localAll.map((t) => t.serverUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toList()..sort()).last.toUtc();

    try {
      final remoteTasks = await TaskApiService.instance.fetchAllSince(since);
      // ignore: avoid_print
      print('[SYNC] pull: fetched=${remoteTasks.length} since=$since');
      for (final remote in remoteTasks) {
        // compara serverUpdatedAt e lastModified
        final local = localAll.firstWhere((l) => l.id == remote.id, orElse: () => remote);
        final serverTs = remote.serverUpdatedAt ?? remote.lastModified;
        final localTs = local.lastModified;
        if (serverTs.isAfter(localTs)) {
          await DatabaseService.instance.upsertFromServer(remote);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SYNC] pull error: $e');
    }

    // PUSH
    final queue = await DatabaseService.instance.getSyncQueue();
    // ignore: avoid_print
    print('[SYNC] push: queueLen=${queue.length}');
    for (final item in queue) {
      final action = item['action'] as String;
      final payload = jsonDecode(item['payload']);
      final task = Task.fromMap(payload);
      // ignore: avoid_print
      print('[SYNC] processing action=$action taskId=${task.id}');
      try {
        switch (action) {
          case 'create':
            final created = await TaskApiService.instance.create(task);
            if (created.id != task.id && task.id != null) {
              // Replace local record to avoid duplicate ids
              await DatabaseService.instance.delete(task.id!);
            }
            await DatabaseService.instance.upsertFromServer(created);
            await DatabaseService.instance.removeDuplicateUnsyncedCreates(
              keepId: created.id!,
              title: created.title,
              description: created.description,
            );
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
        // ignore: avoid_print
        print('[SYNC] action processed: $action taskId=${task.id}');
      } catch (e) {
        // ignore: avoid_print
        print('[SYNC] push error: $e');
        break; // para no primeiro erro
      }
    }
    // ignore: avoid_print
    print('[SYNC] done');
    _syncing = false;
  }

  Future<void> clearQueue() async {
    await DatabaseService.instance.clearSyncQueue();
    // ignore: avoid_print
    print('[SYNC] queue cleared');
  }

  Future<void> syncCreatesOnly() async {
    // ignore: avoid_print
    print('[SYNC] start (creates only)');
    final online = await ConnectivityService.instance.isOnline;
    if (!online) return;

    // Pull still runs to get remote tasks
    try {
      final localAll = await DatabaseService.instance.readAll();
      final since = localAll.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0).toUtc()
          : (localAll
                  .map((t) => t.serverUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .toList()
                ..sort())
              .last
              .toUtc();
      final remoteTasks = await TaskApiService.instance.fetchAllSince(since);
      // ignore: avoid_print
      print('[SYNC] pull: fetched=${remoteTasks.length}');
      for (final remote in remoteTasks) {
        await DatabaseService.instance.upsertFromServer(remote);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SYNC] pull error: $e');
    }

    // Only process creates
    final queue = await DatabaseService.instance.getSyncQueue();
    final createItems = queue.where((q) => (q['action'] as String) == 'create').toList();
    // ignore: avoid_print
    print('[SYNC] push (creates only): queueLen=${createItems.length}');
    for (final item in createItems) {
      final payload = jsonDecode(item['payload']);
      final task = Task.fromMap(payload);
      try {
        final created = await TaskApiService.instance.create(task);
        await DatabaseService.instance.upsertFromServer(created);
        await DatabaseService.instance.removeSyncAction(item['id'] as int);
        // ignore: avoid_print
        print('[SYNC] created taskId=${created.id}');
      } catch (e) {
        // ignore: avoid_print
        print('[SYNC] push create error: $e');
        break;
      }
    }
    // ignore: avoid_print
    print('[SYNC] done (creates only)');
  }
}
