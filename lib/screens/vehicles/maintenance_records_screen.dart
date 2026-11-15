import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/maintenance_record.dart';
import '../../models/record_photo.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';
import '../../widgets/photo_gallery_section.dart';
import 'maintenance_record_form_screen.dart';

/// Historial detallado de un vehículo: arreglos, averías, services y
/// otros datos importantes. Cualquier usuario logueado puede verlo;
/// solo el god puede cargar nuevos registros o eliminarlos.
class MaintenanceRecordsScreen extends StatefulWidget {
  final String vehicleId;
  final String vehicleLabel; // ej: "12 · AB123CD"
  final bool readOnly;

  const MaintenanceRecordsScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.readOnly,
  });

  @override
  State<MaintenanceRecordsScreen> createState() =>
      _MaintenanceRecordsScreenState();
}

class _MaintenanceRecordsScreenState extends State<MaintenanceRecordsScreen> {
  late Future<List<MaintenanceRecord>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = DatabaseHelper.instance.getMaintenanceRecords(widget.vehicleId);
    });
  }

  Future<void> _delete(MaintenanceRecord r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('¿Eliminar este registro del historial?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteMaintenanceRecord(r.id);
      SyncService.instance.deleteMaintenanceRecordRemote(r.id);
      _reload();
    }
  }

  IconData _iconFor(MaintenanceEventType type) {
    switch (type) {
      case MaintenanceEventType.repair:
        return Icons.build_outlined;
      case MaintenanceEventType.breakdown:
        return Icons.report_problem_outlined;
      case MaintenanceEventType.service:
        return Icons.settings_suggest_outlined;
      case MaintenanceEventType.other:
        return Icons.notes_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial · ${widget.vehicleLabel}'),
      ),
      body: FutureBuilder<List<MaintenanceRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!;
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay registros cargados para este vehículo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_iconFor(r.type))),
                  title: Text('${r.type.label} · ${DateFormat('dd/MM/yyyy').format(r.date)}'),
                  trailing: widget.readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(r),
                        ),
                  isThreeLine: true,
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          r.description,
                          if (r.mileageAtEvent != null)
                            '${r.mileageAtEvent} km',
                          if (r.cost != null)
                            '\$${r.cost!.toStringAsFixed(2)}',
                        ].join(' · '),
                      ),
                      const SizedBox(height: 6),
                      _RecordPhotosStrip(
                        recordId: r.id,
                        readOnly: widget.readOnly,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo registro'),
              onPressed: () async {
                final message = await Navigator.push<String?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MaintenanceRecordFormScreen(vehicleId: widget.vehicleId),
                  ),
                );
                _reload();
                if (message != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                }
              },
            ),
    );
  }
}

/// Franja de miniaturas de las fotos adjuntas a un registro del
/// historial, con botón para agregar más y opción de eliminarlas.
/// Se carga y refresca de forma independiente para cada registro.
class _RecordPhotosStrip extends StatefulWidget {
  final String recordId;
  final bool readOnly;

  const _RecordPhotosStrip({required this.recordId, required this.readOnly});

  @override
  State<_RecordPhotosStrip> createState() => _RecordPhotosStripState();
}

class _RecordPhotosStripState extends State<_RecordPhotosStrip> {
  List<RecordPhoto> _photos = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = await DatabaseHelper.instance.getRecordPhotos(widget.recordId);
    if (mounted) setState(() {
      _photos = photos;
      _loaded = true;
    });
  }

  Future<void> _addPhoto(String path) async {
    final photo = RecordPhoto(
      id: const Uuid().v4(),
      recordId: widget.recordId,
      photoPath: path,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.insertRecordPhoto(photo);
    SyncService.instance.pushRecordPhoto(photo);
    await _load();
  }

  Future<void> _deletePhoto(String id) async {
    await DatabaseHelper.instance.deleteRecordPhoto(id);
    SyncService.instance.deleteRecordPhotoRemote(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_photos.isEmpty && widget.readOnly) return const SizedBox.shrink();

    return PhotoGallerySection(
      title: 'Fotos',
      photos:
          _photos.map((p) => GalleryPhoto(id: p.id, path: p.photoPath)).toList(),
      readOnly: widget.readOnly,
      onAdd: _addPhoto,
      onDelete: _deletePhoto,
    );
  }
}
