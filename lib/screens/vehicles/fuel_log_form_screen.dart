import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_provider.dart';
import '../../providers/fuel_provider.dart';
import '../../widgets/photo_picker_tile.dart';

class FuelLogFormScreen extends StatefulWidget {
  final String vehicleId;

  const FuelLogFormScreen({super.key, required this.vehicleId});

  @override
  State<FuelLogFormScreen> createState() => _FuelLogFormScreenState();
}

class _FuelLogFormScreenState extends State<FuelLogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litersCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  TextEditingController? _driverFieldController;
  DateTime _date = DateTime.now();
  String? _ticketPhotoPath;
  bool _saving = false;

  @override
  void dispose() {
    _litersCtrl.dispose();
    _mileageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await context.read<FuelProvider>().addFuelLog(
            vehicleId: widget.vehicleId,
            date: _date,
            liters: double.parse(_litersCtrl.text.replaceAll(',', '.')),
            mileage: int.parse(_mileageCtrl.text),
            driverName: (_driverFieldController?.text.trim().isEmpty ?? true)
                ? null
                : _driverFieldController!.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            ticketPhotoPath: _ticketPhotoPath,
          );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      // Antes, si esto fallaba por cualquier motivo, la pantalla se
      // quedaba trabada en "cargando" para siempre, sin avisar nada.
      // Ahora siempre se destraba y muestra el motivo real.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la carga: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cargar combustible')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                controller: _litersCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Litros', border: OutlineInputBorder()),
                validator: (v) => (double.tryParse(
                            (v ?? '').replaceAll(',', '.')) ==
                        null)
                    ? 'Ingresá un número válido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mileageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Kilometraje', border: OutlineInputBorder()),
                validator: (v) =>
                    (int.tryParse(v ?? '') == null) ? 'Ingresá un número' : null,
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue value) {
                  final names = context
                      .read<DriverProvider>()
                      .drivers
                      .map((d) => d.fullName)
                      .toList();
                  if (value.text.isEmpty) return names;
                  final query = value.text.toLowerCase();
                  return names.where((n) => n.toLowerCase().contains(query));
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  _driverFieldController = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                        labelText: 'Chofer que hace la carga (opcional)',
                        border: OutlineInputBorder()),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              PhotoPickerTile(
                label: 'Foto del ticket (opcional)',
                photoPath: _ticketPhotoPath,
                readOnly: false,
                placeholderIcon: Icons.receipt_long_outlined,
                onPicked: (path) => setState(() => _ticketPhotoPath = path),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar carga'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
