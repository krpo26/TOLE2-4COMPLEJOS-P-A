import '../../widgets/delete_or_move_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/entity_icons.dart';

/// Vehículos dados de baja ("archivados"). Desde acá se pueden
/// reactivar (vuelven a aparecer en la lista normal y en las alertas)
/// o eliminar definitivamente (esto sí borra el registro para
/// siempre, incluida su nube si está conectada).
class ArchivedVehiclesScreen extends StatefulWidget {
  const ArchivedVehiclesScreen({super.key});

  @override
  State<ArchivedVehiclesScreen> createState() =>
      _ArchivedVehiclesScreenState();
}

class _ArchivedVehiclesScreenState extends State<ArchivedVehiclesScreen> {
  late Future<List<Vehicle>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<VehicleProvider>().getArchived();
    });
  }

  Future<void> _unarchive(Vehicle v) async {
    await context.read<VehicleProvider>().unarchive(v);
    if (!mounted) return;
    _reload();
  }

  Future<void> _deleteForever(Vehicle v) async {
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
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehículos archivados')),
      body: FutureBuilder<List<Vehicle>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
                child: Text('No hay vehículos archivados.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final v = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    child: Icon(
                      resolveEntityIcon(kVehicleIconChoices, v.iconKey,
                          Icons.local_shipping),
                      color: Colors.grey.shade700,
                    ),
                  ),
                  title: Text('${v.internalNumber} · ${v.plate}'),
                  subtitle: Text('${v.brand} ${v.model}'.trim()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reactivar',
                        icon: const Icon(Icons.unarchive_outlined),
                        onPressed: () => _unarchive(v),
                      ),
                      IconButton(
                        tooltip: 'Eliminar definitivamente',
                        icon: const Icon(Icons.delete_forever_outlined,
                            color: Colors.red),
                        onPressed: () => _deleteForever(v),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
