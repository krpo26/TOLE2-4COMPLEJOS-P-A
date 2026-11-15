import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/vehicle_tech_sheet.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// Maneja la ficha técnica de un vehículo: la lista de renglones
/// (FECHA, CHOFER, KILOMETRO, REPUESTOS, COMERCIO) cargados para él.
class TechSheetProvider extends ChangeNotifier {
  String? _vehicleId;
  List<TechSheetEntry> entries = [];
  bool isLoading = false;

  Future<void> load(String vehicleId) async {
    _vehicleId = vehicleId;
    isLoading = true;
    notifyListeners();
    entries = await DatabaseHelper.instance.getTechSheetEntries(vehicleId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> add({
    required DateTime date,
    String? driverName,
    int? mileage,
    String? parts,
    String? shop,
  }) async {
    if (_vehicleId == null) return;
    final entry = TechSheetEntry(
      id: const Uuid().v4(),
      vehicleId: _vehicleId!,
      date: date,
      driverName: driverName,
      mileage: mileage,
      parts: parts,
      shop: shop,
    );
    await DatabaseHelper.instance.insertTechSheetEntry(entry);
    unawaited(SyncService.instance.pushTechSheetEntry(entry));
    await load(_vehicleId!);
  }

  Future<void> delete(String id) async {
    if (_vehicleId == null) return;
    await DatabaseHelper.instance.deleteTechSheetEntry(id);
    unawaited(SyncService.instance.deleteTechSheetEntryRemote(id));
    await load(_vehicleId!);
  }
}
