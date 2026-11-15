import 'dart:io';

import 'package:flutter/material.dart';

import '../services/image_picker_service.dart';

/// Un ítem de la galería: un id (para poder borrarlo) y la ruta local
/// de la foto en el dispositivo.
class GalleryPhoto {
  final String id;
  final String path;
  const GalleryPhoto({required this.id, required this.path});
}

/// Sección con una grilla de miniaturas + botón "Agregar foto".
/// Se usa tanto para las fotos sueltas de "Observaciones" de un
/// vehículo como para las fotos de un registro del historial de
/// mantenimiento. Tocar una miniatura la abre en pantalla completa,
/// desde donde también se puede eliminar (si no es de solo lectura).
class PhotoGallerySection extends StatelessWidget {
  final String title;
  final List<GalleryPhoto> photos;
  final bool readOnly;
  final Future<void> Function(String path) onAdd;
  final Future<void> Function(String id) onDelete;

  const PhotoGallerySection({
    super.key,
    required this.title,
    required this.photos,
    required this.readOnly,
    required this.onAdd,
    required this.onDelete,
  });

  Future<void> _pickAndAdd(BuildContext context) async {
    final source = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await ImagePickerService.pickAndSave(fromCamera: source);
    if (path != null) await onAdd(path);
  }

  void _openViewer(BuildContext context, GalleryPhoto photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(photo.path)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
                  if (!readOnly)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await onDelete(photo.id);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    style:
                        IconButton.styleFrom(backgroundColor: Colors.black45),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (!readOnly)
              TextButton.icon(
                onPressed: () => _pickAndAdd(context),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Agregar foto'),
              ),
          ],
        ),
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Sin fotos adjuntas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: photos.map((photo) {
              return GestureDetector(
                onTap: () => _openViewer(context, photo),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: File(photo.path).existsSync()
                      ? Image.file(File(photo.path), fit: BoxFit.cover)
                      : Icon(Icons.broken_image_outlined,
                          color: Colors.grey.shade500),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
