import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../models/vehicle_tech_sheet.dart';
import '../../providers/tech_sheet_provider.dart';
import '../../services/excel_export_service.dart';

/// Ficha técnica de un vehículo: tabla de renglones (uno por cada
/// service/reparación cargada) con columnas FECHA, CHOFER, KILOMETRO,
/// REPUESTOS y COMERCIO — igual que la planilla de Excel que se
/// usaba antes. Se puede exportar a Excel.
class TechSheetScreen extends StatelessWidget {
  final Vehicle vehicle;
  final bool readOnly;

  const TechSheetScreen({
    super.key,
    required this.vehicle,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TechSheetProvider()..load(vehicle.id),
      child: _TechSheetView(vehicle: vehicle, readOnly: readOnly),
    );
  }
}

class _TechSheetView extends StatelessWidget {
  final Vehicle vehicle;
  final bool readOnly;

  const _TechSheetView({required this.vehicle, required this.readOnly});

  Future<void> _delete(BuildContext context, TechSheetEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar renglón'),
        content: const Text('¿Eliminar este renglón de la ficha técnica?'),
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
      await context.read<TechSheetProvider>().delete(entry.id);
    }
  }

  Future<void> _openForm(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TechSheetEntryForm(
        provider: context.read<TechSheetProvider>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TechSheetProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Ficha técnica · ${vehicle.internalNumber}'),
        actions: [
          IconButton(
            tooltip: 'Exportar a Excel',
            icon: const Icon(Icons.grid_on_outlined),
            onPressed: provider.entries.isEmpty
                ? null
                : () => ExcelExportService.exportTechSheet(
                      vehicle: vehicle,
                      entries: provider.entries,
                    ),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay renglones cargados para este vehículo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('FECHA')),
                        DataColumn(label: Text('CHOFER')),
                        DataColumn(label: Text('KILOMETRO')),
                        DataColumn(label: Text('REPUESTOS')),
                        DataColumn(label: Text('COMERCIO')),
                        DataColumn(label: Text('')),
                      ],
                      rows: provider.entries.map((e) {
                        return DataRow(cells: [
                          DataCell(Text(DateFormat('dd/MM/yyyy').format(e.date))),
                          DataCell(Text(e.driverName ?? '')),
                          DataCell(Text(e.mileage?.toString() ?? '')),
                          DataCell(Text(e.parts ?? '')),
                          DataCell(Text(e.shop ?? '')),
                          DataCell(
                            readOnly
                                ? const SizedBox.shrink()
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(context, e),
                                  ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo renglón'),
              onPressed: () => _openForm(context),
            ),
    );
  }
}

/// Formulario para cargar un renglón nuevo de la ficha técnica.
class _TechSheetEntryForm extends StatefulWidget {
  final TechSheetProvider provider;

  const _TechSheetEntryForm({required this.provider});

  @override
  State<_TechSheetEntryForm> createState() => _TechSheetEntryFormState();
}

class _TechSheetEntryFormState extends State<_TechSheetEntryForm> {
  DateTime _date = DateTime.now();
  final _driverCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _partsCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _driverCtrl.dispose();
    _mileageCtrl.dispose();
    _partsCtrl.dispose();
    _shopCtrl.dispose();
    super.dispose();
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
    setState(() => _saving = true);
    await widget.provider.add(
      date: _date,
      driverName:
          _driverCtrl.text.trim().isEmpty ? null : _driverCtrl.text.trim(),
      mileage: int.tryParse(_mileageCtrl.text.trim()),
      parts: _partsCtrl.text.trim().isEmpty ? null : _partsCtrl.text.trim(),
      shop: _shopCtrl.text.trim().isEmpty ? null : _shopCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nuevo renglón', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'FECHA',
                border: OutlineInputBorder(),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _driverCtrl,
            decoration: const InputDecoration(
                labelText: 'CHOFER', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mileageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'KILOMETRO', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _partsCtrl,
            decoration: const InputDecoration(
                labelText: 'REPUESTOS', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shopCtrl,
            decoration: const InputDecoration(
                labelText: 'COMERCIO', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
