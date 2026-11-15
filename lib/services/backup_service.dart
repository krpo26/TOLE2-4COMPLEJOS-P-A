import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver.dart';
import '../models/fuel_log.dart';
import '../models/maintenance_record.dart';
import '../models/user_account.dart';
import '../models/vehicle.dart';
import '../models/vehicle_tech_sheet.dart';
import 'database_helper.dart';
import 'sync_service.dart';

const kLastBackupAtKey = 'last_backup_at';

/// Genera y restaura respaldos completos de la base de datos local en
/// formato JSON.
///
/// Hay dos formas de disparar un respaldo:
/// - MANUAL: botón "Exportar ahora" en la pantalla de administración,
///   que genera el archivo y abre el selector para compartirlo
///   (WhatsApp, mail, Drive, guardar en el celular, etc.)
/// - AUTOMÁTICO: cada 3 horas (ver [BackgroundService]), en silencio,
///   sin abrir ningún selector. Si hay nube conectada, además sube el
///   archivo a Firebase Storage; si no hay nube, igual queda un
///   archivo de respaldo guardado en el almacenamiento del propio
///   celular.
///
/// IMPORTANTE: el respaldo incluye los DATOS (vehículos, choferes,
/// combustible, etc.) pero NO las fotos en sí — guarda las RUTAS
/// locales de los archivos de foto, que solo tienen sentido en el
/// celular donde se tomaron. Para que las fotos también viajen entre
/// dispositivos hace falta que Firebase Storage esté conectado (ver
/// [CloudStorageService]).
class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  Future<Map<String, dynamic>> _buildBackupMap() async {
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles(includeArchived: true);

    final fuelLogs = <Map<String, dynamic>>[];
    final techSheets = <Map<String, dynamic>>[];
    final maintenanceRecords = <Map<String, dynamic>>[];
    for (final v in vehicles) {
      for (final month in await db.getFuelLogMonths(v.id)) {
        for (final f in await db.getFuelLogsForMonth(v.id, month)) {
          fuelLogs.add(f.toMap());
        }
      }
      for (final t in await db.getTechSheetEntries(v.id)) {
        techSheets.add(t.toMap());
      }
      for (final r in await db.getMaintenanceRecords(v.id)) {
        maintenanceRecords.add(r.toMap());
      }
    }

    return {
      'generated_at': DateTime.now().toIso8601String(),
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'drivers': (await db.getDrivers(includeArchived: true))
          .map((d) => d.toMap())
          .toList(),
      // Solo usuarios comunes: el usuario god nunca sale del
      // dispositivo, ni siquiera en un respaldo.
      'common_users':
          (await db.getCommonUsers()).map((u) => u.toMap()).toList(),
      'maintenance_records': maintenanceRecords,
      'fuel_logs': fuelLogs,
      'vehicle_tech_sheets': techSheets,
    };
  }

  Future<File> _writeToTempFile(Map<String, dynamic> data) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/respaldo_flota_$stamp.json');
    await file.writeAsBytes(utf8.encode(jsonEncode(data)), flush: true);
    return file;
  }

  /// Genera el respaldo y abre el selector para compartirlo/guardarlo.
  Future<void> exportAndShare() async {
    final data = await _buildBackupMap();
    final file = await _writeToTempFile(data);
    await _markBackedUpNow();
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Respaldo Parque Automotor — ${DateTime.now()}',
    );
  }

  /// Respaldo silencioso: se llama desde la tarea en segundo plano
  /// cada 3 horas. No abre ningún selector. Guarda una copia local y,
  /// si hay nube conectada, también la sube a Firebase Storage.
  Future<void> runAutoBackup() async {
    try {
      final data = await _buildBackupMap();
      final jsonStr = jsonEncode(data);

      final docsDir = await getApplicationDocumentsDirectory();
      final localFile = File('${docsDir.path}/auto_backup_latest.json');
      await localFile.writeAsBytes(utf8.encode(jsonStr), flush: true);

      if (SyncService.instance.isCloudEnabled) {
        try {
          final storage = FirebaseStorage.instance;
          await storage
              .ref('backups/auto_backup_latest.json')
              .putString(jsonStr, format: PutStringFormat.raw);
          final stamp =
              DateTime.now().toIso8601String().replaceAll(':', '-');
          await storage
              .ref('backups/auto_backup_$stamp.json')
              .putString(jsonStr, format: PutStringFormat.raw);
        } catch (_) {
          // Sin conexión en el momento del respaldo automático: la
          // copia local ya quedó guardada, se reintenta la próxima vez.
        }
      }
      await _markBackedUpNow();
    } catch (_) {
      // Un respaldo fallido nunca debe interrumpir el resto de la app.
    }
  }

  Future<void> _markBackedUpNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLastBackupAtKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(kLastBackupAtKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Respaldo automático "inteligente": solo corre si pasaron al
  /// menos [minInterval] desde el último respaldo (por defecto, 3
  /// horas). Se llama desde la tarea en segundo plano cada 15
  /// minutos (mínimo técnico de Android para tareas periódicas), pero
  /// el respaldo en sí solo se ejecuta de verdad cada 3 horas.
  Future<void> runAutoBackupIfDue({
    Duration minInterval = const Duration(hours: 3),
  }) async {
    final last = await getLastBackupAt();
    if (last != null && DateTime.now().difference(last) < minInterval) {
      return;
    }
    await runAutoBackup();
  }

  /// Restaura un respaldo JSON como el que genera [exportAndShare].
  /// No borra nada que ya esté cargado: hace upsert (inserta o
  /// reemplaza por id) de todo lo que venga en el archivo.
  Future<void> restoreFromJsonString(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final db = DatabaseHelper.instance;

    for (final raw in (data['vehicles'] as List? ?? [])) {
      await db.insertVehicle(Vehicle.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['drivers'] as List? ?? [])) {
      await db.insertDriver(Driver.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['common_users'] as List? ?? [])) {
      final user = UserAccount.fromMap(raw as Map<String, dynamic>);
      if (user.role == UserRole.common) await db.insertUser(user);
    }
    for (final raw in (data['maintenance_records'] as List? ?? [])) {
      await db.insertMaintenanceRecord(
          MaintenanceRecord.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['fuel_logs'] as List? ?? [])) {
      await db.insertFuelLog(FuelLog.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['vehicle_tech_sheets'] as List? ?? [])) {
      await db.insertTechSheetEntry(
          TechSheetEntry.fromMap(raw as Map<String, dynamic>));
    }
  }
}
