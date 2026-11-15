/// Una estación de servicio adherida a Ticket Car (Edenred), tal
/// como figura en el listado oficial. Son datos de referencia fijos
/// (no se editan desde la app ni se sincronizan con la nube) — se
/// cargan una sola vez desde el archivo que viaja empaquetado con la
/// app: assets/data/estaciones_ticket_car.json.
class FuelStation {
  final String province;
  final String name; // Nombre de fantasía (ej: "SHELL 1066 CORDOBA")
  final String owner; // Razón social
  final String cuit;
  final String address; // Calle y número
  final String locality;

  FuelStation({
    required this.province,
    required this.name,
    required this.owner,
    required this.cuit,
    required this.address,
    required this.locality,
  });

  /// Todo el texto de la estación en minúscula y sin acentos, para
  /// buscar de forma rápida y tolerante a tildes/mayúsculas.
  late final String _searchText = _normalize(
      '$name $owner $address $locality $province');

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final terms = _normalize(query).split(RegExp(r'\s+'));
    return terms.every((t) => _searchText.contains(t));
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');

  /// Ciudad "legible" para buscar en Google Maps (el listado trae
  /// abreviaturas como "S.MIGUEL DE TUCUMAN").
  String get _cityForMaps {
    final l = locality.toUpperCase();
    if (l == 'S.MIGUEL DE TUCUMAN' || l == 'SAN MIGUEL') {
      return 'San Miguel de Tucumán';
    }
    return locality;
  }

  /// Dirección completa para geolocalizar / abrir en Google Maps.
  /// Si el número es 0 (rutas, accesos) se omite.
  String get mapsAddress {
    final street = address.replaceFirst(RegExp(r'\s0$'), '');
    return '$street, $_cityForMaps, $province, Argentina';
  }

  /// Clave para guardar en el celular las coordenadas ya calculadas.
  String get cacheKey => '$name|$address|$locality';

  factory FuelStation.fromMap(Map<String, dynamic> map) {
    return FuelStation(
      province: map['province'] as String,
      name: map['name'] as String,
      owner: map['owner'] as String,
      cuit: map['cuit'] as String,
      address: map['address'] as String,
      locality: map['locality'] as String,
    );
  }
}
