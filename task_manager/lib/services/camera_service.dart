import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      print(
        '✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)',
      );
    } catch (e) {
      print('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  Future<String?> takePicture(BuildContext context) async {
    if (!hasCameras) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nenhuma câmera disponível'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (e) {
      print('❌ Erro ao abrir câmera: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<String> savePicture(XFile image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = path.join(appDir.path, 'images', fileName);

      final imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final savedImage = await File(image.path).copy(savePath);
      print('✅ Foto salva: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao deletar foto: $e');
      return false;
    }
  }

  // NOVOS MÉTODOS PARA GALERIA
  Future<String?> pickImageFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final savedPath = await savePicture(image);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📷 Imagem selecionada da galeria!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return savedPath;
      }

      return null;
    } catch (e) {
      print('❌ Erro ao selecionar da galeria: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    }
  }

  Future<String?> showImageSourceDialog(BuildContext context) async {
    return await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecionar Foto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final imagePath = await takePicture(context);
                          if (imagePath != null && context.mounted) {
                            Navigator.pop(context, imagePath);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 48,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Câmera',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tirar foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final imagePath = await pickImageFromGallery(context);
                          if (imagePath != null && context.mounted) {
                            Navigator.pop(context, imagePath);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.photo_library,
                                size: 48,
                                color: Colors.green,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Galeria',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Escolher foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NOVOS MÉTODOS PARA MÚLTIPLAS FOTOS
  Future<List<String>?> pickMultipleImagesFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        List<String> savedPaths = [];
        
        for (XFile image in images) {
          final savedPath = await savePicture(image);
          savedPaths.add(savedPath);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📷 ${images.length} imagens selecionadas!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        return savedPaths;
      }
      
      return null;
    } catch (e) {
      print('❌ Erro ao selecionar múltiplas imagens: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagens: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    }
  }

  Future<String?> showMultiImageSourceDialog(BuildContext context) async {
    return await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Adicionar Fotos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Primeira linha: Câmera e Galeria (única)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final imagePath = await takePicture(context);
                          if (imagePath != null) {
                            Navigator.pop(context, 'single:$imagePath');
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.camera_alt, size: 40, color: Colors.blue),
                              SizedBox(height: 8),
                              Text('Câmera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final imagePath = await pickImageFromGallery(context);
                          if (imagePath != null) {
                            Navigator.pop(context, 'single:$imagePath');
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.photo, size: 40, color: Colors.green),
                              SizedBox(height: 8),
                              Text('1 Foto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Segunda linha: Múltiplas fotos
                InkWell(
                  onTap: () async {
                    final imagePaths = await pickMultipleImagesFromGallery(context);
                    if (imagePaths != null && imagePaths.isNotEmpty) {
                      Navigator.pop(context, 'multiple:${imagePaths.join(",")}');
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purple, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.photo_library, size: 40, color: Colors.purple),
                        SizedBox(height: 8),
                        Text('Múltiplas Fotos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                        Text('Selecionar várias fotos da galeria', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> deleteMultiplePhotos(List<String> photoPaths) async {
    bool allDeleted = true;
    
    for (String photoPath in photoPaths) {
      bool deleted = await deletePhoto(photoPath);
      if (!deleted) allDeleted = false;
    }
    
    return allDeleted;
  }
}
