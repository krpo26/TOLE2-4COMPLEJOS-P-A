/// Un registro de auditoría: quién hizo qué cambio y cuándo. Se usa
/// para poder rastrear altas, ediciones, archivados y eliminaciones
/// definitivas de vehículos, choferes y usuarios.
class AuditLog {
  final String id;
  final DateTime timestamp;
  final String username;
  final String action; // 'creó', 'editó', 'archivó', 'reactivó', 'eliminó definitivamente'
  final String entityType; // 'Vehículo', 'Chofer', 'Usuario'
  final String entityLabel; // ej: "AB123CD" o "Pérez, Juan"

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.username,
    required this.action,
    required this.entityType,
    required this.entityLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'action': action,
      'entity_type': entityType,
      'entity_label': entityLabel,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      username: map['username'] as String,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      entityLabel: map['entity_label'] as String,
    );
  }
}

/// Tipo de registro que se usa para anotar los ingresos (inicios de
/// sesión) de los usuarios. Lo lee la pantalla "Últimos ingresos".
const String kAccessEntityType = 'Acceso';
