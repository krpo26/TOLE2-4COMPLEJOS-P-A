import '../../widgets/delete_or_move_dialog.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/observation_photo.dart';
import '../../models/service_intervals.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/database_helper.dart';
import '../../services/image_picker_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/entity_icons.dart';
import '../../widgets/photo_gallery_section.dart';
import '../../widgets/photo_picker_tile.dart';
import 'package:uuid/uuid.dart';
import 'maintenance_records_screen.dart';
import 'fuel_log_screen.dart';
import 'tech_sheet_screen.dart';

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle; // null = alta, no-null = edición
  final bool readOnly; // true = usuario común, solo puede ver

  const VehicleFormScreen({super.key, this.vehicle, this.readOnly = false});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _plateCtrl;
  late final TextEditingController _internalNumberCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _mileageCtrl;
  late final TextEditingController _nextServiceCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _fuelLimitCtrl;
  DateTime? _lastServiceDate;
  String? _vehicleType;
  String? _photoPath;
  String? _cedulaVerdePath;
  String? _tituloPath;
  String? _vtvPath;
  String? _seguroPath;
  String? _iconKey;
  List<ObservationPhoto> _observationPhotos = [];

  bool get _isEditing => widget.vehicle != null;

  static const List<String> _vehicleTypes = [
    'Auto',
    'Camioneta',
    'Camión',
    'Utilitario',
    'Moto',
    'Ómnibus / Micro',
    'Maquinaria',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _internalNumberCtrl = TextEditingController(text: v?.internalNumber ?? '');
    _brandCtrl = TextEditingController(text: v?.brand ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    // Solo para refrescar el texto de ayuda del intervalo de service
    // mientras se escribe marca/modelo (la lógica real de
    // autocompletar el "próximo service" no depende de esto).
    _brandCtrl.addListener(() => setState(() {}));
    _modelCtrl.addListener(() => setState(() {}));
    _vehicleType = (v?.vehicleType.isNotEmpty ?? false) ? v!.vehicleType : null;
    _mileageCtrl = TextEditingController(text: v?.currentMileage.toString() ?? '');
    _nextServiceCtrl =
        TextEditingController(text: v?.nextServiceMileage.toString() ?? '');
    _notesCtrl = TextEditingController(text: v?.notes ?? '');
    _fuelLimitCtrl = TextEditingController(
        text: v?.monthlyFuelLimitLiters?.toString() ?? '');
    _lastServiceDate = v?.lastServiceDate;
    _photoPath = v?.photoPath;
    _cedulaVerdePath = v?.cedulaVerdePath;
    _tituloPath = v?.tituloPath;
    _vtvPath = v?.vtvPath;
    _seguroPath = v?.seguroPath;
    _iconKey = v?.iconKey;
    if (_isEditing) _loadObservationPhotos();
  }

  Future<void> _loadObservationPhotos() async {
    final photos =
        await DatabaseHelper.instance.getObservationPhotos(widget.vehicle!.id);
    if (mounted) setState(() => _observationPhotos = photos);
  }

  Future<void> _addObservationPhoto(String path) async {
    final photo = ObservationPhoto(
      id: const Uuid().v4(),
      vehicleId: widget.vehicle!.id,
      photoPath: path,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.insertObservationPhoto(photo);
    unawaited(SyncService.instance.pushObservationPhoto(photo));
    await _loadObservationPhotos();
  }

  Future<void> _deleteObservationPhoto(String id) async {
    await DatabaseHelper.instance.deleteObservationPhoto(id);
    unawaited(SyncService.instance.deleteObservationPhotoRemote(id));
    await _loadObservationPhotos();
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _internalNumberCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _mileageCtrl.dispose();
    _nextServiceCtrl.dispose();
    _notesCtrl.dispose();
    _fuelLimitCtrl.dispose();
    super.dispose();
  }

  Future<String?> _showPhotoSheet() async {
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
    if (source == null) return null;
    return ImagePickerService.pickAndSave(fromCamera: source);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _lastServiceDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<VehicleProvider>();
    final fuelLimitText = _fuelLimitCtrl.text.trim().replaceAll(',', '.');
    final fuelLimit = fuelLimitText.isEmpty ? null : double.tryParse(fuelLimitText);

    try {
      if (_isEditing) {
        final updated = widget.vehicle!.copyWith(
          plate: _plateCtrl.text.trim(),
          internalNumber: _internalNumberCtrl.text.trim(),
          brand: _brandCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          vehicleType: _vehicleType ?? '',
          currentMileage: int.parse(_mileageCtrl.text),
          nextServiceMileage: int.parse(_nextServiceCtrl.text),
          lastServiceDate: _lastServiceDate,
          notes: _notesCtrl.text.trim(),
          photoPath: _photoPath,
          cedulaVerdePath: _cedulaVerdePath,
          tituloPath: _tituloPath,
          vtvPath: _vtvPath,
          seguroPath: _seguroPath,
          iconKey: _iconKey,
          monthlyFuelLimitLiters: fuelLimit,
          clearMonthlyFuelLimitLiters: fuelLimit == null,
        );
        await provider.updateVehicle(updated);
      } else {
        await provider.addVehicle(
          plate: _plateCtrl.text.trim(),
          internalNumber: _internalNumberCtrl.text.trim(),
          brand: _brandCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          vehicleType: _vehicleType ?? '',
          currentMileage: int.parse(_mileageCtrl.text),
          nextServiceMileage: int.parse(_nextServiceCtrl.text),
          lastServiceDate: _lastServiceDate,
          notes: _notesCtrl.text.trim(),
          photoPath: _photoPath,
          cedulaVerdePath: _cedulaVerdePath,
          tituloPath: _tituloPath,
          vtvPath: _vtvPath,
          seguroPath: _seguroPath,
          iconKey: _iconKey,
          monthlyFuelLimitLiters: fuelLimit,
        );
      }
    } on DatabaseException catch (e) {
      if (!mounted) return;
      final message = e.isUniqueConstraintError()
          ? 'Ya existe un vehículo cargado con esa patente.'
          : 'No se pudo guardar el vehículo.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteOrMove() async {
    final v = widget.vehicle!;
    final result = await showDeleteOrMoveDialog(
      context,
      itemLabel: '${v.internalNumber} · ${v.plate}',
      currentComplexId: v.complexId,
      deleteWarning:
          'Se borra también su historial de mantenimiento, combustible y ficha técnica.',
    );
    if (result == null || !mounted) return;
    final provider = context.read<VehicleProvider>();
    if (result.delete) {
      await provider.deleteVehicle(v);
    } else {
      await provider.moveToComplex(v, result.targetComplexId!);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dar de baja el vehículo'),
        content: const Text(
          'El vehículo deja de aparecer en la lista y en las alertas, '
          'pero no se borra nada: se puede reactivar en cualquier '
          'momento desde "Archivados" en el panel de administración.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dar de baja')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<VehicleProvider>().archive(widget.vehicle!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGod = context.watch<AuthProvider>().isGod;
    final flags = context.watch<FeatureFlagsProvider>();
    // widget.readOnly ya indica "usuario común" en esta pantalla, pero
    // por las dudas se vuelve a chequear el rol acá también: el admin
    // siempre ve las 3 secciones, sin importar lo que él mismo haya
    // configurado en "Pestañas visibles".
    bool canSee(String key) => isGod || flags.isEnabled(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly
            ? 'Detalle del vehículo'
            : (_isEditing ? 'Editar vehículo' : 'Nuevo vehículo')),
        actions: [
          if (_isEditing && !widget.readOnly)
            IconButton(
                tooltip: 'Dar de baja (archivar)',
                onPressed: _archive,
                icon: const Icon(Icons.archive_outlined)),
          if (_isEditing && !widget.readOnly)
            IconButton(
                tooltip: 'Eliminar o mover de complejo',
                onPressed: _deleteOrMove,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: widget.readOnly
                    ? null
                    : () async {
                        final path = await _showPhotoSheet();
                        if (path != null) setState(() => _photoPath = path);
                      },
                child: Container(
                  width: 140,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (_photoPath != null && File(_photoPath!).existsSync())
                      ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                      : Icon(Icons.local_shipping,
                          size: 40, color: Colors.grey.shade500),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                widget.readOnly ? 'Foto del vehículo' : 'Tocar para agregar foto',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _plateCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Patente / Dominio', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _internalNumberCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Número interno', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _brandCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Marca', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Modelo', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: const InputDecoration(
                  labelText: 'Tipo de vehículo', border: OutlineInputBorder()),
              items: _vehicleTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: widget.readOnly
                  ? null
                  : (value) => setState(() => _vehicleType = value),
            ),
            const SizedBox(height: 16),
            IconPickerTile(
              label: 'Ícono del vehículo',
              iconKey: _iconKey,
              choices: kVehicleIconChoices,
              fallbackIcon: Icons.local_shipping,
              color: Theme.of(context).colorScheme.primary,
              readOnly: widget.readOnly,
              onPicked: (key) => setState(() => _iconKey = key),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mileageCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Kilometraje actual', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                if (int.tryParse(v) == null) return 'Debe ser un número entero';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nextServiceCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Próximo service (km)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                if (int.tryParse(v) == null) return 'Debe ser un número entero';
                return null;
              },
            ),
            Builder(builder: (context) {
              final interval =
                  serviceIntervalKmFor(_brandCtrl.text, _modelCtrl.text);
              if (interval == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Este campo se actualiza solo (cada $interval km) cada '
                  'vez que cargues un "Service" en el historial del vehículo.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              );
            }),
            const SizedBox(height: 16),
            InkWell(
              onTap: widget.readOnly ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Fecha del último service',
                    border: OutlineInputBorder()),
                child: Text(_lastServiceDate == null
                    ? 'Seleccionar fecha'
                    : DateFormat('dd/MM/yyyy').format(_lastServiceDate!)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fuelLimitCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Límite de combustible por mes (litros, opcional)',
                  helperText:
                      'Al llegar a este número entre todas las cargas del mes, '
                      'sale una notificación. Dejalo vacío para no limitar.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // opcional
                if (double.tryParse(v.trim().replaceAll(',', '.')) == null) {
                  return 'Ingresá un número válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Observaciones / Historial de mantenimiento',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true),
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            if (_isEditing)
              PhotoGallerySection(
                title: 'Fotos adjuntas a las observaciones',
                photos: _observationPhotos
                    .map((p) => GalleryPhoto(id: p.id, path: p.photoPath))
                    .toList(),
                readOnly: widget.readOnly,
                onAdd: _addObservationPhoto,
                onDelete: _deleteObservationPhoto,
              )
            else
              Text(
                'Guardá el vehículo primero para poder adjuntar fotos a las observaciones.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 24),
            const Text('Documentación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            PhotoPickerTile(
              label: 'Cédula verde',
              photoPath: _cedulaVerdePath,
              readOnly: widget.readOnly,
              placeholderIcon: Icons.badge_outlined,
              onPicked: (path) => setState(() => _cedulaVerdePath = path),
            ),
            const SizedBox(height: 8),
            PhotoPickerTile(
              label: 'Título del automotor',
              photoPath: _tituloPath,
              readOnly: widget.readOnly,
              placeholderIcon: Icons.description_outlined,
              onPicked: (path) => setState(() => _tituloPath = path),
            ),
            const SizedBox(height: 8),
            PhotoPickerTile(
              label: 'VTV',
              photoPath: _vtvPath,
              readOnly: widget.readOnly,
              placeholderIcon: Icons.fact_check_outlined,
              onPicked: (path) => setState(() => _vtvPath = path),
            ),
            const SizedBox(height: 8),
            PhotoPickerTile(
              label: 'Seguro del móvil',
              photoPath: _seguroPath,
              readOnly: widget.readOnly,
              placeholderIcon: Icons.verified_user_outlined,
              onPicked: (path) => setState(() => _seguroPath = path),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              if (canSee('maintenance_records')) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Ver historial de arreglos y averías'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaintenanceRecordsScreen(
                        vehicleId: widget.vehicle!.id,
                        vehicleLabel:
                            '${widget.vehicle!.internalNumber} · ${widget.vehicle!.plate}',
                        readOnly: widget.readOnly,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (canSee('fuel_log')) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.local_gas_station_outlined),
                  label: const Text('Combustible'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FuelLogScreen(
                        vehicle: widget.vehicle!,
                        readOnly: widget.readOnly,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (canSee('tech_sheet'))
                OutlinedButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Ficha técnica'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TechSheetScreen(
                        vehicle: widget.vehicle!,
                        readOnly: widget.readOnly,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            if (!widget.readOnly)
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_isEditing ? 'Guardar cambios' : 'Guardar vehículo'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
