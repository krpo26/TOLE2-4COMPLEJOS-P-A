/// Una carga de combustible de un vehículo.
///
/// El campo [monthKey] ("YYYY-MM") se guarda calculado a partir de
/// [date] para poder filtrar y agrupar por mes de forma directa y
/// rápida, sin tener que parsear fechas en cada consulta. Las cargas
/// de meses anteriores NUNCA se borran automáticamente: quedan como
/// historial permanente. Lo único que "reinicia" cada mes es la
/// vista/planilla actual, que por defecto muestra el mes en curso —
/// los meses pasados se consultan eligiéndolos en el selector de mes.
class FuelLog {
  final String id;
  final String vehicleId;
  final DateTime date;
  final String monthKey; // "2026-08"
  final double liters;
  // Costo total y estación de servicio: se dejaron de pedir al cargar
  // combustible (quedan nullable solo para no perder las cargas viejas
  // que sí los tenían cargados). Ya no se muestran ni se exportan.
  final double? amount;
  final int mileage; // kilometraje al momento de la carga
  final String? driverName; // chofer que hizo la carga
  final String? stationName;
  final String? notes;
  final String? ticketPhotoPath; // foto del ticket/comprobante

  FuelLog({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.liters,
    this.amount,
    required this.mileage,
    this.driverName,
    this.stationName,
    this.notes,
    this.ticketPhotoPath,
  }) : monthKey =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'month_key': monthKey,
      'liters': liters,
      'amount': amount,
      'mileage': mileage,
      'driver_name': driverName,
      'station_name': stationName,
      'notes': notes,
      'ticket_photo_path': ticketPhotoPath,
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    return FuelLog(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      liters: (map['liters'] as num).toDouble(),
      amount: (map['amount'] as num?)?.toDouble(),
      mileage: map['mileage'] as int,
      driverName: map['driver_name'] as String?,
      stationName: map['station_name'] as String?,
      notes: map['notes'] as String?,
      ticketPhotoPath: map['ticket_photo_path'] as String?,
    );
  }
}
