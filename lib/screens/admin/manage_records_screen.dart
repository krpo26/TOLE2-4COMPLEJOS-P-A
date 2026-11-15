import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/complex.dart';
import '../../models/driver.dart';
import '../../models/vehicle.dart';
import '../../providers/driver_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/database_helper.dart';
import '../../services/excel_export_service.dart';

/// Pantalla del administrador para trabajar con VARIOS vehículos o
/// choferes a la vez, de cualquiera de los 4 complejos:
///  - Mover a otro complejo
///  - Descargar (Excel)
///  - Borrar definitivamente (desaparece de todos los celulares)
class ManageRecordsScreen extends StatefulWidget {
  /// Si se indica, arranca filtrado en ese complejo.
  final String? initialComplexId;
  const ManageRecordsScreen({super.key, this.initialComplexId});

  @override
  State<ManageRecordsScreen> createState() => _ManageRecordsScreenState();
}

class _ManageRecordsScreenState extends State<ManageRecordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  List<Vehicle> _vehicles = [];
  List<Driver> _drivers = [];
  final Set<String> _selVehicles = {};
  final Set<String> _selDrivers = {};
  String? _complexFilter;
  bool _loading = true;
  bool _working = false;

  bool get _onVehicles => _tab.index == 0;
  Set<String> get _selection => _onVehicles ? _selVehicles : _selDrivers;

  @override
  void initState() {
    super.initState();
    _complexFilter = widget.initialComplexId;
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final v = await db.getVehicles(includeArchived: true);
    final d = await db.getDrivers(includeArchived: true);
    if (!mounted) return;
    setState(() {
      _vehicles = v;
      _drivers = d;
      _selVehicles.removeWhere((id) => !v.any((x) => x.id == id));
      _selDrivers.removeWhere((id) => !d.any((x) => x.id == id));
      _loading = false;
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  List<Vehicle> get _shownVehicles {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _vehicles
        .where((v) =>
            (_complexFilter == null || v.complexId == _complexFilter) &&
            (q.isEmpty ||
                '${v.plate} ${v.internalNumber} ${v.brand} ${v.model}'
                    .toLowerCase()
                    .contains(q)))
        .toList();
  }

  List<Driver> get _shownDrivers {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _drivers
        .where((d) =>
            (_complexFilter == null || d.complexId == _complexFilter) &&
            (q.isEmpty ||
                '${d.fullName} ${d.documentId}'.toLowerCase().contains(q)))
        .toList();
  }

  void _toggleAll() {
    final ids = _onVehicles
        ? _shownVehicles.map((v) => v.id).toList()
        : _shownDrivers.map((d) => d.id).toList();
    setState(() {
      if (ids.isNotEmpty && ids.every(_selection.contains)) {
        _selection.removeAll(ids);
      } else {
        _selection.addAll(ids);
      }
    });
  }

  // ---------------- ACCIONES ----------------

  Future<void> _move() async {
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Mover ${_selection.length} a…'),
        children: kComplexes
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c.id),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(c.icon, color: c.color),
                    title: Text(c.name, style: const TextStyle(fontSize: 13)),
                  ),
                ))
            .toList(),
      ),
    );
    if (target == null || !mounted) return;
    setState(() => _working = true);
    var moved = 0;
    if (_onVehicles) {
      final provider = context.read<VehicleProvider>();
      for (final v in _vehicles.where((v) => _selVehicles.contains(v.id))) {
        if (v.complexId == target) continue;
        await provider.moveToComplex(v, target);
        moved++;
      }
      _selVehicles.clear();
    } else {
      final provider = context.read<DriverProvider>();
      for (final d in _drivers.where((d) => _selDrivers.contains(d.id))) {
        if (d.complexId == target) continue;
        await provider.moveToComplex(d, target);
        moved++;
      }
      _selDrivers.clear();
    }
    await _load();
    if (mounted) setState(() => _working = false);
    _snack('Se movieron $moved a ${complexById(target).shortName}.');
  }

  Future<void> _download() async {
    try {
      if (_onVehicles) {
        await ExcelExportService.exportVehicleSelection(
            _vehicles.where((v) => _selVehicles.contains(v.id)).toList());
      } else {
        await ExcelExportService.exportDriverSelection(
            _drivers.where((d) => _selDrivers.contains(d.id)).toList());
      }
    } catch (_) {
      _snack('No se pudo generar el archivo.');
    }
  }

  Future<void> _delete() async {
    final n = _selection.length;
    final what = _onVehicles ? 'vehículo(s)' : 'chofer(es)';
    final extra = _onVehicles
        ? ' Se borra también su historial de mantenimiento, combustible y ficha técnica.'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar definitivamente'),
        content: Text(
            'Se borran $n $what de todos los dispositivos. No se puede deshacer.$extra'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar para siempre')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _working = true);
    if (_onVehicles) {
      final provider = context.read<VehicleProvider>();
      for (final v in _vehicles.where((v) => _selVehicles.contains(v.id))) {
        await provider.deleteVehicle(v);
      }
      _selVehicles.clear();
    } else {
      final provider = context.read<DriverProvider>();
      for (final d in _drivers.where((d) => _selDrivers.contains(d.id))) {
        await provider.deleteDriver(d);
      }
      _selDrivers.clear();
    }
    await _load();
    if (mounted) setState(() => _working = false);
    _snack('Se eliminaron $n $what.');
  }

  // ---------------- PANTALLA ----------------

  @override
  Widget build(BuildContext context) {
    final vehicles = _shownVehicles;
    final drivers = _shownDrivers;
    final count = _selection.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mover, descargar o borrar'),
        actions: [
          IconButton(
            tooltip: 'Seleccionar / quitar todos',
            icon: const Icon(Icons.select_all),
            onPressed: _toggleAll,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: 'Vehículos (${vehicles.length})'),
            Tab(text: 'Choferes (${drivers.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todos'),
                          selected: _complexFilter == null,
                          onSelected: (_) =>
                              setState(() => _complexFilter = null),
                        ),
                      ),
                      ...kComplexes.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.shortName),
                            selected: _complexFilter == c.id,
                            onSelected: (_) =>
                                setState(() => _complexFilter = c.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_working) const LinearProgressIndicator(),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildList(
                        empty: vehicles.isEmpty,
                        itemCount: vehicles.length,
                        builder: (i) {
                          final v = vehicles[i];
                          return CheckboxListTile(
                            value: _selVehicles.contains(v.id),
                            onChanged: (_) => setState(() {
                              if (!_selVehicles.add(v.id)) {
                                _selVehicles.remove(v.id);
                              }
                            }),
                            title: Text('${v.internalNumber} · ${v.plate}'),
                            subtitle: Text(
                                '${v.brand} ${v.model} · '
                                '${complexById(v.complexId).shortName}'
                                '${v.isArchived ? ' · ARCHIVADO' : ''}'),
                          );
                        },
                      ),
                      _buildList(
                        empty: drivers.isEmpty,
                        itemCount: drivers.length,
                        builder: (i) {
                          final d = drivers[i];
                          return CheckboxListTile(
                            value: _selDrivers.contains(d.id),
                            onChanged: (_) => setState(() {
                              if (!_selDrivers.add(d.id)) {
                                _selDrivers.remove(d.id);
                              }
                            }),
                            title: Text(d.fullName),
                            subtitle: Text(
                                'DNI ${d.documentId} · '
                                '${complexById(d.complexId).shortName}'
                                '${d.isArchived ? ' · ARCHIVADO' : ''}'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: count == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _working ? null : _move,
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: Text('Mover ($count)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _working ? null : _download,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Descargar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: _working ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Borrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildList({
    required bool empty,
    required int itemCount,
    required Widget Function(int) builder,
  }) {
    if (empty) {
      return const Center(
        child: Text('No hay elementos para mostrar.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(itemCount: itemCount, itemBuilder: (_, i) => builder(i));
  }
}
