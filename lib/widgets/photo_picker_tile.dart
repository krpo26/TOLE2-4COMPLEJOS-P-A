import 'dart:io';

import 'package:flutter/material.dart';

import '../services/image_picker_service.dart';

/// Tarjeta con una miniatura (o ícono si está vacía) y un botón para
/// tomar/elegir una foto. Se usa para fotos de choferes y para los
/// documentos de un vehículo (cédula verde, título, VTV, seguro).
class PhotoPickerTile extends StatelessWidget {
  final String label;
  final String? photoPath;
  final bool readOnly;
  final void Function(String path) onPicked;
  final IconData placeholderIcon;

  const PhotoPickerTile({
    super.key,
    required this.label,
    required this.photoPath,
    required this.readOnly,
    required this.onPicked,
    this.placeholderIcon = Icons.description_outlined,
  });

  Future<void> _choose(BuildContext context) async {
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
    if (path != null) onPicked(path);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && File(photoPath!).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: readOnly ? null : () => _choose(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? Image.file(File(photoPath!), fit: BoxFit.cover)
                    : Icon(placeholderIcon, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              if (!readOnly)
                Icon(hasPhoto ? Icons.edit_outlined : Icons.add_a_photo_outlined,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
