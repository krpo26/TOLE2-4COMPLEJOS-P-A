import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/fuel_station.dart';
import '../../services/excel_export_service.dart';
import '../../services/fuel_station_service.dart';

/// Listado de estaciones de servicio adheridas a Ticket Car, con
/// buscador (por nombre, localidad, calle o provincia) y un filtro
/// por provincia.
///
/// Botón "Cerca de mí": toma la ubicación del celular y ordena las
/// estaciones de la provincia elegida de la más cercana a la más
/// lejana. Cada estación tiene su botón "Cómo llegar", que abre
/// Google Maps con la ruta desde donde está el celular.
class FuelStationsScreen extends StatefulWidget {
  const FuelStationsScreen({super.key});

  @override
  State<FuelStationsScreen> createState() => _FuelStationsScreenState();
}

class _FuelStationsScreenState extends State<FuelStationsScreen> {
  static const _defaultProvince = 'TUCUMAN';
  // Por encima de este número no se calculan distancias (cada dirección
  // se ubica una sola vez, pero conviene acotarlo a una provincia).
  static const _maxForDistance = 80;

  final _searchCtrl = TextEditingController();
  List<FuelStation> _all = [];
  List<FuelStation> _filtered = [];
  List<String> _provinces = [];
  String? _selectedProvince;
  bool _loading = true;

  // Distancia (en metros) desde el celular a cada estación.
  final Map<String, double> _distances = {};
  bool _locating = false;
  String _locatingText = '';
  bool _sortedByDistance = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  Future<void> _load() async {
    final stations = await FuelStationService.instance.loadAll();
    final provinces = await FuelStationService.instance.loadProvinces();
    if (!mounted) return;
    setState(() {
      _all = stations;
      _provinces = provinces;
      // Se arranca en Tucumán si está en el listado.
      _selectedProvince =
          provinces.contains(_defaultProvince) ? _defaultProvince : null;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchCtrl.text;
    final list = _all
        .where((s) =>
            (_selectedProvince == null || s.province == _selectedProvince) &&
            s.matches(query))
        .toList();
    if (_sortedByDistance) _sortByDistance(list);
    setState(() => _filtered = list);
  }

  void _sortByDistance(List<FuelStation> list) {
    list.sort((a, b) {
      final da = _distances[a.cacheKey];
      final db = _distances[b.cacheKey];
      if (da == null && db == null) return 0;
      if (da == null) return 1; // sin ubicar: al final
      if (db == null) return -1;
      return da.compareTo(db);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Pide permiso, toma la ubicación del celular y calcula la
  /// distancia a cada estación de la lista.
  Future<void> _findNearest() async {
    final candidates = _all
        .where((s) =>
            _selectedProvince == null || s.province == _selectedProvince)
        .toList();
    if (candidates.length > _maxForDistance) {
      _snack('Elegí una provincia (por ejemplo TUCUMAN) para buscar '
          'la estación más cercana.');
      return;
    }

    setState(() {
      _locating = true;
      _locatingText = 'Obteniendo tu ubicación…';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Activá la ubicación (GPS) del celular y probá de nuevo.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Sin permiso de ubicación no se puede ordenar por cercanía. '
            'Podés darlo desde Ajustes del celular → Aplicaciones.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      _distances.clear();
      var done = 0;
      var notFound = 0;
      for (final s in candidates) {
        if (!mounted) return;
        setState(() => _locatingText =
            'Calculando distancias… $done/${candidates.length}');
        final c = await FuelStationService.instance.coordinatesOf(s);
        if (c == null) {
          notFound++;
        } else {
          _distances[s.cacheKey] =
              Geolocator.distanceBetween(pos.latitude, pos.longitude, c.lat, c.lng);
        }
        done++;
      }

      _sortedByDistance = true;
      _applyFilter();
      if (_distances.isEmpty) {
        _snack('No se pudo calcular ninguna distancia. Revisá la conexión '
            'a internet (se necesita solo la primera vez).');
      } else if (notFound > 0) {
        _snack('$notFound estación(es) no se pudieron ubicar y quedan al '
            'final. Usá "Cómo llegar" para verlas en Google Maps.');
      }
    } catch (e) {
      _snack('No se pudo obtener la ubicación. Probá de nuevo al aire libre '
          'o con el GPS activado.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Abre Google Maps buscando "estación de servicio" alrededor de
  /// donde está el celular (cualquier estación, no solo Ticket Car).
  Future<void> _openNearbyInMaps() async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent('estación de servicio')}');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) _snack('No se pudo abrir Google Maps.');
  }

  /// Pasa a Excel (.csv) el listado que se está viendo.
  Future<void> _exportExcel() async {
    try {
      await ExcelExportService.exportFuelStations(
        stations: _filtered,
        title: _selectedProvince ?? 'Todas',
      );
    } catch (_) {
      _snack('No se pudo generar el archivo.');
    }
  }

  /// Abre Google Maps con la ruta desde la ubicación actual del
  /// celular hasta la estación.
  Future<void> _openInMaps(FuelStation s) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${Uri.encodeComponent(s.mapsAddress)}'
        '&travelmode=driving');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) _snack('No se pudo abrir Google Maps.');
  }

  String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final nearest = (_sortedByDistance &&
            _filtered.isNotEmpty &&
            _distances.containsKey(_filtered.first.cacheKey))
        ? _filtered.first
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones Ticket Car'),
        actions: [
          IconButton(
            tooltip: 'Exportar a Excel',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: _filtered.isEmpty ? null : _exportExcel,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre, localidad o calle',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchCtrl.clear(),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Provincia (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Todas las provincias')),
                      ..._provinces.map(
                          (p) => DropdownMenuItem(value: p, child: Text(p))),
                    ],
                    onChanged: (value) {
                      // Al cambiar de provincia las distancias dejan de
                      // valer: se vuelve a tocar "Cerca de mí".
                      _selectedProvince = value;
                      _sortedByDistance = false;
                      _distances.clear();
                      _applyFilter();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _locating ? null : _findNearest,
                      icon: _locating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(_locating
                          ? _locatingText
                          : 'Cerca de mí (ordenar por distancia)'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openNearbyInMaps,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text(
                          'Ver estaciones cercanas en Google Maps'),
                    ),
                  ),
                ),
                if (nearest != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openInMaps(nearest),
                        icon: const Icon(Icons.directions),
                        label: Text(
                          'Ir a la más cercana: ${nearest.name} '
                          '(${_formatDistance(_distances[nearest.cacheKey]!)})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length} estaciones encontradas',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No se encontró ninguna estación con esa búsqueda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final s = _filtered[index];
                            final d = _distances[s.cacheKey];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                onTap: () => _openInMaps(s),
                                leading: const CircleAvatar(
                                  child:
                                      Icon(Icons.local_gas_station_outlined),
                                ),
                                title: Text(s.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${s.address} · ${s.locality}\n'
                                    '${d != null ? 'A ${_formatDistance(d)} · ' : ''}'
                                    '${s.province}'),
                                isThreeLine: true,
                                trailing: IconButton(
                                  tooltip: 'Cómo llegar (Google Maps)',
                                  icon: const Icon(Icons.directions),
                                  onPressed: () => _openInMaps(s),
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
