import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskApiService {
  TaskApiService._();
  static final TaskApiService instance = TaskApiService._();

  // Base URL da API - ajuste conforme seu backend
  final String baseUrl = "http://10.0.2.2:3000";

  Future<List<Task>> fetchAllSince(DateTime since) async {
    final uri = Uri.parse('$baseUrl/tasks?since=${since.toUtc().toIso8601String()}');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) throw Exception('Erro ao buscar tasks');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => Task.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Task> create(Task task) async {
    // Debug: print task payload before sending
    print('create() received task: ${jsonEncode(task.toMap())}');
    final uri = Uri.parse('$baseUrl/tasks');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(task.toMap()));
    if (resp.statusCode != 201) throw Exception('Erro ao criar task');
    return Task.fromMap(jsonDecode(resp.body));
  }

  Future<Task> update(Task task) async {
    if (task.id == null) throw Exception('Task sem id');
    final uri = Uri.parse('$baseUrl/tasks/${task.id}');
    final resp = await http.put(uri,
        headers: {
          'Content-Type': 'application/json',
          'If-Unmodified-Since': task.serverUpdatedAt?.toUtc().toIso8601String() ?? '',
        },
        body: jsonEncode(task.toMap()));
    if (resp.statusCode != 200) throw Exception('Erro ao atualizar task');
    return Task.fromMap(jsonDecode(resp.body));
  }

  Future<void> delete(int id) async {
    final uri = Uri.parse('$baseUrl/tasks/$id');
    final resp = await http.delete(uri);
    if (resp.statusCode != 204) throw Exception('Erro ao deletar task');
  }
}
