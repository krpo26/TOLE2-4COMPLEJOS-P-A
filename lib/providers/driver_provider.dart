import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/complex.dart';
import '../models/driver.dart';
import '../services/audit_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class DriverProvider extends ChangeNotifier {
  final List<Driver> _drivers = [];
  bool isLoading = false;

  /// Complejo activo. null = todos (solo al arrancar).
  String? _complexId;
  String? get complexId => _complexId;

  Future<void> setComplex(String? id) async {
    _complexId = id;
    await load();
  }

  List<Driver> get drivers => List.unmodifiable(_drivers);

  List<Driver> get criticalDrivers => _drivers
      .where((d) => d.licenseStatus != LicenseStatus.ok)
      .toList();

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final data = await DatabaseHelper.instance.getDrivers(complexId: _complexId);
    _drivers
      ..clear()
      ..addAll(data);
    isLoading = false;
    notifyListeners();
  }

  /// Choferes archivados (dados de baja). No se guardan en el estado
  /// del provider — se consultan al vuelo desde la pantalla
  /// "Archivados".
  Future<List<Driver>> getArchived() =>
      DatabaseHelper.instance.getArchivedDrivers(complexId: _complexId);

  Future<void> addDriver({
    required String fullName,
    required String documentId,
    required String phone,
    required String licenseCategory,
    required DateTime licenseExpiration,
    String? photoPath,
    String? licensePhotoPath,
    String? address,
    String? cargoNumber,
    String? iconKey,
  }) async {
    final driver = Driver(
      id: const Uuid().v4(),
      fullName: fullName,
      documentId: documentId,
      phone: phone,
      licenseCategory: licenseCategory,
      licenseExpiration: licenseExpiration,
      photoPath: photoPath,
      licensePhotoPath: licensePhotoPath,
      address: address,
      cargoNumber: cargoNumber,
      iconKey: iconKey,
      complexId: _complexId ?? kDefaultComplexId,
    );
    await DatabaseHelper.instance.insertDriver(driver);
    await load();
    await NotificationService.instance.notifyDriverLicense(driver);
    unawaited(SyncService.instance.pushDriver(driver));
    unawaited(AuditService.log(
      action: 'creó',
      entityType: 'Chofer',
      entityLabel: driver.fullName,
    ));
  }

  Future<void> updateDriver(Driver driver) async {
    await DatabaseHelper.instance.updateDriver(driver);
    await load();
    await NotificationService.instance.notifyDriverLicense(driver);
    unawaited(SyncService.instance.pushDriver(driver));
    unawaited(AuditService.log(
      action: 'editó',
      entityType: 'Chofer',
      entityLabel: driver.fullName,
    ));
  }

  /// "Archivar" en vez de borrar: el chofer deja de aparecer en la
  /// lista normal pero no se pierde nada — se puede reactivar en
  /// cualquier momento desde "Archivados".
  Future<void> archive(Driver driver) async {
    final updated = driver.copyWith(isArchived: true);
    await DatabaseHelper.instance.updateDriver(updated);
    await load();
    unawaited(SyncService.instance.pushDriver(updated));
    unawaited(AuditService.log(
      action: 'archivó',
      entityType: 'Chofer',
      entityLabel: driver.fullName,
    ));
  }

  Future<void> unarchive(Driver driver) async {
    final updated = driver.copyWith(isArchived: false);
    await DatabaseHelper.instance.updateDriver(updated);
    await load();
    unawaited(SyncService.instance.pushDriver(updated));
    unawaited(AuditService.log(
      action: 'reactivó',
      entityType: 'Chofer',
      entityLabel: driver.fullName,
    ));
  }

  /// Borrado DEFINITIVO. Solo se ofrece desde "Archivados", sobre un
  /// chofer que ya estaba archivado.
  Future<void> deleteDriver(Driver driver) async {
    await DatabaseHelper.instance.deleteDriver(driver.id);
    await DatabaseHelper.instance.insertTombstone('driver', driver.id);
    await load();
    unawaited(SyncService.instance.deleteDriverRemote(driver.id));
    unawaited(SyncService.instance.pushTombstone('driver', driver.id));
    unawaited(AuditService.log(
      action: 'eliminó definitivamente',
      entityType: 'Chofer',
      entityLabel: driver.fullName,
    ));
  }

  /// Pasa el chofer a otro complejo. Deja de verse en el actual.
  Future<void> moveToComplex(Driver driver, String newComplexId) async {
    final updated = driver.copyWith(complexId: newComplexId);
    await DatabaseHelper.instance.updateDriver(updated);
    await load();
    unawaited(SyncService.instance.pushDriver(updated));
    unawaited(AuditService.log(
      action: 'movió a ${complexById(newComplexId).shortName}',
      entityType: 'Chofer',
      entityLabel: driver.fullName,
    ));
  }
}
