import 'complex.dart';

/// Estado de alerta de mantenimiento de un vehículo.
enum MaintenanceStatus { ok, warning, overdue }

/// Umbral (en km) para pasar de "ok" a "warning" antes del próximo service.
/// A cuántos km de diferencia con el próximo service se empieza a
/// avisar (tarjeta de alerta en el inicio + notificación push). Se
/// aplica igual para todos los vehículos, sin importar la marca.
const int kWarningThresholdKm = 3000;

class Vehicle {
  final String id; // uuid interno
  final String plate; // Patente / Dominio (clave única de negocio)
  final String internalNumber; // Número interno de unidad
  final String brand; // Marca (ej. Toyota, Ford)
  final String model; // Modelo (ej. Hilux, Ranger)
  final String vehicleType; // Tipo (ej. Camioneta, Auto, Moto, Camión)
  final int currentMileage; // Kilometraje actual
  final DateTime? lastServiceDate; // Fecha del último service
  final int nextServiceMileage; // Próximo service por kilometraje
  final String notes; // Observaciones / historial de mantenimiento

  // Fotos de documentación del vehículo (rutas locales en el dispositivo).
  final String? photoPath; // Foto general del vehículo
  final String? cedulaVerdePath; // Cédula verde
  final String? tituloPath; // Título del automotor
  final String? vtvPath; // VTV / RTO
  final String? seguroPath; // Seguro del móvil
  final String? iconKey; // Ícono elegido para representar al vehículo
  final bool isArchived; // true = dado de baja (no se borra, se archiva)
  // Límite de litros de combustible por mes que fija el admin (null =
  // sin límite). Al llegar/superar este número entre todas las cargas
  // del mes, sale una notificación. Ver FuelProvider.addFuelLog.
  final double? monthlyFuelLimitLiters;
  // Cuándo se guardó esta versión del registro por última vez. Se usa
  // para que, al sincronizar, la edición más reciente (venga de este
  // dispositivo o de otro) sea siempre la que gana.
  final DateTime updatedAt;
  // Complejo penitenciario al que pertenece este móvil.
  final String complexId;

  Vehicle({
    required this.id,
    required this.plate,
    required this.internalNumber,
    this.brand = '',
    this.model = '',
    this.vehicleType = '',
    required this.currentMileage,
    required this.nextServiceMileage,
    this.lastServiceDate,
    this.notes = '',
    this.photoPath,
    this.cedulaVerdePath,
    this.tituloPath,
    this.vtvPath,
    this.seguroPath,
    this.iconKey,
    this.isArchived = false,
    this.monthlyFuelLimitLiters,
    DateTime? updatedAt,
    this.complexId = kDefaultComplexId,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Diferencia entre el próximo service y el kilometraje actual.
  /// Negativo significa que el service ya está vencido/superado.
  int get kmRemaining => nextServiceMileage - currentMileage;

  MaintenanceStatus get maintenanceStatus {
    if (kmRemaining <= 0) return MaintenanceStatus.overdue;
    if (kmRemaining <= kWarningThresholdKm) return MaintenanceStatus.warning;
    return MaintenanceStatus.ok;
  }

  Vehicle copyWith({
    String? plate,
    String? internalNumber,
    String? brand,
    String? model,
    String? vehicleType,
    int? currentMileage,
    DateTime? lastServiceDate,
    int? nextServiceMileage,
    String? notes,
    String? photoPath,
    String? cedulaVerdePath,
    String? tituloPath,
    String? vtvPath,
    String? seguroPath,
    String? iconKey,
    bool? isArchived,
    double? monthlyFuelLimitLiters,
    bool clearMonthlyFuelLimitLiters = false,
    DateTime? updatedAt,
    String? complexId,
  }) {
    return Vehicle(
      id: id,
      plate: plate ?? this.plate,
      internalNumber: internalNumber ?? this.internalNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      vehicleType: vehicleType ?? this.vehicleType,
      currentMileage: currentMileage ?? this.currentMileage,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      nextServiceMileage: nextServiceMileage ?? this.nextServiceMileage,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      cedulaVerdePath: cedulaVerdePath ?? this.cedulaVerdePath,
      tituloPath: tituloPath ?? this.tituloPath,
      vtvPath: vtvPath ?? this.vtvPath,
      seguroPath: seguroPath ?? this.seguroPath,
      iconKey: iconKey ?? this.iconKey,
      isArchived: isArchived ?? this.isArchived,
      monthlyFuelLimitLiters: clearMonthlyFuelLimitLiters
          ? null
          : (monthlyFuelLimitLiters ?? this.monthlyFuelLimitLiters),
      updatedAt: updatedAt ?? DateTime.now(),
      complexId: complexId ?? this.complexId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plate': plate,
      'internal_number': internalNumber,
      'brand': brand,
      'model': model,
      'vehicle_type': vehicleType,
      'current_mileage': currentMileage,
      'last_service_date': lastServiceDate?.toIso8601String(),
      'next_service_mileage': nextServiceMileage,
      'notes': notes,
      'photo_path': photoPath,
      'cedula_verde_path': cedulaVerdePath,
      'titulo_path': tituloPath,
      'vtv_path': vtvPath,
      'seguro_path': seguroPath,
      'icon_key': iconKey,
      'is_archived': isArchived ? 1 : 0,
      'monthly_fuel_limit_liters': monthlyFuelLimitLiters,
      'updated_at': updatedAt.toIso8601String(),
      'complex_id': complexId,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      plate: map['plate'] as String,
      internalNumber: map['internal_number'] as String,
      brand: (map['brand'] ?? '') as String,
      model: (map['model'] ?? '') as String,
      vehicleType: (map['vehicle_type'] ?? '') as String,
      currentMileage: map['current_mileage'] as int,
      lastServiceDate: map['last_service_date'] != null
          ? DateTime.parse(map['last_service_date'] as String)
          : null,
      nextServiceMileage: map['next_service_mileage'] as int,
      notes: (map['notes'] ?? '') as String,
      photoPath: map['photo_path'] as String?,
      cedulaVerdePath: map['cedula_verde_path'] as String?,
      tituloPath: map['titulo_path'] as String?,
      vtvPath: map['vtv_path'] as String?,
      seguroPath: map['seguro_path'] as String?,
      iconKey: map['icon_key'] as String?,
      isArchived: map['is_archived'] == true || map['is_archived'] == 1,
      monthlyFuelLimitLiters:
          (map['monthly_fuel_limit_liters'] as num?)?.toDouble(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      complexId: (map['complex_id'] ?? kDefaultComplexId) as String,
    );
  }
}
