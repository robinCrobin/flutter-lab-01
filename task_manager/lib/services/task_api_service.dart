import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskApiService {
  TaskApiService._();
  static final TaskApiService instance = TaskApiService._();

  // Base URL dinâmico por plataforma, com possibilidade de override via env
  String get baseUrl {
    // Override via --dart-define=TASK_API_BASE_URL=http://ip:3000
    const envUrl = String.fromEnvironment('TASK_API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    // iOS Simulator, macOS, desktop
    return 'http://localhost:3000';
  }

  // Converte o payload simples do servidor (MySQL) para nosso modelo Task
  Task _fromServer(Map<String, dynamic> data) {
    final int? updatedMs = data['updated_at'] is int
        ? data['updated_at'] as int
        : int.tryParse('${data['updated_at'] ?? ''}');
    final DateTime serverTs = updatedMs != null
        ? DateTime.fromMillisecondsSinceEpoch(updatedMs, isUtc: true)
        : DateTime.now().toUtc();

    return Task(
      id: (data['id'] as num?)?.toInt(),
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      // Campos não presentes no servidor recebem defaults
      priority: 'medium',
      completed: false,
      createdAt: DateTime.now().toUtc(),
      lastModified: serverTs, // importante para LWW
      serverUpdatedAt: serverTs,
      isSynced: true,
      deleted: false,
    );
  }

  Future<List<Task>> fetchAllSince(DateTime since) async {
    final uri = Uri.parse(
      '$baseUrl/tasks?since=${since.toUtc().toIso8601String()}',
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) throw Exception('Erro ao buscar tasks');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => _fromServer(e as Map<String, dynamic>)).toList();
  }

  Future<Task> create(Task task) async {
    // Debug: print task payload before sending
    print('create() received task: ${jsonEncode(task.toMap())}');
    final uri = Uri.parse('$baseUrl/tasks');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': task.id, // manter id local
        'title': task.title,
        'description': task.description,
        // Opcionalmente, envie lastModified se quiser
        'lastModified': task.lastModified.toUtc().toIso8601String(),
      }),
    );
    if (resp.statusCode != 201) throw Exception('Erro ao criar task');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return _fromServer(map);
  }

  Future<Task> update(Task task) async {
    if (task.id == null) throw Exception('Task sem id');
    final uri = Uri.parse('$baseUrl/tasks/${task.id}');
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // Cabeçalho condicional pode ser ignorado pelo backend atual
        'If-Unmodified-Since':
            task.serverUpdatedAt?.toUtc().toIso8601String() ?? '',
      },
      body: jsonEncode({
        'title': task.title,
        'description': task.description,
        'lastModified': task.lastModified.toUtc().toIso8601String(),
      }),
    );
    if (resp.statusCode != 200) throw Exception('Erro ao atualizar task');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return _fromServer(map);
  }

  Future<void> delete(int id) async {
    final uri = Uri.parse('$baseUrl/tasks/$id');
    final resp = await http.delete(uri);
    if (resp.statusCode != 204) throw Exception('Erro ao deletar task');
  }
}
