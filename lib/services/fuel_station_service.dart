import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fuel_station.dart';

/// Carga (una sola vez, y queda en memoria) el listado de estaciones
/// de servicio adheridas a Ticket Car, empaquetado con la app en
/// assets/data/estaciones_ticket_car.json. No depende de internet ni
/// de la nube — funciona 100% offline, como el resto de la app.
class FuelStationService {
  FuelStationService._internal();
  static final FuelStationService instance = FuelStationService._internal();

  List<FuelStation>? _stations;

  Future<List<FuelStation>> loadAll() async {
    if (_stations != null) return _stations!;
    final raw = await rootBundle
        .loadString('assets/data/estaciones_ticket_car.json');
    final list = jsonDecode(raw) as List;
    _stations = list
        .map((e) => FuelStation.fromMap(e as Map<String, dynamic>))
        .toList();
    return _stations!;
  }

  Future<List<String>> loadProvinces() async {
    final stations = await loadAll();
    final provinces = stations.map((s) => s.province).toSet().toList();
    provinces.sort();
    return provinces;
  }

  Future<List<FuelStation>> search(String query, {String? province}) async {
    final stations = await loadAll();
    return stations
        .where((s) =>
            (province == null || s.province == province) && s.matches(query))
        .toList();
  }

  /// Coordenadas (lat, lng) de la estación. Se calculan una sola vez a
  /// partir de la dirección y quedan guardadas en el celular, así las
  /// próximas veces es instantáneo y sin internet. Devuelve null si no
  /// se pudo ubicar la dirección.
  Future<({double lat, double lng})?> coordinatesOf(FuelStation s) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'fuel_geo_${s.cacheKey}';
    final cached = prefs.getString(key);
    if (cached != null) {
      if (cached == 'none') return null;
      final p = cached.split(',');
      return (lat: double.parse(p[0]), lng: double.parse(p[1]));
    }
    try {
      final results = await locationFromAddress(s.mapsAddress);
      if (results.isNotEmpty) {
        final r = results.first;
        await prefs.setString(key, '${r.latitude},${r.longitude}');
        return (lat: r.latitude, lng: r.longitude);
      }
      await prefs.setString(key, 'none');
    } catch (_) {
      // Sin internet / sin servicio de ubicación: no se guarda "none"
      // para volver a intentarlo la próxima vez.
    }
    return null;
  }
}
