import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/tramite.dart';
import '../../providers/tramite_provider.dart';

/// Alta / edición de un trámite: móvil, tipo de trámite, fecha de
/// inicio, estado y número de expediente.
class TramiteFormScreen extends StatefulWidget {
  final Tramite? tramite;
  final bool readOnly;
  const TramiteFormScreen({super.key, this.tramite, this.readOnly = false});

  @override
  State<TramiteFormScreen> createState() => _TramiteFormScreenState();
}

class _TramiteFormScreenState extends State<TramiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fileCtrl;
  late final TextEditingController _detailCtrl;
  String? _vehicleId;
  late TramiteType _type;
  late TramiteStatus _status;
  late DateTime _startDate;
  bool _saving = false;

  bool get _editing => widget.tramite != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tramite;
    _fileCtrl = TextEditingController(text: t?.fileNumber ?? '');
    _detailCtrl = TextEditingController(text: t?.detail ?? '');
    _vehicleId = t?.vehicleId;
    _type = t?.type ?? TramiteType.service;
    _status = t?.status ?? TramiteStatus.iniciado;
    _startDate = t?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _fileCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<TramiteProvider>();
    final file = _fileCtrl.text.trim();
    final detail = _detailCtrl.text.trim();
    if (_editing) {
      await provider.update(widget.tramite!.copyWith(
        vehicleId: _vehicleId,
        type: _type,
        startDate: _startDate,
        status: _status,
        fileNumber: file,
        detail: detail,
      ));
    } else {
      await provider.add(
        vehicleId: _vehicleId!,
        type: _type,
        startDate: _startDate,
        status: _status,
        fileNumber: file,
        detail: detail,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar trámite'),
        content: Text(
            'Se borra el trámite Exp. ${widget.tramite!.fileNumber} de todos los dispositivos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<TramiteProvider>().delete(widget.tramite!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TramiteProvider>();
    final vehicles = provider.vehiclesById.values
        .where((v) => !v.isArchived || v.id == _vehicleId)
        .toList()
      ..sort((a, b) => a.internalNumber.compareTo(b.internalNumber));
    final enabled = !widget.readOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Trámite' : 'Cargar trámite'),
        actions: [
          if (_editing && enabled)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: vehicles.any((v) => v.id == _vehicleId) ? _vehicleId : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Móvil',
                border: OutlineInputBorder(),
              ),
              items: vehicles
                  .map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text(
                            '${v.internalNumber} · ${v.plate}'
                            '${v.brand.isEmpty ? '' : ' · ${v.brand} ${v.model}'}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: enabled ? (v) => setState(() => _vehicleId = v) : null,
              validator: (v) => v == null ? 'Elegí un móvil' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TramiteType>(
              value: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trámite',
                border: OutlineInputBorder(),
              ),
              items: TramiteType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Row(children: [
                          Icon(t.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(t.label),
                        ]),
                      ))
                  .toList(),
              onChanged: enabled
                  ? (v) => setState(() => _type = v ?? TramiteType.service)
                  : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: enabled ? _pickDate : null,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de inicio del trámite',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TramiteStatus>(
              value: _status,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Estado del trámite',
                border: OutlineInputBorder(),
              ),
              items: TramiteStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(children: [
                          Icon(Icons.circle, size: 12, color: s.color),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ]),
                      ))
                  .toList(),
              onChanged: enabled
                  ? (v) => setState(() => _status = v ?? TramiteStatus.iniciado)
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fileCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Número de expediente',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresá el número de expediente'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailCtrl,
              enabled: enabled,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _type == TramiteType.otro
                    ? 'Detalle del trámite'
                    : 'Detalle (opcional)',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (_type == TramiteType.otro &&
                      (v == null || v.trim().isEmpty))
                  ? 'Describí de qué trámite se trata'
                  : null,
            ),
            const SizedBox(height: 24),
            if (enabled)
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_editing ? 'Guardar cambios' : 'Cargar trámite'),
              ),
          ],
        ),
      ),
    );
  }
}
