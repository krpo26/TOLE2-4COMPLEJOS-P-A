/// Un renglón de la "ficha técnica" de un vehículo: un service,
/// reparación o repuesto cargado en una fecha puntual. Hay muchos
/// por vehículo (uno por cada visita al taller/gomería/etc.), a
/// diferencia del resto de los datos del vehículo que son fijos.
///
/// Columnas, igual que en la planilla de Excel que se usaba antes:
/// FECHA · CHOFER · KILOMETRO · REPUESTOS · COMERCIO.
class TechSheetEntry {
  final String id;
  final String vehicleId;
  final DateTime date; // FECHA
  final String? driverName; // CHOFER
  final int? mileage; // KILOMETRO
  final String? parts; // REPUESTOS (ej: "SERVICE COMPLETO", "cambio de batería")
  final String? shop; // COMERCIO (ej: "RUIZ AUTOMOTORES")

  TechSheetEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    this.driverName,
    this.mileage,
    this.parts,
    this.shop,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'driver_name': driverName,
      'mileage': mileage,
      'parts': parts,
      'shop': shop,
    };
  }

  factory TechSheetEntry.fromMap(Map<String, dynamic> map) {
    return TechSheetEntry(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      driverName: map['driver_name'] as String?,
      mileage: map['mileage'] as int?,
      parts: map['parts'] as String?,
      shop: map['shop'] as String?,
    );
  }
}
