import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/entity_icons.dart';
import '../../widgets/status_badge.dart';
import 'archived_vehicles_screen.dart';
import 'vehicle_form_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  String _query = '';
  MaintenanceStatus? _statusFilter;

  List<Vehicle> _filter(List<Vehicle> vehicles) {
    final q = _query.trim().toLowerCase();
    return vehicles.where((v) {
      if (_statusFilter != null && v.maintenanceStatus != _statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = [
        v.plate, v.internalNumber, v.brand, v.model, v.vehicleType,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    final isGod = context.watch<AuthProvider>().isGod;
    final vehicles = _filter(provider.vehicles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehículos'),
        actions: [
          if (isGod)
            IconButton(
              tooltip: 'Archivados',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ArchivedVehiclesScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por patente, número, marca o modelo...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _statusFilter == null,
                    onSelected: (_) => setState(() => _statusFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Al día'),
                    selected: _statusFilter == MaintenanceStatus.ok,
                    onSelected: (_) =>
                        setState(() => _statusFilter = MaintenanceStatus.ok),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Próximos'),
                    selected: _statusFilter == MaintenanceStatus.warning,
                    onSelected: (_) => setState(
                        () => _statusFilter = MaintenanceStatus.warning),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Vencidos'),
                    selected: _statusFilter == MaintenanceStatus.overdue,
                    onSelected: (_) => setState(
                        () => _statusFilter = MaintenanceStatus.overdue),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vehicles.isEmpty
                    ? Center(
                        child: Text(
                          provider.vehicles.isEmpty
                              ? 'No hay vehículos cargados.'
                              : 'Ningún vehículo coincide con la búsqueda.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final v = vehicles[index];
                          return _VehicleTile(vehicle: v, readOnly: !isGod);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isGod
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
              ),
            )
          : null,
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final Vehicle vehicle;
  final bool readOnly;
  const _VehicleTile({required this.vehicle, required this.readOnly});

  Color _statusColor() {
    switch (vehicle.maintenanceStatus) {
      case MaintenanceStatus.ok:
        return Colors.green;
      case MaintenanceStatus.warning:
        return Colors.amber.shade800;
      case MaintenanceStatus.overdue:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _statusColor().withOpacity(0.15),
          child: Icon(
            resolveEntityIcon(
                kVehicleIconChoices, vehicle.iconKey, Icons.local_shipping),
            color: _statusColor(),
          ),
        ),
        title: Text('${vehicle.internalNumber} · ${vehicle.plate}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text([
          if (vehicle.brand.isNotEmpty || vehicle.model.isNotEmpty)
            '${vehicle.brand} ${vehicle.model}'.trim(),
          if (vehicle.vehicleType.isNotEmpty) vehicle.vehicleType,
          '${vehicle.currentMileage} km actuales',
          'Próx. service: ${vehicle.nextServiceMileage} km',
        ].join(' · ')),
        trailing: StatusBadge.forMaintenance(vehicle.maintenanceStatus),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  VehicleFormScreen(vehicle: vehicle, readOnly: readOnly)),
        ),
      ),
    );
  }
}
