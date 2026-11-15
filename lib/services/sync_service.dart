import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/audit_log.dart';
import '../models/driver.dart';
import '../models/complex_appearance.dart';
import '../models/tramite.dart';
import 'notification_prefs_service.dart';
import '../models/feature_flag.dart';
import '../models/fuel_log.dart';
import '../models/legal_acceptance.dart';
import '../models/maintenance_record.dart';
import '../models/observation_photo.dart';
import '../models/record_photo.dart';
import '../models/user_account.dart';
import '../models/vehicle.dart';
import '../models/vehicle_tech_sheet.dart';
import 'database_helper.dart';

/// Sincroniza vehículos, choferes, historial de mantenimiento y
/// usuarios comunes con Cloud Firestore cuando hay conexión a
/// internet.
///
/// DISEÑO OFFLINE-FIRST: SQLite local es siempre la fuente de verdad
/// para que la app funcione al 100% sin internet. La nube es un
/// respaldo y un medio para compartir datos entre dispositivos del
/// mismo parque automotor — nunca un requisito para operar.
///
/// El usuario GOD NO se sincroniza a la nube por seguridad: vive
/// únicamente en el dispositivo donde se creó (SQLite +
/// almacenamiento seguro). Los usuarios COMUNES sí se sincronizan
/// (solo su hash de contraseña, nunca en texto plano), para que
/// puedan iniciar sesión y ver la información desde cualquier
/// dispositivo del equipo, no solo desde el que los creó.
///
/// Si Firebase no fue configurado (ver README), [isCloudEnabled]
/// queda en false y todos los métodos de sync no hacen nada: la app
/// sigue funcionando perfecto en modo offline únicamente.
///
/// SEGURIDAD: antes de tocar Firestore, la app se autentica contra
/// Firebase con una sesión anónima (Firebase Authentication, modo
/// "Anonymous"). Esto es lo que permite que firestore.rules exija
/// `request.auth != null` en vez de dejar las colecciones abiertas a
/// cualquiera: sin esa sesión, ni la propia app ni nadie más puede
/// leer o escribir nada en la base. No identifica a la PERSONA (todos
/// los dispositivos comparten el mismo tipo de sesión anónima, no hay
/// "usuario de Firebase" por persona), pero sí cierra el acceso a
/// quien no pase por el flujo normal de arranque de la app.
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  bool isCloudEnabled = false;
  DateTime? lastSyncedAt;
  String? lastInitError; // Diagnóstico temporal: motivo si falla la conexión.

  FirebaseFirestore? _firestore;

  Future<void> init() async {
    try {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // En Android, si google-services.json está presente, el propio
        // sistema ya inicializó la app [DEFAULT] nativamente antes de
        // que Dart llegue a este punto. Eso es normal, no un error real:
        // seguimos usando esa instancia ya inicializada.
        if (!e.toString().contains('duplicate-app')) rethrow;
      }

      // Autenticación anónima: si ya había una sesión de una apertura
      // anterior, Firebase la reutiliza sola (queda guardada en el
      // dispositivo); si no, se crea una nueva acá. Sin esto, las
      // reglas de Firestore (`request.auth != null`) rechazan
      // cualquier lectura/escritura.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      _firestore = FirebaseFirestore.instance;
      _firestore!.settings = const Settings(persistenceEnabled: true);
      isCloudEnabled = true;
      lastInitError = null;
    } catch (e) {
      // Sin Firebase configurado, sin poder autenticar, o sin poder
      // inicializar: seguimos 100% operativos en modo offline con
      // SQLite.
      isCloudEnabled = false;
      lastInitError = e.toString();
    }
  }

  // ---------------- Push individual (se llama tras cada alta/edición/baja) ----------------

  Future<void> pushVehicle(Vehicle v) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('vehicles').doc(v.id).set(v.toMap());
    } catch (_) {
      // Sin conexión: el cambio ya quedó en SQLite; se sincroniza
      // solo cuando vuelva la conexión.
    }
  }

  Future<void> deleteVehicleRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('vehicles').doc(id).delete();
      // Firestore no tiene borrado en cascada como SQLite: hay que
      // limpiar a mano las colecciones relacionadas con este
      // vehículo, para que no queden datos huérfanos ocupando lugar
      // en la nube para siempre.
      for (final collection in [
        'maintenance_records',
        'fuel_logs',
        'vehicle_tech_sheets',
        'vehicle_observation_photos',
        'tramites',
      ]) {
        final docs = await _firestore!
            .collection(collection)
            .where('vehicle_id', isEqualTo: id)
            .get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> pushDriver(Driver d) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('drivers').doc(d.id).set(d.toMap());
    } catch (_) {}
  }

  Future<void> deleteDriverRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('drivers').doc(id).delete();
    } catch (_) {}
  }

  /// Solo sube usuarios COMUNES. El usuario god nunca se sube a la
  /// nube, ni siquiera si se llama por error con uno: se ignora.
  Future<void> pushUser(UserAccount u) async {
    if (!isCloudEnabled) return;
    if (u.role != UserRole.common) return;
    try {
      await _firestore!.collection('common_users').doc(u.id).set(u.toMap());
    } catch (_) {}
  }

  Future<void> deleteUserRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('common_users').doc(id).delete();
    } catch (_) {}
  }

  /// Busca un usuario común por nombre de usuario directamente en la
  /// nube. Se usa como respaldo en el login: si un dispositivo todavía
  /// no bajó la sincronización completa (por ejemplo, es la primera
  /// vez que se abre la app en ese equipo) pero hay internet en el
  /// momento de iniciar sesión, esto permite entrar igual sin esperar
  /// a que corra una sincronización completa.
  Future<UserAccount?> findCommonUserByUsername(String username) async {
    if (!isCloudEnabled) return null;
    try {
      final query = await _firestore!
          .collection('common_users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      final user = UserAccount.fromMap(query.docs.first.data());
      return user.role == UserRole.common ? user : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> pushMaintenanceRecord(MaintenanceRecord r) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!
          .collection('maintenance_records')
          .doc(r.id)
          .set(r.toMap());
    } catch (_) {}
  }

  Future<void> deleteMaintenanceRecordRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('maintenance_records').doc(id).delete();
    } catch (_) {}
  }

  Future<void> pushObservationPhoto(ObservationPhoto p) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!
          .collection('vehicle_observation_photos')
          .doc(p.id)
          .set(p.toMap());
    } catch (_) {}
  }

  Future<void> deleteObservationPhotoRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('vehicle_observation_photos').doc(id).delete();
    } catch (_) {}
  }

  Future<void> pushRecordPhoto(RecordPhoto p) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!
          .collection('maintenance_record_photos')
          .doc(p.id)
          .set(p.toMap());
    } catch (_) {}
  }

  Future<void> deleteRecordPhotoRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('maintenance_record_photos').doc(id).delete();
    } catch (_) {}
  }
  Future<void> pushFuelLog(FuelLog f) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('fuel_logs').doc(f.id).set(f.toMap());
    } catch (_) {}
  }

  Future<void> deleteFuelLogRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('fuel_logs').doc(id).delete();
    } catch (_) {}
  }

  Future<void> pushTechSheetEntry(TechSheetEntry t) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!
          .collection('vehicle_tech_sheets')
          .doc(t.id)
          .set(t.toMap());
    } catch (_) {}
  }

  Future<void> deleteTechSheetEntryRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('vehicle_tech_sheets').doc(id).delete();
    } catch (_) {}
  }

  Future<void> pushTramite(Tramite t) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('tramites').doc(t.id).set(t.toMap());
    } catch (_) {}
  }

  Future<void> deleteTramiteRemote(String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('tramites').doc(id).delete();
    } catch (_) {}
  }

  /// Sincroniza los trámites: gana la versión más nueva y lo borrado
  /// definitivamente no vuelve.
  Future<void> _syncTramites(DatabaseHelper db, Set<String> tomb) async {
    final locals = {for (final t in await db.getAllTramites()) t.id: t};
    final snap = await _firestore!.collection('tramites').get();
    final remotes = <String, Tramite>{};
    for (final doc in snap.docs) {
      final r = Tramite.fromMap(doc.data());
      if (tomb.contains('procedure:${r.id}')) {
        await doc.reference.delete();
        continue;
      }
      remotes[r.id] = r;
    }
    for (final r in remotes.values) {
      final l = locals[r.id];
      if (l == null || r.updatedAt.isAfter(l.updatedAt)) {
        try {
          await db.upsertTramite(r);
        } catch (_) {
          // Trámite huérfano (su móvil ya fue borrado): se ignora.
        }
      }
    }
    for (final l in locals.values) {
      final r = remotes[l.id];
      if (r == null || l.updatedAt.isAfter(r.updatedAt)) {
        await _firestore!.collection('tramites').doc(l.id).set(l.toMap());
      }
    }
  }

  /// Sube el aspecto y el audio de las notificaciones.
  Future<void> pushNotificationPrefs() async {
    if (!isCloudEnabled) return;
    try {
      await NotificationPrefsService.instance.pushToCloud(_firestore!);
    } catch (_) {}
  }

  /// Sube la apariencia de un complejo (logo, tema, color, letra).
  Future<void> pushAppearance(ComplexAppearance a) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!
          .collection('complex_appearance')
          .doc(a.complexId)
          .set(a.toMap());
    } catch (_) {}
  }

  /// Sincroniza la apariencia de cada complejo: gana siempre la
  /// versión más nueva (por fecha de modificación).
  Future<void> _syncAppearances(DatabaseHelper db) async {
    final locals = {
      for (final a in await db.getComplexAppearances()) a.complexId: a
    };
    final snap = await _firestore!.collection('complex_appearance').get();
    final remotes = <String, ComplexAppearance>{};
    for (final doc in snap.docs) {
      final r = ComplexAppearance.fromMap(doc.data());
      remotes[r.complexId] = r;
    }
    for (final r in remotes.values) {
      final l = locals[r.complexId];
      if (l == null || r.updatedAt.isAfter(l.updatedAt)) {
        await db.upsertComplexAppearance(r);
      }
    }
    for (final l in locals.values) {
      final r = remotes[l.complexId];
      if (r == null || l.updatedAt.isAfter(r.updatedAt)) {
        await _firestore!
            .collection('complex_appearance')
            .doc(l.complexId)
            .set(l.toMap());
      }
    }
  }

  Future<void> pushFeatureFlag(FeatureFlag f) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('feature_flags').doc(f.key).set(f.toMap());
    } catch (_) {}
  }

  Future<void> pushLegalAcceptance(LegalAcceptance a) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!
          .collection('legal_acceptances')
          .doc(a.username)
          .set(a.toMap());
    } catch (_) {}
  }

  /// Sube una entrada de auditoría apenas se genera. No hace falta
  /// esperar al próximo syncAll() — así el registro queda disponible
  /// para el admin en otros dispositivos casi al instante.
  void pushAuditLog(AuditLog entry) {
    if (!isCloudEnabled) return;
    _firestore!
        .collection('audit_log')
        .doc(entry.id)
        .set(entry.toMap())
        .catchError((_) {});
  }

  // ---------------- Sincronización completa (manual o al reconectar) ----------------

  /// Registra en la nube que algo se borró definitivamente.
  /// [type]: 'vehicle', 'driver' o 'user'.
  Future<void> pushTombstone(String type, String id) async {
    if (!isCloudEnabled) return;
    try {
      await _firestore!.collection('deleted_records').doc('${type}_$id').set({
        'type': type,
        'id': id,
        'deleted_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Sincroniza el registro de borrados (local <-> nube) y elimina
  /// del dispositivo todo lo que ya se borró en cualquier otro.
  /// Devuelve las claves "tipo:id" de todo lo borrado.
  Future<Set<String>> _applyTombstones(DatabaseHelper db) async {
    try {
      final local = await db.getTombstones();
      final snap = await _firestore!.collection('deleted_records').get();
      final remoteIds = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final type = d['type'] as String?;
        final id = d['id'] as String?;
        if (type == null || id == null) continue;
        remoteIds.add(doc.id);
        await db.insertTombstone(type, id,
            deletedAt: d['deleted_at'] as String?);
      }
      for (final t in local) {
        final docId = '${t['type']}_${t['id']}';
        if (!remoteIds.contains(docId)) {
          await _firestore!.collection('deleted_records').doc(docId).set({
            'type': t['type'],
            'id': t['id'],
            'deleted_at': t['deleted_at'],
          });
        }
      }
    } catch (_) {
      // Sin conexión o reglas sin actualizar: se sigue con lo que
      // haya registrado localmente.
    }

    final keys = <String>{};
    for (final t in await db.getTombstones()) {
      final type = t['type'] as String;
      final id = t['id'] as String;
      keys.add('$type:$id');
      if (type == 'vehicle') {
        await db.deleteVehicle(id);
      } else if (type == 'driver') {
        await db.deleteDriver(id);
      } else if (type == 'procedure') {
        await db.deleteTramite(id);
      } else if (type == 'user') {
        final u = await db.getUserById(id);
        if (u != null && u.role == UserRole.common) {
          await db.deleteUser(id);
        }
      }
    }
    return keys;
  }

  /// Trae y sube vehículos, comparando quién tiene la edición más
  /// reciente (campo updatedAt) para cada uno. Así, si el admin editó
  /// algo desde otro dispositivo, esa versión gana sin importar que
  /// este dispositivo también tenga el registro guardado localmente
  /// desde antes.
  Future<void> _mergeVehicles(DatabaseHelper db, Set<String> tomb) async {
    final localVehicles = await db.getVehicles(includeArchived: true);
    final localById = {for (final v in localVehicles) v.id: v};

    final remoteSnap = await _firestore!.collection('vehicles').get();
    final remoteById = {
      for (final doc in remoteSnap.docs) doc.id: Vehicle.fromMap(doc.data())
    };
    // Lo borrado definitivamente nunca se vuelve a subir ni a bajar:
    // si todavía queda en la nube (porque lo subió un dispositivo
    // desactualizado), se limpia de nuevo.
    for (final id in remoteById.keys.toList()) {
      if (tomb.contains('vehicle:$id')) {
        await deleteVehicleRemote(id);
        remoteById.remove(id);
      }
    }

    for (final id in {...localById.keys, ...remoteById.keys}) {
      final local = localById[id];
      final remote = remoteById[id];
      if (local == null && remote != null) {
        await db.insertVehicle(remote);
      } else if (remote == null && local != null) {
        await _firestore!.collection('vehicles').doc(id).set(local.toMap());
      } else if (local != null && remote != null) {
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          await db.insertVehicle(remote);
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          await _firestore!.collection('vehicles').doc(id).set(local.toMap());
        }
      }
    }
  }

  /// Igual que [_mergeVehicles] pero para choferes — resuelve el caso
  /// puntual de "el admin cambió la fecha de vencimiento del carnet y
  /// a otros usuarios no les llega": ahora, sea cual sea el orden en
  /// que sincronicen los dispositivos, siempre queda la edición con
  /// la fecha más nueva, nunca la más vieja.
  Future<void> _mergeDrivers(DatabaseHelper db, Set<String> tomb) async {
    final localDrivers = await db.getDrivers(includeArchived: true);
    final localById = {for (final d in localDrivers) d.id: d};

    final remoteSnap = await _firestore!.collection('drivers').get();
    final remoteById = {
      for (final doc in remoteSnap.docs) doc.id: Driver.fromMap(doc.data())
    };
    for (final id in remoteById.keys.toList()) {
      if (tomb.contains('driver:$id')) {
        await deleteDriverRemote(id);
        remoteById.remove(id);
      }
    }

    for (final id in {...localById.keys, ...remoteById.keys}) {
      final local = localById[id];
      final remote = remoteById[id];
      if (local == null && remote != null) {
        await db.insertDriver(remote);
      } else if (remote == null && local != null) {
        await _firestore!.collection('drivers').doc(id).set(local.toMap());
      } else if (local != null && remote != null) {
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          await db.insertDriver(remote);
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          await _firestore!.collection('drivers').doc(id).set(local.toMap());
        }
      }
    }
  }

  /// Sube todo lo local a la nube (upsert) y trae todo lo remoto a
  /// SQLite local (upsert). Se usa al reconectar o con "Sincronizar
  /// ahora". No borra nada que no se haya borrado explícitamente.
  ///
  /// Vehículos y choferes se fusionan comparando fechas de edición
  /// (ver [_mergeVehicles] / [_mergeDrivers]); el resto de las
  /// colecciones (mantenimiento, combustible, fotos, ficha técnica,
  /// usuarios) sigue subiendo y bajando directo, como antes.
  Future<void> syncAll() async {
    if (!isCloudEnabled) return;
    try {
      final db = DatabaseHelper.instance;

      // Primero se aplican los borrados definitivos de todos los
      // dispositivos, para que nada eliminado vuelva a aparecer.
      final tomb = await _applyTombstones(db);

      await _mergeVehicles(db, tomb);
      await _mergeDrivers(db, tomb);
      await _syncTramites(db, tomb);

      // A partir de acá, releemos vehículos/choferes ya fusionados,
      // para que el resto de la sincronización trabaje siempre sobre
      // la versión más actualizada de cada uno.
      final localVehicles = await db.getVehicles(includeArchived: true);
      final localCommonUsers = await db.getCommonUsers();

      for (final u in localCommonUsers) {
        await _firestore!.collection('common_users').doc(u.id).set(u.toMap());
      }
      for (final v in localVehicles) {
        final records = await db.getMaintenanceRecords(v.id);
        for (final r in records) {
          await _firestore!
              .collection('maintenance_records')
              .doc(r.id)
              .set(r.toMap());
          final recordPhotos = await db.getRecordPhotos(r.id);
          for (final p in recordPhotos) {
            await _firestore!
                .collection('maintenance_record_photos')
                .doc(p.id)
                .set(p.toMap());
          }
        }
        final obsPhotos = await db.getObservationPhotos(v.id);
        for (final p in obsPhotos) {
          await _firestore!
              .collection('vehicle_observation_photos')
              .doc(p.id)
              .set(p.toMap());
        }
        final months = await db.getFuelLogMonths(v.id);
        for (final month in months) {
          final fuelLogs = await db.getFuelLogsForMonth(v.id, month);
          for (final f in fuelLogs) {
            await _firestore!.collection('fuel_logs').doc(f.id).set(f.toMap());
          }
        }
        final techSheetEntries = await db.getTechSheetEntries(v.id);
        for (final t in techSheetEntries) {
          await _firestore!
              .collection('vehicle_tech_sheets')
              .doc(t.id)
              .set(t.toMap());
        }
      }

      final localFlags = await db.getFeatureFlags();
      for (final f in localFlags) {
        await _firestore!.collection('feature_flags').doc(f.key).set(f.toMap());
      }
      final localAcceptances = await db.getAllLegalAcceptances();
      for (final a in localAcceptances) {
        await _firestore!
            .collection('legal_acceptances')
            .doc(a.username)
            .set(a.toMap());
      }

      final remoteCommonUsers =
          await _firestore!.collection('common_users').get();
      for (final doc in remoteCommonUsers.docs) {
        final user = UserAccount.fromMap(doc.data());
        if (tomb.contains('user:${user.id}')) {
          await deleteUserRemote(user.id);
          continue;
        }
        // Chequeo de seguridad: nunca se instala localmente un usuario
        // con rol god que venga de la nube (nunca debería subirse uno,
        // pero así se evita cualquier vector de escalada de permisos).
        if (user.role == UserRole.common) {
          await db.insertUser(user);
        }
      }

      final remoteRecords =
          await _firestore!.collection('maintenance_records').get();
      for (final doc in remoteRecords.docs) {
        try {
          await db.insertMaintenanceRecord(MaintenanceRecord.fromMap(doc.data()));
        } catch (_) {
          // Registro huérfano (su vehículo ya fue borrado): se ignora.
        }
      }

      final remoteObsPhotos =
          await _firestore!.collection('vehicle_observation_photos').get();
      for (final doc in remoteObsPhotos.docs) {
        try {
          await db.insertObservationPhoto(ObservationPhoto.fromMap(doc.data()));
        } catch (_) {
          // Registro huérfano (su vehículo ya fue borrado): se ignora.
        }
      }

      final remoteRecordPhotos =
          await _firestore!.collection('maintenance_record_photos').get();
      for (final doc in remoteRecordPhotos.docs) {
        try {
          await db.insertRecordPhoto(RecordPhoto.fromMap(doc.data()));
        } catch (_) {
          // Registro huérfano (su vehículo ya fue borrado): se ignora.
        }
      }

      final remoteFuelLogs = await _firestore!.collection('fuel_logs').get();
      for (final doc in remoteFuelLogs.docs) {
        try {
          await db.insertFuelLog(FuelLog.fromMap(doc.data()));
        } catch (_) {
          // Registro huérfano (su vehículo ya fue borrado): se ignora.
        }
      }

      final remoteTechSheets =
          await _firestore!.collection('vehicle_tech_sheets').get();
      for (final doc in remoteTechSheets.docs) {
        try {
          await db.insertTechSheetEntry(TechSheetEntry.fromMap(doc.data()));
        } catch (_) {
          // Registro huérfano (su vehículo ya fue borrado): se ignora.
        }
      }

      final remoteFlags = await _firestore!.collection('feature_flags').get();
      for (final doc in remoteFlags.docs) {
        final remote = FeatureFlag.fromMap(doc.data());
        final localMatch =
            localFlags.where((f) => f.key == remote.key).toList();
        final local = localMatch.isEmpty ? null : localMatch.first;
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          await db.upsertFeatureFlag(remote);
        }
      }

      await _syncAppearances(db);
      try {
        await NotificationPrefsService.instance.syncWithCloud(_firestore!);
      } catch (_) {}

      final remoteAcceptances =
          await _firestore!.collection('legal_acceptances').get();
      for (final doc in remoteAcceptances.docs) {
        await db.upsertLegalAcceptance(LegalAcceptance.fromMap(doc.data()));
      }

      // Auditoría: se trae todo lo remoto (de todos los dispositivos)
      // hacia la base local, para que "Ver historial de movimientos"
      // muestre el panorama completo, no solo lo que pasó en este
      // celular. Nunca se sube nada acá — solo se lee (ver
      // AuditService.log, que sube apenas se genera cada entrada).
      final remoteAuditLog = await _firestore!.collection('audit_log').get();
      for (final doc in remoteAuditLog.docs) {
        await db.insertAuditLog(AuditLog.fromMap(doc.data()));
      }

      lastSyncedAt = DateTime.now();
    } catch (_) {
      // Falla de red a mitad de sync: no rompe nada, se reintenta
      // en la próxima reconexión o toque de "Sincronizar ahora".
    }
  }
}
