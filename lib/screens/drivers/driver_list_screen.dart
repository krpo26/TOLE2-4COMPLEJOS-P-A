import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/driver.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/entity_icons.dart';
import '../../widgets/status_badge.dart';
import 'archived_drivers_screen.dart';
import 'driver_form_screen.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  String _query = '';

  Color _statusColor(Driver d) {
    switch (d.licenseStatus) {
      case LicenseStatus.ok:
        return Colors.green;
      case LicenseStatus.warning:
        return Colors.amber.shade800;
      case LicenseStatus.expired:
        return Colors.red;
    }
  }

  List<Driver> _filter(List<Driver> drivers) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return drivers;
    return drivers.where((d) {
      final haystack = [
        d.fullName, d.documentId, d.cargoNumber ?? '', d.address ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final isGod = context.watch<AuthProvider>().isGod;
    final drivers = _filter(provider.drivers);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choferes'),
        actions: [
          if (isGod)
            IconButton(
              tooltip: 'Archivados',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ArchivedDriversScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, DNI, cargo o dirección...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : drivers.isEmpty
                    ? Center(
                        child: Text(
                          provider.drivers.isEmpty
                              ? 'No hay choferes cargados.'
                              : 'Ningún chofer coincide con la búsqueda.',
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest),
                            columns: const [
                              DataColumn(label: Text('')),
                              DataColumn(label: Text('Apellido y Nombre')),
                              DataColumn(label: Text('N° de cargo')),
                              DataColumn(label: Text('DNI')),
                              DataColumn(label: Text('Categoría')),
                              DataColumn(label: Text('Vence carnet')),
                              DataColumn(label: Text('Estado')),
                            ],
                            rows: drivers.map((d) {
                              return DataRow(
                                onSelectChanged: (_) => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DriverFormScreen(
                                        driver: d, readOnly: !isGod),
                                  ),
                                ),
                                cells: [
                                  DataCell(CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        _statusColor(d).withOpacity(0.15),
                                    child: Icon(
                                      resolveEntityIcon(kDriverIconChoices,
                                          d.iconKey, Icons.person),
                                      size: 18,
                                      color: _statusColor(d),
                                    ),
                                  )),
                                  DataCell(Text(d.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))),
                                  DataCell(Text(
                                      d.cargoNumber?.isNotEmpty == true
                                          ? d.cargoNumber!
                                          : '—')),
                                  DataCell(Text(d.documentId)),
                                  DataCell(Text(d.licenseCategory)),
                                  DataCell(Text(DateFormat('dd/MM/yyyy')
                                      .format(d.licenseExpiration))),
                                  DataCell(
                                      StatusBadge.forLicense(d.licenseStatus)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
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
                MaterialPageRoute(builder: (_) => const DriverFormScreen()),
              ),
            )
          : null,
    );
  }
}
