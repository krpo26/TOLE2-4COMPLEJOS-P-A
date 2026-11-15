import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/fuel_log.dart';
import '../../models/vehicle.dart';
import '../../providers/fuel_provider.dart';
import '../../services/excel_export_service.dart';
import 'fuel_log_form_screen.dart';
import 'fuel_stations_screen.dart';

const _kMonthNames = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String monthKeyLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return monthKey;
  return '${_kMonthNames[month]} ${parts[0]}';
}

/// Planilla de combustible de un vehículo. Por defecto muestra el mes
/// en curso (que arranca vacío al empezar cada mes), con un selector
/// para consultar meses anteriores sin perder ese historial. Cada mes
/// se puede exportar a Excel por separado.
class FuelLogScreen extends StatelessWidget {
  final Vehicle vehicle;
  final bool readOnly;

  const FuelLogScreen({
    super.key,
    required this.vehicle,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FuelProvider()..load(vehicle.id),
      child: _FuelLogView(vehicle: vehicle, readOnly: readOnly),
    );
  }
}

class _FuelLogView extends StatelessWidget {
  final Vehicle vehicle;
  final bool readOnly;

  const _FuelLogView({required this.vehicle, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FuelProvider>();
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('Combustible · ${vehicle.internalNumber}'),
        actions: [
          IconButton(
            tooltip: 'Estaciones Ticket Car',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FuelStationsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Exportar este mes a Excel',
            icon: const Icon(Icons.grid_on_outlined),
            onPressed: provider.logs.isEmpty
                ? null
                : () => ExcelExportService.exportFuelLogsForMonth(
                      vehicle: vehicle,
                      monthKey: provider.selectedMonthKey,
                      logs: provider.logs,
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: provider.selectedMonthKey,
              decoration: const InputDecoration(
                labelText: 'Mes',
                border: OutlineInputBorder(),
              ),
              items: provider.availableMonths
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(monthKeyLabel(m)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  context.read<FuelProvider>().changeMonth(vehicle.id, value);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Total litros: ${provider.totalLiters.toStringAsFixed(1)}'),
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.logs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Sin cargas registradas en este mes todavía.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: provider.logs.length,
                        itemBuilder: (context, index) {
                          final log = provider.logs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.local_gas_station_outlined),
                              ),
                              title:
                                  Text('${log.liters.toStringAsFixed(1)} L'),
                              subtitle: Text([
                                dateFmt.format(log.date),
                                if (log.driverName != null &&
                                    log.driverName!.isNotEmpty)
                                  log.driverName!,
                                '${log.mileage} km',
                              ].join(' · ')),
                              trailing: readOnly
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _confirmDelete(
                                          context, log, vehicle.id),
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Cargar combustible'),
              onPressed: () async {
                final fuelProvider = context.read<FuelProvider>();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: fuelProvider,
                      child: FuelLogFormScreen(vehicleId: vehicle.id),
                    ),
                  ),
                );
                await fuelProvider.load(vehicle.id,
                    monthKey: fuelProvider.selectedMonthKey);
              },
            ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, FuelLog log, String vehicleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar carga'),
        content: const Text('¿Eliminar esta carga de combustible?'),
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
    if (confirmed == true && context.mounted) {
      await context.read<FuelProvider>().deleteFuelLog(vehicleId, log.id);
    }
  }
}
