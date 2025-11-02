import 'dart:io';
import 'package:flutter/material.dart';

class PhotoGalleryWidget extends StatelessWidget {
  final List<String> photoPaths;
  final Function(int index)? onPhotoTap;
  final Function(int index)? onPhotoDelete;
  final bool showDeleteButton;
  final double? maxHeight;

  const PhotoGalleryWidget({
    super.key,
    required this.photoPaths,
    this.onPhotoTap,
    this.onPhotoDelete,
    this.showDeleteButton = false,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (photoPaths.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: maxHeight != null 
        ? BoxConstraints(maxHeight: maxHeight!) 
        : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com contador
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.photo_library, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '${photoPaths.length} foto${photoPaths.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          // Grid de fotos
          Expanded(
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 1.0,
                mainAxisSpacing: 8,
              ),
              itemCount: photoPaths.length,
              itemBuilder: (context, index) {
                return _buildPhotoItem(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(BuildContext context, int index) {
    return Stack(
      children: [
        // Foto
        GestureDetector(
          onTap: () => onPhotoTap?.call(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photoPaths[index]),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(height: 4),
                        Text('Erro', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        
        // Botão de deletar (se habilitado)
        if (showDeleteButton)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => onPhotoDelete?.call(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        
        // Indicador de posição (se múltiplas fotos)
        if (photoPaths.length > 1)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Widget para exibir foto em tela cheia
class FullScreenPhotoViewer extends StatelessWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const FullScreenPhotoViewer({
    super.key,
    required this.photoPaths,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1} de ${photoPaths.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photoPaths.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: Image.file(
                File(photoPaths[index]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Erro ao carregar imagem',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
