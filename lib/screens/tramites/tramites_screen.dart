import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/complex.dart';
import '../../models/tramite.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tramite_provider.dart';
import '../../services/excel_export_service.dart';
import 'tramite_form_screen.dart';

/// Trámites de los móviles del complejo: se pueden ver, filtrar por
/// estado y descargar a Excel. El administrador además los carga,
/// modifica y elimina.
class TramitesScreen extends StatefulWidget {
  final Complex complex;
  const TramitesScreen({super.key, required this.complex});

  @override
  State<TramitesScreen> createState() => _TramitesScreenState();
}

class _TramitesScreenState extends State<TramitesScreen> {
  TramiteStatus? _statusFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    context.read<TramiteProvider>().load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TramiteProvider>();
    final isGod = context.watch<AuthProvider>().isGod;
    final fmt = DateFormat('dd/MM/yyyy');
    final q = _searchCtrl.text.trim().toLowerCase();

    final list = provider.tramites
        .where((t) =>
            (_statusFilter == null || t.status == _statusFilter) &&
            (q.isEmpty ||
                '${t.fileNumber} ${provider.vehicleLabel(t.vehicleId)} ${t.type.label} ${t.detail}'
                    .toLowerCase()
                    .contains(q)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trámites'),
        actions: [
          IconButton(
            tooltip: 'Descargar a Excel',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: list.isEmpty
                ? null
                : () => ExcelExportService.exportTramites(
                      tramites: list,
                      vehicleLabel: provider.vehicleLabel,
                      complexName: widget.complex.shortName,
                    ),
          ),
        ],
      ),
      floatingActionButton: isGod
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TramiteFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Cargar trámite'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar por expediente, móvil o trámite',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _statusFilter == null,
                    onSelected: (_) => setState(() => _statusFilter = null),
                  ),
                ),
                ...TramiteStatus.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: _statusFilter == s,
                      onSelected: (_) => setState(() => _statusFilter = s),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay trámites para mostrar.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final t = list[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TramiteFormScreen(
                                  tramite: t, readOnly: !isGod),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                t.status.color.withOpacity(0.15),
                            child: Icon(t.type.icon, color: t.status.color),
                          ),
                          title: Text(t.type.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Móvil ${provider.vehicleLabel(t.vehicleId)}\n'
                              'Exp. ${t.fileNumber} · Inicio ${fmt.format(t.startDate)}'),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(t.status.label,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white)),
                            backgroundColor: t.status.color,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
