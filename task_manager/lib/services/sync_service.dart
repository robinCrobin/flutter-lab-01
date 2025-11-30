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

  /// Processa a fila quando voltar a internet
  Future<void> processQueue() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!online) return;

    final queue = await DatabaseService.instance.getSyncQueue();

    for (final item in queue) {
      final action = item['action'];
      final payload = jsonDecode(item['payload']);
      final taskId = item['taskId'];

      try {
        await _applyAction(action, payload, taskId);

        // remover da fila após sucesso
        await DatabaseService.instance.removeSyncAction(item['id']);
      } catch (e) {
        // se falhar, para a fila
        break;
      }
    }
  }

  /// Aplica ação ao banco local (LWW)
  Future<void> _applyAction(String action, Map<String, dynamic> payload, int taskId) async {
    switch (action) {
      case 'create':
      case 'update':
        final task = Task.fromMap(payload);
        await DatabaseService.instance.upsertFromServer(task);
        break;

      case 'delete':
        await DatabaseService.instance.delete(taskId);
        break;

      default:
        throw Exception('Ação desconhecida: $action');
    }
  }

  /// Registra mudança local e coloca na fila
  Future<void> registerLocalChange(Task task, String action) async {
    // Marca task local como não sincronizada
    await DatabaseService.instance.upsert(
      task.copyWith(
        isSynced: false,
        syncAction: action,
      ),
    );

    await queueAction(
      taskId: task.id!,
      action: action,
      task: task,
    );
  }

  Future<void> sync() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!online) return;

    // PULL: obter últimas modificações do servidor
    final allLocal = await DatabaseService.instance.readAll();
    DateTime since = allLocal.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0).toUtc()
        : (allLocal.map((t) => t.serverUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toList()
              ..sort()).last.toUtc();

    try {
      final remote = await TaskApiService.instance.fetchAllSince(since);
      for (final r in remote) {
        // LWW: compara serverUpdatedAt (remoto) vs lastModified (local)
        final local = allLocal.firstWhere(
          (l) => l.id == r.id,
          orElse: () => r, // se não existir, usa remoto diretamente
        );
        if (local.id == null) {
          await DatabaseService.instance.upsertFromServer(r);
          continue;
        }
        final serverTs = r.serverUpdatedAt ?? r.lastModified;
        final localTs = local.lastModified;
        if (serverTs.isAfter(localTs)) {
          await DatabaseService.instance.upsertFromServer(r);
        }
      }
    } catch (_) {
      // falha no pull não impede push
    }

    // PUSH: processar fila local para servidor
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
            if (task.id != null) {
              await TaskApiService.instance.delete(task.id!);
            }
            await DatabaseService.instance.delete(task.id!);
            break;
        }
        await DatabaseService.instance.removeSyncAction(item['id'] as int);
      } catch (e) {
        // para o processamento no primeiro erro para tentar depois
        break;
      }
    }
  }
}
