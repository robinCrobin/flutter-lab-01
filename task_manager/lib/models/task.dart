import 'package:uuid/uuid.dart';

class Task {
  final int? id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;

  // CÂMERA - Múltiplas fotos
  final String? photoPath; // Mantido para compatibilidade
  final List<String>? photoPaths; // Nova lista de fotos

  // SENSORES
  final DateTime? completedAt;
  final String? completedBy; // 'manual', 'shake'

  // GPS
  final double? latitude;
  final double? longitude;
  final String? locationName;

  // OFFLINE
  final DateTime lastModified;
  final bool isSynced;
  final String? syncAction;

  // OFFLINE-FIRST
  final DateTime? serverUpdatedAt; // timestamp do servidor
  final bool deleted; // tombstone
  String? deviceId; // identificador do dispositivo que gerou a última mudança

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.completed = false,
    DateTime? createdAt,
    this.photoPath,
    this.photoPaths,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    this.dueDate,
    DateTime? lastModified,
    this.isSynced = true,
    this.syncAction,
    this.serverUpdatedAt,
    this.deleted = false,
    this.deviceId,
  }) : createdAt = (createdAt ?? DateTime.now()).toUtc(),
       lastModified = (lastModified ?? DateTime.now()).toUtc() {
    deviceId = deviceId ?? const Uuid().v4();
  }

  // Getters auxiliares
  bool get hasPhoto =>
      (photoPath != null && photoPath!.isNotEmpty) ||
      (photoPaths != null && photoPaths!.isNotEmpty);
  bool get hasMultiplePhotos => photoPaths != null && photoPaths!.length > 1;
  int get photoCount => photoPaths?.length ?? (hasPhoto ? 1 : 0);
  List<String> get allPhotoPaths {
    List<String> paths = [];
    if (photoPath != null && photoPath!.isNotEmpty) paths.add(photoPath!);
    if (photoPaths != null) paths.addAll(photoPaths!);
    return paths.toSet().toList(); // Remove duplicatas
  }

  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'completed': completed == true ? 1 : 0, // bool → int
      'createdAt': createdAt.toIso8601String(),
      'photoPath': photoPath,
      'photoPaths': (photoPaths ?? []).join(','),

      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,

      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,

      'dueDate': dueDate?.toIso8601String(),

      'lastModified': lastModified.toIso8601String(), // DateTime → String

      'isSynced': isSynced == true ? 1 : 0, // bool → int

      'syncAction': syncAction,

      'serverUpdatedAt': serverUpdatedAt?.toUtc().toIso8601String(),
      'deleted': deleted ? 1 : 0,
      'deviceId': deviceId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? '',
      completed: (map['completed'] ?? 0) == 1, // int → bool
      createdAt: DateTime.tryParse(map['createdAt'] ?? ''),
      photoPath: map['photoPath'],
      photoPaths: map['photoPaths'] != null
          ? List<String>.from(map['photoPaths'].split(','))
          : [],
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      completedBy: map['completedBy'],
      latitude: map['latitude'] != null ? map['latitude'] * 1.0 : null,
      longitude: map['longitude'] != null ? map['longitude'] * 1.0 : null,
      locationName: map['locationName'],
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'])
          : null,

      lastModified: map['lastModified'] != null
          ? DateTime.tryParse(map['lastModified'])
          : null, // String → DateTime

      isSynced: map['isSynced'] == 1, // int → bool

      syncAction: map['syncAction'],

      serverUpdatedAt: map['serverUpdatedAt'] != null
          ? DateTime.tryParse(map['serverUpdatedAt'])?.toUtc()
          : null,
      deleted: (map['deleted'] ?? 0) == 1,
      deviceId: map['deviceId'],
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    String? photoPath,
    List<String>? photoPaths,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? dueDate,
    DateTime? lastModified,
    bool? isSynced,
    String? syncAction,
    DateTime? serverUpdatedAt,
    bool? deleted,
    String? deviceId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      photoPath: photoPath ?? this.photoPath,
      photoPaths: photoPaths ?? this.photoPaths,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      dueDate: dueDate ?? this.dueDate,
      lastModified: lastModified ?? this.lastModified,
      isSynced: isSynced ?? this.isSynced,
      syncAction: syncAction ?? this.syncAction,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deleted: deleted ?? this.deleted,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  // Método para verificar se a tarefa está vencida
  bool get isOverdue {
    if (dueDate == null || completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  // Método para verificar se a tarefa vence hoje
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = dueDate!;
    return now.year == due.year && now.month == due.month && now.day == due.day;
  }

  // Método para verificar se a tarefa vence em breve (próximos 3 dias)
  bool get isDueSoon {
    if (dueDate == null || completed) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference >= 0 && difference <= 3;
  }
}
