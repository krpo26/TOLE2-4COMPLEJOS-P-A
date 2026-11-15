import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/tramite.dart';
import '../models/vehicle.dart';
import '../services/audit_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// Trámites del complejo en el que se está trabajando.
class TramiteProvider extends ChangeNotifier {
  List<Tramite> tramites = [];
  Map<String, Vehicle> vehiclesById = {};
  String? _complexId;
  String? get complexId => _complexId;

  Future<void> setComplex(String? id) async {
    _complexId = id;
    await load();
  }

  Future<void> load() async {
    final db = DatabaseHelper.instance;
    if (_complexId == null) {
      tramites = await db.getAllTramites();
      vehiclesById = {
        for (final v in await db.getVehicles(includeArchived: true)) v.id: v
      };
    } else {
      tramites = await db.getTramitesForComplex(_complexId!);
      vehiclesById = {
        for (final v
            in await db.getVehicles(includeArchived: true, complexId: _complexId))
          v.id: v
      };
    }
    notifyListeners();
  }

  /// Trámites que siguen en curso (iniciados o en trámite).
  int get openCount => tramites.where((t) => t.status.isOpen).length;

  String vehicleLabel(String vehicleId) {
    final v = vehiclesById[vehicleId];
    return v == null ? 'Móvil eliminado' : '${v.internalNumber} · ${v.plate}';
  }

  Future<void> add({
    required String vehicleId,
    required TramiteType type,
    required DateTime startDate,
    required TramiteStatus status,
    required String fileNumber,
    String detail = '',
  }) async {
    final t = Tramite(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      type: type,
      startDate: startDate,
      status: status,
      fileNumber: fileNumber,
      detail: detail,
    );
    await DatabaseHelper.instance.upsertTramite(t);
    await load();
    unawaited(SyncService.instance.pushTramite(t));
    unawaited(AuditService.log(
      action: 'cargó',
      entityType: 'Trámite',
      entityLabel: '${type.label} · Exp. $fileNumber · ${vehicleLabel(vehicleId)}',
    ));
  }

  Future<void> update(Tramite t) async {
    await DatabaseHelper.instance.upsertTramite(t);
    await load();
    unawaited(SyncService.instance.pushTramite(t));
    unawaited(AuditService.log(
      action: 'modificó',
      entityType: 'Trámite',
      entityLabel: '${t.type.label} · Exp. ${t.fileNumber} · ${vehicleLabel(t.vehicleId)}',
    ));
  }

  Future<void> delete(Tramite t) async {
    final label =
        '${t.type.label} · Exp. ${t.fileNumber} · ${vehicleLabel(t.vehicleId)}';
    await DatabaseHelper.instance.deleteTramite(t.id);
    await DatabaseHelper.instance.insertTombstone('procedure', t.id);
    await load();
    unawaited(SyncService.instance.deleteTramiteRemote(t.id));
    unawaited(SyncService.instance.pushTombstone('procedure', t.id));
    unawaited(AuditService.log(
      action: 'eliminó',
      entityType: 'Trámite',
      entityLabel: label,
    ));
  }
}
