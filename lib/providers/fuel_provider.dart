import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/fuel_log.dart';
import '../models/vehicle.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

/// Maneja las cargas de combustible de UN vehículo a la vez (se usa
/// desde la pantalla de combustible de ese vehículo). El mes que se
/// está mirando se controla con [selectedMonthKey]; por defecto es
/// el mes en curso ("planilla mensual" que arranca vacía cada mes),
/// pero se puede cambiar para consultar el historial de meses
/// anteriores sin que eso borre ni afecte esos datos.
class FuelProvider extends ChangeNotifier {
  final List<FuelLog> _logs = [];
  List<String> _availableMonths = [];
  String _selectedMonthKey = _currentMonthKey();
  bool isLoading = false;

  List<FuelLog> get logs => List.unmodifiable(_logs);
  List<String> get availableMonths => List.unmodifiable(_availableMonths);
  String get selectedMonthKey => _selectedMonthKey;

  double get totalLiters => _logs.fold(0.0, (sum, l) => sum + l.liters);

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> load(String vehicleId, {String? monthKey}) async {
    isLoading = true;
    notifyListeners();

    _selectedMonthKey = monthKey ?? _selectedMonthKey;
    final months = await DatabaseHelper.instance.getFuelLogMonths(vehicleId);
    // El mes en curso siempre aparece como opción, aunque todavía no
    // tenga cargas: así la planilla del mes "arranca" visible y vacía.
    final currentKey = _currentMonthKey();
    if (!months.contains(currentKey)) {
      months.insert(0, currentKey);
    }
    _availableMonths = months;

    final data = await DatabaseHelper.instance
        .getFuelLogsForMonth(vehicleId, _selectedMonthKey);
    _logs
      ..clear()
      ..addAll(data);

    isLoading = false;
    notifyListeners();
  }

  Future<void> changeMonth(String vehicleId, String monthKey) =>
      load(vehicleId, monthKey: monthKey);

  Future<void> addFuelLog({
    required String vehicleId,
    required DateTime date,
    required double liters,
    required int mileage,
    String? driverName,
    String? notes,
    String? ticketPhotoPath,
  }) async {
    final log = FuelLog(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      date: date,
      liters: liters,
      mileage: mileage,
      driverName: driverName,
      notes: notes,
      ticketPhotoPath: ticketPhotoPath,
    );
    await DatabaseHelper.instance.insertFuelLog(log);
    unawaited(SyncService.instance.pushFuelLog(log));
    await load(vehicleId, monthKey: log.monthKey);

    await _checkFuelLimit(vehicleId, justAddedLiters: liters);
  }

  /// Porcentaje del límite mensual a partir del cual avisa que se
  /// está "acercando" (antes de llegar/superarlo del todo).
  static const double _approachingRatio = 0.9;

  /// Si el admin le puso un límite mensual de litros a este vehículo
  /// (Vehicle.monthlyFuelLimitLiters), avisa en dos momentos
  /// distintos, cada uno una sola vez (no se repite en cargas
  /// posteriores aunque el total se mantenga arriba del umbral):
  ///   1. Al llegar al 90% del límite → "se está acercando"
  ///   2. Al llegar/superar el 100% → "se alcanzó el límite"
  /// Si una sola carga salta los dos umbrales de una, avisa los dos.
  Future<void> _checkFuelLimit(String vehicleId,
      {required double justAddedLiters}) async {
    final vehicle = await DatabaseHelper.instance.getVehicleById(vehicleId);
    final limit = vehicle?.monthlyFuelLimitLiters;
    if (vehicle == null || limit == null || limit <= 0) return;

    final totalBefore = totalLiters - justAddedLiters;
    final approachingAt = limit * _approachingRatio;

    if (totalBefore < approachingAt && totalLiters >= approachingAt) {
      await NotificationService.instance
          .notifyFuelLimitApproaching(vehicle, totalLiters, limit);
    }
    if (totalBefore < limit && totalLiters >= limit) {
      await NotificationService.instance
          .notifyFuelLimitReached(vehicle, totalLiters);
    }
  }

  Future<void> deleteFuelLog(String vehicleId, String id) async {
    await DatabaseHelper.instance.deleteFuelLog(id);
    unawaited(SyncService.instance.deleteFuelLogRemote(id));
    await load(vehicleId);
  }
}
