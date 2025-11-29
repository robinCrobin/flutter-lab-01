import 'dart:convert';
import '../models/task.dart';
import 'database_service.dart';
import 'connectivity_service.dart';

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
}
