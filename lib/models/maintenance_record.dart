/// Tipo de evento cargado en el historial de un vehículo.
enum MaintenanceEventType { repair, breakdown, service, other }

extension MaintenanceEventTypeX on MaintenanceEventType {
  String get value {
    switch (this) {
      case MaintenanceEventType.repair:
        return 'repair';
      case MaintenanceEventType.breakdown:
        return 'breakdown';
      case MaintenanceEventType.service:
        return 'service';
      case MaintenanceEventType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case MaintenanceEventType.repair:
        return 'Arreglo';
      case MaintenanceEventType.breakdown:
        return 'Avería';
      case MaintenanceEventType.service:
        return 'Service';
      case MaintenanceEventType.other:
        return 'Otro';
    }
  }

  static MaintenanceEventType fromValue(String value) {
    switch (value) {
      case 'repair':
        return MaintenanceEventType.repair;
      case 'breakdown':
        return MaintenanceEventType.breakdown;
      case 'service':
        return MaintenanceEventType.service;
      default:
        return MaintenanceEventType.other;
    }
  }
}

/// Registro individual del historial de un vehículo: un arreglo, una
/// avería, un service o cualquier otro dato relevante, con fecha,
/// descripción, kilometraje al momento del evento y costo opcional.
/// Solo el usuario god puede cargar/editar/eliminar estos registros;
/// cualquier usuario logueado puede verlos.
class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final DateTime date;
  final MaintenanceEventType type;
  final String description;
  final int? mileageAtEvent;
  final double? cost;

  MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.type,
    required this.description,
    this.mileageAtEvent,
    this.cost,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'type': type.value,
      'description': description,
      'mileage_at_event': mileageAtEvent,
      'cost': cost,
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      type: MaintenanceEventTypeX.fromValue(map['type'] as String),
      description: map['description'] as String,
      mileageAtEvent: map['mileage_at_event'] as int?,
      cost: (map['cost'] as num?)?.toDouble(),
    );
  }
}
