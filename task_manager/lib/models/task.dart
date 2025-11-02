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
  }) : createdAt = createdAt ?? DateTime.now();

  // Getters auxiliares
  bool get hasPhoto => (photoPath != null && photoPath!.isNotEmpty) || 
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
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'photoPath': photoPath,
      'photoPaths': photoPaths?.join(','), // Salva como string separada por vírgulas
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      priority: map['priority'] as String,
      completed: (map['completed'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      photoPath: map['photoPath'] as String?,
      photoPaths: map['photoPaths'] != null 
          ? (map['photoPaths'] as String).split(',').where((path) => path.isNotEmpty).toList()
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['locationName'] as String?,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    String? photoPath,
    List<String>? photoPaths,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      photoPath: photoPath ?? this.photoPath,
      photoPaths: photoPaths ?? this.photoPaths,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
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
