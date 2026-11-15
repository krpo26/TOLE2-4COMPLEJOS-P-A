import '../../widgets/delete_or_move_dialog.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/driver.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/entity_icons.dart';

class DriverFormScreen extends StatefulWidget {
  final Driver? driver;
  final bool readOnly;

  const DriverFormScreen({super.key, this.driver, this.readOnly = false});

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _dniCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _cargoNumberCtrl;
  late final TextEditingController _addressCtrl;
  DateTime? _licenseExpiration;
  String? _photoPath;
  String? _licensePhotoPath;
  String? _iconKey;

  bool get _isEditing => widget.driver != null;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _nameCtrl = TextEditingController(text: d?.fullName ?? '');
    _dniCtrl = TextEditingController(text: d?.documentId ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _categoryCtrl = TextEditingController(text: d?.licenseCategory ?? '');
    _cargoNumberCtrl = TextEditingController(text: d?.cargoNumber ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _licenseExpiration = d?.licenseExpiration;
    _photoPath = d?.photoPath;
    _licensePhotoPath = d?.licensePhotoPath;
    _iconKey = d?.iconKey;
  }

  Future<void> _pickPhoto() async {
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
    if (path != null) setState(() => _photoPath = path);
  }

  Future<void> _pickLicensePhoto() async {
    final source = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto del carnet'),
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
    if (path != null) setState(() => _licensePhotoPath = path);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dniCtrl.dispose();
    _phoneCtrl.dispose();
    _categoryCtrl.dispose();
    _cargoNumberCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _licenseExpiration = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licenseExpiration == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Seleccioná la fecha de vencimiento del carnet')));
      return;
    }

    final provider = context.read<DriverProvider>();

    try {
      if (_isEditing) {
        final updated = widget.driver!.copyWith(
          fullName: _nameCtrl.text.trim(),
          documentId: _dniCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          licenseCategory: _categoryCtrl.text.trim(),
          licenseExpiration: _licenseExpiration,
          photoPath: _photoPath,
          licensePhotoPath: _licensePhotoPath,
          address: _addressCtrl.text.trim(),
          cargoNumber: _cargoNumberCtrl.text.trim(),
          iconKey: _iconKey,
        );
        await provider.updateDriver(updated);
      } else {
        await provider.addDriver(
          fullName: _nameCtrl.text.trim(),
          documentId: _dniCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          licenseCategory: _categoryCtrl.text.trim(),
          licenseExpiration: _licenseExpiration!,
          photoPath: _photoPath,
          licensePhotoPath: _licensePhotoPath,
          address: _addressCtrl.text.trim(),
          cargoNumber: _cargoNumberCtrl.text.trim(),
          iconKey: _iconKey,
        );
      }
    } on DatabaseException catch (e) {
      if (!mounted) return;
      final message = e.isUniqueConstraintError()
          ? 'Ya existe un chofer cargado con ese DNI.'
          : 'No se pudo guardar el chofer.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteOrMove() async {
    final d = widget.driver!;
    final result = await showDeleteOrMoveDialog(
      context,
      itemLabel: d.fullName,
      currentComplexId: d.complexId,
    );
    if (result == null || !mounted) return;
    final provider = context.read<DriverProvider>();
    if (result.delete) {
      await provider.deleteDriver(d);
    } else {
      await provider.moveToComplex(d, result.targetComplexId!);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dar de baja el chofer'),
        content: const Text(
          'El chofer deja de aparecer en la lista y en las alertas, '
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
      await context.read<DriverProvider>().archive(widget.driver!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGod = context.watch<AuthProvider>().isGod;
    final flags = context.watch<FeatureFlagsProvider>();
    bool canSee(String key) => isGod || flags.isEnabled(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly
            ? 'Detalle del chofer'
            : (_isEditing ? 'Editar chofer' : 'Nuevo chofer')),
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
                onTap: widget.readOnly ? null : _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (_photoPath != null &&
                              File(_photoPath!).existsSync())
                          ? FileImage(File(_photoPath!))
                          : null,
                      child: (_photoPath == null ||
                              !File(_photoPath!).existsSync())
                          ? Icon(
                              resolveEntityIcon(
                                  kDriverIconChoices, _iconKey, Icons.person),
                              size: 52,
                              color: Colors.grey.shade500)
                          : null,
                    ),
                    if (!widget.readOnly)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            IconPickerTile(
              label: 'Ícono del chofer',
              iconKey: _iconKey,
              choices: kDriverIconChoices,
              fallbackIcon: Icons.person,
              color: Theme.of(context).colorScheme.primary,
              readOnly: widget.readOnly,
              onPicked: (key) => setState(() => _iconKey = key),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Apellido y Nombre', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cargoNumberCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Número de cargo',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dniCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'DNI / Identificación',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            if (canSee('field_driver_phone')) ...[
              TextFormField(
                controller: _phoneCtrl,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                    labelText: 'Teléfono de contacto',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
            ],
            if (canSee('field_driver_address')) ...[
              TextFormField(
                controller: _addressCtrl,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                    labelText: 'Dirección', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _categoryCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                  labelText: 'Categoría de licencia / carnet',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: widget.readOnly ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Vencimiento del carnet de conducir',
                    border: OutlineInputBorder()),
                child: Text(_licenseExpiration == null
                    ? 'Seleccionar fecha'
                    : DateFormat('dd/MM/yyyy').format(_licenseExpiration!)),
              ),
            ),
            const SizedBox(height: 16),
            _LicensePhotoTile(
              photoPath: _licensePhotoPath,
              readOnly: widget.readOnly,
              onTap: _pickLicensePhoto,
            ),
            const SizedBox(height: 24),
            if (!widget.readOnly)
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_isEditing ? 'Guardar cambios' : 'Guardar chofer'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta para tomar/ver la foto del carnet de conducir, con vista
/// ampliada al tocar la miniatura.
class _LicensePhotoTile extends StatelessWidget {
  final String? photoPath;
  final bool readOnly;
  final VoidCallback onTap;

  const _LicensePhotoTile({
    required this.photoPath,
    required this.readOnly,
    required this.onTap,
  });

  bool get _hasPhoto => photoPath != null && File(photoPath!).existsSync();

  void _openFullscreen(BuildContext context) {
    if (!_hasPhoto) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Foto del carnet')),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(photoPath!)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _hasPhoto
            ? () => _openFullscreen(context)
            : (readOnly ? null : onTap),
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
                child: _hasPhoto
                    ? Image.file(File(photoPath!), fit: BoxFit.cover)
                    : Icon(Icons.badge_outlined, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Foto del carnet de conducir',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              if (!readOnly)
                IconButton(
                  icon: Icon(
                      _hasPhoto ? Icons.edit_outlined : Icons.add_a_photo_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  onPressed: onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
