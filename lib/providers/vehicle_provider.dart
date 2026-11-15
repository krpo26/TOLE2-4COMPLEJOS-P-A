import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/complex.dart';
import '../models/vehicle.dart';
import '../services/audit_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class VehicleProvider extends ChangeNotifier {
  final List<Vehicle> _vehicles = [];
  bool isLoading = false;

  /// Complejo activo. null = todos (se usa solo al arrancar, para
  /// que las alertas de notificación cubran los 4 complejos).
  String? _complexId;
  String? get complexId => _complexId;

  Future<void> setComplex(String? id) async {
    _complexId = id;
    await load();
  }

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);

  List<Vehicle> get criticalVehicles => _vehicles
      .where((v) => v.maintenanceStatus != MaintenanceStatus.ok)
      .toList();

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final data = await DatabaseHelper.instance.getVehicles(complexId: _complexId);
    _vehicles
      ..clear()
      ..addAll(data);
    isLoading = false;
    notifyListeners();
  }

  /// Vehículos archivados (dados de baja). No se guardan en el estado
  /// del provider — se consultan al vuelo desde la pantalla
  /// "Archivados", igual que hace la administración de usuarios.
  Future<List<Vehicle>> getArchived() =>
      DatabaseHelper.instance.getArchivedVehicles(complexId: _complexId);

  Future<void> addVehicle({
    required String plate,
    required String internalNumber,
    String brand = '',
    String model = '',
    String vehicleType = '',
    required int currentMileage,
    required int nextServiceMileage,
    DateTime? lastServiceDate,
    String notes = '',
    String? photoPath,
    String? cedulaVerdePath,
    String? tituloPath,
    String? vtvPath,
    String? seguroPath,
    String? iconKey,
    double? monthlyFuelLimitLiters,
  }) async {
    final vehicle = Vehicle(
      id: const Uuid().v4(),
      plate: plate,
      internalNumber: internalNumber,
      brand: brand,
      model: model,
      vehicleType: vehicleType,
      currentMileage: currentMileage,
      nextServiceMileage: nextServiceMileage,
      lastServiceDate: lastServiceDate,
      notes: notes,
      photoPath: photoPath,
      cedulaVerdePath: cedulaVerdePath,
      tituloPath: tituloPath,
      vtvPath: vtvPath,
      seguroPath: seguroPath,
      iconKey: iconKey,
      monthlyFuelLimitLiters: monthlyFuelLimitLiters,
      complexId: _complexId ?? kDefaultComplexId,
    );
    await DatabaseHelper.instance.insertVehicle(vehicle);
    await load();
    await NotificationService.instance.notifyVehicleMaintenance(vehicle);
    unawaited(SyncService.instance.pushVehicle(vehicle));
    unawaited(AuditService.log(
      action: 'creó',
      entityType: 'Vehículo',
      entityLabel: '${vehicle.internalNumber} · ${vehicle.plate}',
    ));
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await DatabaseHelper.instance.updateVehicle(vehicle);
    await load();
    await NotificationService.instance.notifyVehicleMaintenance(vehicle);
    unawaited(SyncService.instance.pushVehicle(vehicle));
    unawaited(AuditService.log(
      action: 'editó',
      entityType: 'Vehículo',
      entityLabel: '${vehicle.internalNumber} · ${vehicle.plate}',
    ));
  }

  /// "Archivar" en vez de borrar: el vehículo deja de aparecer en la
  /// lista normal pero no se pierde nada — se puede reactivar en
  /// cualquier momento desde "Archivados".
  Future<void> archive(Vehicle vehicle) async {
    final updated = vehicle.copyWith(isArchived: true);
    await DatabaseHelper.instance.updateVehicle(updated);
    await load();
    unawaited(SyncService.instance.pushVehicle(updated));
    unawaited(AuditService.log(
      action: 'archivó',
      entityType: 'Vehículo',
      entityLabel: '${vehicle.internalNumber} · ${vehicle.plate}',
    ));
  }

  Future<void> unarchive(Vehicle vehicle) async {
    final updated = vehicle.copyWith(isArchived: false);
    await DatabaseHelper.instance.updateVehicle(updated);
    await load();
    unawaited(SyncService.instance.pushVehicle(updated));
    unawaited(AuditService.log(
      action: 'reactivó',
      entityType: 'Vehículo',
      entityLabel: '${vehicle.internalNumber} · ${vehicle.plate}',
    ));
  }

  /// Borrado DEFINITIVO. Solo se ofrece desde la pantalla
  /// "Archivados" (es decir, sobre algo que ya estaba archivado), como
  /// última instancia para limpiar registros que ya no hacen falta.
  Future<void> deleteVehicle(Vehicle vehicle) async {
    await DatabaseHelper.instance.deleteVehicle(vehicle.id);
    await DatabaseHelper.instance.insertTombstone('vehicle', vehicle.id);
    await load();
    unawaited(SyncService.instance.deleteVehicleRemote(vehicle.id));
    unawaited(SyncService.instance.pushTombstone('vehicle', vehicle.id));
    unawaited(AuditService.log(
      action: 'eliminó definitivamente',
      entityType: 'Vehículo',
      entityLabel: '${vehicle.internalNumber} · ${vehicle.plate}',
    ));
  }

  /// Pasa el vehículo a otro complejo (con todo su historial, que lo
  /// acompaña). Deja de verse en el complejo actual.
  Future<void> moveToComplex(Vehicle vehicle, String newComplexId) async {
    final updated = vehicle.copyWith(complexId: newComplexId);
    await DatabaseHelper.instance.updateVehicle(updated);
    await load();
    unawaited(SyncService.instance.pushVehicle(updated));
    unawaited(AuditService.log(
      action: 'movió a ${complexById(newComplexId).shortName}',
      entityType: 'Vehículo',
      entityLabel: '${vehicle.internalNumber} · ${vehicle.plate}',
    ));
  }
}
