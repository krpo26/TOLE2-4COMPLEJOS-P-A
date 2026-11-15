import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/maintenance_record.dart';
import '../../models/record_photo.dart';
import '../../models/service_intervals.dart';
import '../../models/vehicle.dart';
import '../../services/database_helper.dart';
import '../../services/image_picker_service.dart';
import '../../services/sync_service.dart';

class MaintenanceRecordFormScreen extends StatefulWidget {
  final String vehicleId;
  const MaintenanceRecordFormScreen({super.key, required this.vehicleId});

  @override
  State<MaintenanceRecordFormScreen> createState() =>
      _MaintenanceRecordFormScreenState();
}

class _MaintenanceRecordFormScreenState
    extends State<MaintenanceRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  MaintenanceEventType _type = MaintenanceEventType.repair;
  DateTime _date = DateTime.now();
  bool _saving = false;
  final List<String> _pendingPhotoPaths = [];

  Future<void> _addPhoto() async {
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
    if (path != null) setState(() => _pendingPhotoPaths.add(path));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final record = MaintenanceRecord(
      id: const Uuid().v4(),
      vehicleId: widget.vehicleId,
      date: _date,
      type: _type,
      description: _descriptionCtrl.text.trim(),
      mileageAtEvent: _mileageCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_mileageCtrl.text.trim()),
      cost: _costCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')),
    );

    await DatabaseHelper.instance.insertMaintenanceRecord(record);
    unawaited(SyncService.instance.pushMaintenanceRecord(record));

    // Si se cargó un Service con kilometraje, se recalcula solo el
    // próximo kilometraje de service del vehículo (kilometraje de
    // este service + el intervalo según su marca/modelo), sin que
    // haga falta tocar nada más a mano.
    String? autoUpdateMessage;
    if (_type == MaintenanceEventType.service && record.mileageAtEvent != null) {
      final vehicle = await DatabaseHelper.instance.getVehicleById(widget.vehicleId);
      if (vehicle != null) {
        final interval = serviceIntervalKmFor(vehicle.brand, vehicle.model);
        if (interval != null) {
          final nextServiceMileage = record.mileageAtEvent! + interval;
          final updatedVehicle =
              vehicle.copyWith(nextServiceMileage: nextServiceMileage);
          await DatabaseHelper.instance.updateVehicle(updatedVehicle);
          unawaited(SyncService.instance.pushVehicle(updatedVehicle));
          autoUpdateMessage =
              'Próximo service actualizado a $nextServiceMileage km '
              '(cada $interval km para ${vehicle.brand} ${vehicle.model}).';
        }
      }
    }

    for (final path in _pendingPhotoPaths) {
      final photo = RecordPhoto(
        id: const Uuid().v4(),
        recordId: record.id,
        photoPath: path,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertRecordPhoto(photo);
      unawaited(SyncService.instance.pushRecordPhoto(photo));
    }

    if (mounted) Navigator.pop(context, autoUpdateMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo registro')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<MaintenanceEventType>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: 'Tipo de evento', border: OutlineInputBorder()),
              items: MaintenanceEventType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) => setState(() => _type = t!),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Fecha', border: OutlineInputBorder()),
                child: Text(DateFormat('dd/MM/yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                  labelText: 'Descripción (arreglo, avería, detalle)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true),
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mileageCtrl,
              decoration: const InputDecoration(
                  labelText: 'Kilometraje al momento (opcional)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costCtrl,
              decoration: const InputDecoration(
                  labelText: 'Costo (opcional)',
                  border: OutlineInputBorder(),
                  prefixText: '\$ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Fotos adjuntas',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Agregar foto'),
                ),
              ],
            ),
            if (_pendingPhotoPaths.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('Sin fotos adjuntas.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pendingPhotoPaths.map((path) {
                  return Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, size: 20),
                          onPressed: () =>
                              setState(() => _pendingPhotoPaths.remove(path)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_saving ? 'Guardando...' : 'Guardar registro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
