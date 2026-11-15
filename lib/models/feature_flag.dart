/// Identificador y datos de cada "pestaña"/sección o "dato" puntual
/// que el admin (god) puede mostrar u ocultar para los usuarios
/// comunes. El admin SIEMPRE ve todo — estos flags nunca lo afectan.
class FeatureFlagDef {
  final String key;
  final String label;
  final String description;
  final String category;

  const FeatureFlagDef(this.key, this.label, this.description,
      {this.category = 'Pestañas completas'});
}

/// Lista fija de secciones y datos puntuales que se pueden activar o
/// desactivar. Agregar uno nuevo acá (y envolver el widget
/// correspondiente en la pantalla con el chequeo de
/// FeatureFlagsProvider.isEnabled) es todo lo que hace falta para
/// sumar un interruptor más.
const List<FeatureFlagDef> kFeatureFlagDefs = [
  FeatureFlagDef('tab_vehicles', 'Vehículos',
      'Tarjeta y listado de vehículos en el inicio.'),
  FeatureFlagDef('tab_drivers', 'Choferes',
      'Tarjeta y listado de choferes en el inicio.'),
  FeatureFlagDef('tab_tramites', 'Trámites',
      'Tarjeta de trámites (pedidos de service, compras, arreglos y otros).'),
  FeatureFlagDef('tab_stations', 'Estaciones de servicio',
      'Tarjeta de estaciones Ticket Car (más cercana en Google Maps y listado en Excel).'),
  FeatureFlagDef('export_pdf', 'Exportar reporte PDF',
      'Botón para exportar el reporte general en PDF.'),
  FeatureFlagDef('maintenance_records', 'Historial de arreglos y averías',
      'Sección dentro de cada vehículo.'),
  FeatureFlagDef('fuel_log', 'Combustible',
      'Sección de cargas de combustible dentro de cada vehículo.'),
  FeatureFlagDef('tech_sheet', 'Ficha técnica',
      'Sección de ficha técnica dentro de cada vehículo.'),
  FeatureFlagDef(
    'field_driver_phone',
    'Teléfono del chofer',
    'El campo de teléfono, dentro del detalle de cada chofer.',
    category: 'Datos dentro de una pantalla',
  ),
  FeatureFlagDef(
    'field_driver_address',
    'Dirección del chofer',
    'El campo de dirección, dentro del detalle de cada chofer.',
    category: 'Datos dentro de una pantalla',
  ),
];

class FeatureFlag {
  final String key;
  final bool enabled;
  final DateTime updatedAt;

  FeatureFlag({
    required this.key,
    required this.enabled,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'enabled': enabled ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FeatureFlag.fromMap(Map<String, dynamic> map) {
    return FeatureFlag(
      key: map['key'] as String,
      enabled: map['enabled'] == true || map['enabled'] == 1,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
