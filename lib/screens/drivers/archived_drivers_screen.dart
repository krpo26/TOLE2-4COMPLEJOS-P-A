import '../../widgets/delete_or_move_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/driver.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/entity_icons.dart';

/// Choferes dados de baja ("archivados"). Desde acá se pueden
/// reactivar o eliminar definitivamente.
class ArchivedDriversScreen extends StatefulWidget {
  const ArchivedDriversScreen({super.key});

  @override
  State<ArchivedDriversScreen> createState() => _ArchivedDriversScreenState();
}

class _ArchivedDriversScreenState extends State<ArchivedDriversScreen> {
  late Future<List<Driver>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<DriverProvider>().getArchived();
    });
  }

  Future<void> _unarchive(Driver d) async {
    await context.read<DriverProvider>().unarchive(d);
    if (!mounted) return;
    _reload();
  }

  Future<void> _deleteForever(Driver d) async {
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
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choferes archivados')),
      body: FutureBuilder<List<Driver>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No hay choferes archivados.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final d = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    child: Icon(
                      resolveEntityIcon(
                          kDriverIconChoices, d.iconKey, Icons.person),
                      color: Colors.grey.shade700,
                    ),
                  ),
                  title: Text(d.fullName),
                  subtitle: Text('DNI ${d.documentId}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reactivar',
                        icon: const Icon(Icons.unarchive_outlined),
                        onPressed: () => _unarchive(d),
                      ),
                      IconButton(
                        tooltip: 'Eliminar definitivamente',
                        icon: const Icon(Icons.delete_forever_outlined,
                            color: Colors.red),
                        onPressed: () => _deleteForever(d),
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
