import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker.dart';
import '../widgets/photo_gallery_widget.dart';
import '../services/sync_service.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = criar novo, não-null = editar

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  bool _completed = false;
  bool _isLoading = false;
  DateTime? _dueDate;

  // CÂMERA - Múltiplas fotos
  String? _photoPath;
  List<String> _photoPaths = [];

  // GPS
  double? _latitude;
  double? _longitude;
  String? _locationName;

  @override
  void initState() {
    super.initState();

    // Se estiver editando, preencher campos
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _dueDate = widget.task!.dueDate;
      _photoPath = widget.task!.photoPath;
      _photoPaths = List<String>.from(widget.task!.photoPaths ?? []);

      // Ensure backward compatibility: if we have photoPath but no photoPaths, add it
      if (_photoPath != null && _photoPaths.isEmpty) {
        _photoPaths.add(_photoPath!);
      }

      // Ensure photoPath is synced with photoPaths for backward compatibility
      if (_photoPaths.isNotEmpty && _photoPath == null) {
        _photoPath = _photoPaths.first;
      }
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // CÂMERA E GALERIA METHODS - Múltiplas fotos
  Future<void> _selectImages() async {
    final result = await CameraService.instance.showMultiImageSourceDialog(
      context,
    );

    if (result != null && mounted) {
      if (result.startsWith('single:')) {
        // Uma única foto
        final photoPath = result.substring(7);
        setState(() {
          _photoPaths.add(photoPath);
          // Manter compatibilidade com photoPath único para exibição
          if (_photoPath == null) _photoPath = photoPath;
        });
      } else if (result.startsWith('multiple:')) {
        // Múltiplas fotos
        final photoPaths = result.substring(9).split(',');
        setState(() {
          _photoPaths.addAll(photoPaths);
          // Manter compatibilidade com photoPath único
          if (_photoPath == null && photoPaths.isNotEmpty) {
            _photoPath = photoPaths.first;
          }
        });
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      if (index < _photoPaths.length) {
        _photoPaths.removeAt(index);
      }
      // Update single photo path for backward compatibility
      _photoPath = _photoPaths.isNotEmpty ? _photoPaths.first : null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🗑️ Foto removida')));
  }

  void _removeAllPhotos() {
    setState(() {
      _photoPaths.clear();
      _photoPath = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Todas as fotos removidas')),
    );
  }

  // GPS METHODS
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: LocationPicker(
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            initialAddress: _locationName,
            onLocationSelected: (lat, lon, address) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _locationName = address;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('📍 Localização removida')));
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.task == null) {
        final newTask = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          dueDate: _dueDate,
          photoPath: _photoPath,
          photoPaths: _photoPaths,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          isSynced: false,
          syncAction: 'create',
        );
        // Persist locally and get id
        final created = await DatabaseService.instance.create(newTask);
        // Queue with the created task (has id)
        debugPrint('Cheguei até aqui: tarefa criada -> ${created.toString()}');
        await SyncService.instance.registerLocalChange(created, 'create');
        // Dispara sync imediato (se online)
        await SyncService.instance.sync();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          dueDate: _dueDate,
          photoPath: _photoPath,
          photoPaths: _photoPaths,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
        );
        await DatabaseService.instance.update(updatedTask);
        await SyncService.instance.registerLocalChange(updatedTask, 'update');
        // Dispara sync imediato (se online)
        await SyncService.instance.sync();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada com sucesso'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Retorna true = sucesso
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecionar data de vencimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );

    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  String _getDueDateStatus() {
    if (_dueDate == null) return '';

    final now = DateTime.now();
    final difference = _dueDate!.difference(now).inDays;

    if (difference < 0) {
      return 'Venceu há ${(-difference)} dia(s)';
    } else if (difference == 0) {
      return 'Vence hoje';
    } else if (difference == 1) {
      return 'Vence amanhã';
    } else if (difference <= 3) {
      return 'Vence em $difference dias';
    } else if (difference <= 7) {
      return 'Vence em 1 semana';
    } else {
      return 'Vence em $difference dias';
    }
  }

  Color _getDueDateColor() {
    if (_dueDate == null) return Colors.grey;

    final now = DateTime.now();
    final difference = _dueDate!.difference(now).inDays;

    if (difference < 0) {
      return Colors.red; // Vencida
    } else if (difference == 0) {
      return Colors.orange; // Vence hoje
    } else if (difference <= 3) {
      return Colors.amber; // Vence em breve
    } else {
      return Colors.green; // Prazo tranquilo
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo de Título
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Estudar Flutter',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, digite um título';
                        }
                        if (value.trim().length < 3) {
                          return 'Título deve ter pelo menos 3 caracteres';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),

                    const SizedBox(height: 16),

                    // Campo de Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Adicione mais detalhes...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
                      maxLength: 500,
                    ),

                    const SizedBox(height: 16),

                    // Dropdown de Prioridade
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Baixa'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Média'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Alta'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Urgente'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Campo de Data de Vencimento
                    InkWell(
                      onTap: _selectDueDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de Vencimento',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _dueDate == null
                              ? 'Selecionar data (opcional)'
                              : '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}',
                          style: TextStyle(
                            color: _dueDate == null
                                ? Colors.grey.shade600
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),

                    if (_dueDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getDueDateStatus(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getDueDateColor(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _dueDate = null),
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Switch de Completo
                    Card(
                      child: SwitchListTile(
                        title: const Text('Tarefa Completa'),
                        subtitle: Text(
                          _completed
                              ? 'Esta tarefa está marcada como concluída'
                              : 'Esta tarefa ainda não foi concluída',
                        ),
                        value: _completed,
                        onChanged: (value) {
                          setState(() => _completed = value);
                        },
                        secondary: Icon(
                          _completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _completed ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),

                    const Divider(height: 32),

                    // SEÇÃO MÚLTIPLAS FOTOS
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          _photoPaths.isEmpty
                              ? 'Fotos'
                              : 'Fotos (${_photoPaths.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_photoPaths.isNotEmpty)
                          TextButton.icon(
                            onPressed: _removeAllPhotos,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover todas'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_photoPaths.isNotEmpty)
                      PhotoGalleryWidget(
                        photoPaths: _photoPaths,
                        onPhotoTap: (index) {
                          // Visualização em tela cheia será tratada pelo widget
                        },
                        onPhotoDelete: (index) {
                          _removePhoto(index);
                        },
                        maxHeight: 200,
                        showDeleteButton: true,
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _selectImages,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Adicionar Fotos'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                    if (_photoPaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _selectImages,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Adicionar mais fotos'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],

                    const Divider(height: 32),

                    // SEÇÃO LOCALIZAÇÃO
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Localização',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_latitude != null)
                          TextButton.icon(
                            onPressed: _removeLocation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_latitude != null && _longitude != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                          ),
                          title: Text(_locationName ?? 'Localização salva'),
                          subtitle: Text(
                            LocationService.instance.formatCoordinates(
                              _latitude!,
                              _longitude!,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _showLocationPicker,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _showLocationPicker,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Adicionar Localização'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Botão Salvar
                    ElevatedButton.icon(
                      onPressed: _saveTask,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isEditing ? 'Atualizar Tarefa' : 'Criar Tarefa',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Botão Cancelar
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
