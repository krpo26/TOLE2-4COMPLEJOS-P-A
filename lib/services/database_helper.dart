import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/audit_log.dart';
import '../models/driver.dart';
import '../models/complex_appearance.dart';
import '../models/feature_flag.dart';
import '../models/tramite.dart';
import '../models/fuel_log.dart';
import '../models/legal_acceptance.dart';
import '../models/maintenance_record.dart';
import '../models/observation_photo.dart';
import '../models/record_photo.dart';
import '../models/user_account.dart';
import '../models/vehicle.dart';
import '../models/vehicle_tech_sheet.dart';

/// Capa de persistencia local. Usa SQLite (sqflite) para que la app
/// funcione 100% offline. El diseño deja preparado el terreno para,
/// en una fase futura, sincronizar estas mismas tablas contra
/// Firebase/Supabase (agregar columnas `updated_at` / `synced` si
/// se desea sincronización incremental).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fleet_app.db');

    return openDatabase(
      path,
      version: 17,
      onConfigure: (db) async {
        // Sin esto, las cláusulas "ON DELETE CASCADE" de las tablas
        // (mantenimiento, combustible, ficha técnica, fotos) quedan
        // sin efecto: SQLite las ignora si esta línea no está. Al
        // borrar definitivamente un vehículo o chofer, esto asegura
        // que se limpie también todo lo relacionado, en vez de dejar
        // registros huérfanos acumulándose en la base para siempre.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Fotos de chofer y documentos de vehículo (cédula verde, título,
      // VTV, seguro), agregadas en una versión posterior de la app.
      for (final col in [
        'photo_path',
        'cedula_verde_path',
        'titulo_path',
        'vtv_path',
        'seguro_path',
      ]) {
        try {
          await db.execute('ALTER TABLE vehicles ADD COLUMN $col TEXT');
        } catch (_) {
          // La columna ya existe (upgrade repetido): se ignora.
        }
      }
      try {
        await db.execute('ALTER TABLE drivers ADD COLUMN photo_path TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      // Fotos sueltas como "observación" del vehículo, y fotos
      // adjuntas a cada registro del historial de mantenimiento.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vehicle_observation_photos (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          photo_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_record_photos (
          id TEXT PRIMARY KEY,
          record_id TEXT NOT NULL,
          photo_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (record_id) REFERENCES maintenance_records (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 4) {
      // Marca, modelo y tipo de vehículo (camioneta, auto, moto, camión).
      for (final col in ['brand', 'model', 'vehicle_type']) {
        try {
          await db.execute('ALTER TABLE vehicles ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }
    if (oldVersion < 5) {
      // Dirección y número de cargo del chofer. Se agregan como columnas
      // nuevas (ALTER TABLE), por lo que los choferes ya cargados no se
      // modifican: simplemente quedan con estos campos en null hasta que
      // se editen y se completen.
      for (final col in ['address', 'cargo_number']) {
        try {
          await db.execute('ALTER TABLE drivers ADD COLUMN $col TEXT');
        } catch (_) {
          // La columna ya existe (upgrade repetido): se ignora.
        }
      }
    }
    if (oldVersion < 6) {
      // Ícono elegible para vehículos y choferes, y foto del carnet de
      // conducir. Se agregan como columnas nuevas: los datos ya cargados
      // no se tocan, y el campo "Vencimiento LINTI / psicofísico" deja
      // de pedirse en el formulario (la columna vieja, si existía,
      // simplemente queda sin usarse en la base).
      try {
        await db.execute('ALTER TABLE vehicles ADD COLUMN icon_key TEXT');
      } catch (_) {}
      for (final col in ['icon_key', 'license_photo_path']) {
        try {
          await db.execute('ALTER TABLE drivers ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }
    if (oldVersion < 7) {
      // Cargas de combustible por vehículo (planilla mensual, con
      // historial permanente de meses anteriores) y ficha técnica
      // detallada por vehículo. Tablas nuevas: no afectan ningún dato
      // ya cargado de vehículos, choferes ni mantenimiento.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fuel_logs (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          date TEXT NOT NULL,
          month_key TEXT NOT NULL,
          liters REAL NOT NULL,
          amount REAL,
          mileage INTEGER NOT NULL,
          station_name TEXT,
          notes TEXT,
          ticket_photo_path TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vehicle_tech_sheets (
          vehicle_id TEXT PRIMARY KEY,
          engine_number TEXT,
          chassis_number TEXT,
          engine_type TEXT,
          fuel_type TEXT,
          transmission TEXT,
          tire_size TEXT,
          tire_count INTEGER,
          load_capacity_kg REAL,
          seating_capacity INTEGER,
          color TEXT,
          manufacture_year INTEGER,
          insurance_company TEXT,
          insurance_policy_number TEXT,
          notes TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 8) {
      // "Archivar" en vez de borrar: un vehículo o chofer dado de baja
      // deja de aparecer en las listas normales, pero se puede
      // consultar y reactivar desde "Ver archivados". Nada se pierde.
      // También se agrega la tabla de auditoría (quién hizo qué
      // cambio y cuándo).
      for (final col in ['is_archived']) {
        try {
          await db.execute(
              'ALTER TABLE vehicles ADD COLUMN $col INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute(
              'ALTER TABLE drivers ADD COLUMN $col INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          username TEXT NOT NULL,
          action TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_label TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 9) {
      // La "ficha técnica" pasa de ser un único formulario fijo por
      // vehículo (motor, chasis, seguro, etc.) a una tabla con varios
      // renglones por vehículo — uno por cada service/reparación
      // cargada, con columnas FECHA, CHOFER, KILOMETRO, REPUESTOS y
      // COMERCIO (igual que la planilla de Excel que se usaba antes).
      // Se reemplaza la tabla vieja: los datos de motor/chasis/seguro
      // que hubiera cargados se pierden, tal como se pidió.
      await db.execute('DROP TABLE IF EXISTS vehicle_tech_sheets');
      await db.execute('''
        CREATE TABLE vehicle_tech_sheets (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          date TEXT NOT NULL,
          driver_name TEXT,
          mileage INTEGER,
          parts TEXT,
          shop TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 10) {
      // Sello de tiempo de última edición en vehículos y choferes,
      // para que la sincronización sepa cuál versión es la más nueva
      // y un dispositivo con datos viejos no le pise el cambio a otro
      // (ej: el admin actualiza el vencimiento del carnet de un
      // chofer y esa edición ya no se pierde al sincronizar).
      await db.execute(
          'ALTER TABLE vehicles ADD COLUMN updated_at TEXT');
      await db.execute(
          'ALTER TABLE drivers ADD COLUMN updated_at TEXT');
    }
    if (oldVersion < 11) {
      // Pestañas/secciones que el admin puede mostrar u ocultar para
      // los usuarios comunes, y el registro de quién aceptó los
      // términos de uso y confidencialidad (y con qué versión del
      // texto), para dejar constancia formal de esa aceptación.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS feature_flags (
          key TEXT PRIMARY KEY,
          enabled INTEGER NOT NULL DEFAULT 1,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS legal_acceptances (
          username TEXT PRIMARY KEY,
          version TEXT NOT NULL,
          accepted_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 12) {
      // Chofer que hizo cada carga de combustible, y límite mensual de
      // litros configurable por vehículo (para la alerta de "se llegó
      // al límite de combustible del mes").
      await db.execute('ALTER TABLE fuel_logs ADD COLUMN driver_name TEXT');
      await db.execute(
          'ALTER TABLE vehicles ADD COLUMN monthly_fuel_limit_liters REAL');
    }
    if (oldVersion < 13) {
      // Se dejó de pedir "monto" y "estación" al cargar combustible.
      // SQLite no permite sacarle el NOT NULL a una columna existente
      // directamente, así que se recrea la tabla sin esa restricción
      // (las cargas viejas que sí tenían monto cargado no se tocan).
      await db.execute('''
        CREATE TABLE fuel_logs_new (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          date TEXT NOT NULL,
          month_key TEXT NOT NULL,
          liters REAL NOT NULL,
          amount REAL,
          mileage INTEGER NOT NULL,
          driver_name TEXT,
          station_name TEXT,
          notes TEXT,
          ticket_photo_path TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO fuel_logs_new
        SELECT id, vehicle_id, date, month_key, liters, amount, mileage,
               driver_name, station_name, notes, ticket_photo_path
        FROM fuel_logs
      ''');
      await db.execute('DROP TABLE fuel_logs');
      await db.execute('ALTER TABLE fuel_logs_new RENAME TO fuel_logs');
    }
    if (oldVersion < 14) {
      // 4 complejos penitenciarios: cada móvil y cada chofer
      // pertenece a uno. Todo lo ya cargado queda asignado a
      // Benjamín Paz (donde se venía usando la app). Los usuarios
      // comunes ya existentes quedan habilitados solo ahí
      // (allowed_complexes en NULL = valor anterior).
      try {
        await db.execute(
            "ALTER TABLE vehicles ADD COLUMN complex_id TEXT NOT NULL DEFAULT 'benjamin_paz'");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE drivers ADD COLUMN complex_id TEXT NOT NULL DEFAULT 'benjamin_paz'");
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN allowed_complexes TEXT');
      } catch (_) {}
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tramites (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          type TEXT NOT NULL,
          start_date TEXT NOT NULL,
          status TEXT NOT NULL,
          file_number TEXT NOT NULL,
          detail TEXT,
          updated_at TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS complex_appearance (
          complex_id TEXT PRIMARY KEY,
          theme_mode TEXT,
          color_index INTEGER,
          font_key TEXT,
          logo_b64 TEXT,
          updated_at TEXT
        )
      ''');
    }
    if (oldVersion < 15) {
      // Registro de lo borrado definitivamente (vehículos, choferes,
      // usuarios), para que el borrado se propague a todos los
      // dispositivos y nada "resucite" al sincronizar.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_records (
          type TEXT NOT NULL,
          id TEXT NOT NULL,
          deleted_at TEXT NOT NULL,
          PRIMARY KEY (type, id)
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        plate TEXT UNIQUE NOT NULL,
        internal_number TEXT NOT NULL,
        brand TEXT,
        model TEXT,
        vehicle_type TEXT,
        current_mileage INTEGER NOT NULL,
        last_service_date TEXT,
        next_service_mileage INTEGER NOT NULL,
        notes TEXT,
        photo_path TEXT,
        cedula_verde_path TEXT,
        titulo_path TEXT,
        vtv_path TEXT,
        seguro_path TEXT,
        icon_key TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        monthly_fuel_limit_liters REAL,
        updated_at TEXT,
        complex_id TEXT NOT NULL DEFAULT 'benjamin_paz'
      )
    ''');

    await db.execute('''
      CREATE TABLE drivers (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        document_id TEXT UNIQUE NOT NULL,
        phone TEXT,
        license_category TEXT,
        license_expiration TEXT NOT NULL,
        photo_path TEXT,
        license_photo_path TEXT,
        address TEXT,
        cargo_number TEXT,
        icon_key TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        complex_id TEXT NOT NULL DEFAULT 'benjamin_paz'
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        allowed_complexes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_records (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        mileage_at_event INTEGER,
        cost REAL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vehicle_observation_photos (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_record_photos (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES maintenance_records (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE fuel_logs (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date TEXT NOT NULL,
        month_key TEXT NOT NULL,
        liters REAL NOT NULL,
        amount REAL,
        mileage INTEGER NOT NULL,
        driver_name TEXT,
        station_name TEXT,
        notes TEXT,
        ticket_photo_path TEXT,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vehicle_tech_sheets (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date TEXT NOT NULL,
        driver_name TEXT,
        mileage INTEGER,
        parts TEXT,
        shop TEXT,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        username TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_label TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE feature_flags (
        key TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE legal_acceptances (
        username TEXT PRIMARY KEY,
        version TEXT NOT NULL,
        accepted_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tramites (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        status TEXT NOT NULL,
        file_number TEXT NOT NULL,
        detail TEXT,
        updated_at TEXT,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE complex_appearance (
        complex_id TEXT PRIMARY KEY,
        theme_mode TEXT,
        color_index INTEGER,
        font_key TEXT,
        logo_b64 TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE deleted_records (
        type TEXT NOT NULL,
        id TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        PRIMARY KEY (type, id)
      )
    ''');
  }

  // ---------------- DELETED RECORDS (borrados definitivos) ----------------

  Future<void> insertTombstone(String type, String id,
      {String? deletedAt}) async {
    final db = await database;
    await db.insert(
      'deleted_records',
      {
        'type': type,
        'id': id,
        'deleted_at': deletedAt ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getTombstones() async {
    final db = await database;
    return db.query('deleted_records');
  }

  // ---------------- VEHICLES ----------------

  Future<int> insertVehicle(Vehicle v) async {
    final db = await database;
    return db.insert(
      'vehicles',
      v.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateVehicle(Vehicle v) async {
    final db = await database;
    return db.update('vehicles', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  Future<int> deleteVehicle(String id) async {
    final db = await database;
    return db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  /// Solo vehículos activos (no archivados) por defecto — lo que se
  /// ve en la lista normal. Pasar [includeArchived] en true trae
  /// también los archivados (se usa en la pantalla "Archivados").
  Future<List<Vehicle>> getVehicles(
      {bool includeArchived = false, String? complexId}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (!includeArchived) where.add('is_archived = 0');
    if (complexId != null) {
      where.add('complex_id = ?');
      args.add(complexId);
    }
    final rows = await db.query(
      'vehicles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'plate ASC',
    );
    return rows.map((r) => Vehicle.fromMap(r)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final db = await database;
    final rows = await db.query('vehicles', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Vehicle.fromMap(rows.first);
  }

  Future<List<Vehicle>> getArchivedVehicles({String? complexId}) async {
    final db = await database;
    final rows = await db.query('vehicles',
        where: complexId == null
            ? 'is_archived = 1'
            : 'is_archived = 1 AND complex_id = ?',
        whereArgs: complexId == null ? null : [complexId],
        orderBy: 'plate ASC');
    return rows.map((r) => Vehicle.fromMap(r)).toList();
  }

  // ---------------- DRIVERS ----------------

  Future<int> insertDriver(Driver d) async {
    final db = await database;
    return db.insert(
      'drivers',
      d.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateDriver(Driver d) async {
    final db = await database;
    return db.update('drivers', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<int> deleteDriver(String id) async {
    final db = await database;
    return db.delete('drivers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Driver>> getDrivers(
      {bool includeArchived = false, String? complexId}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (!includeArchived) where.add('is_archived = 0');
    if (complexId != null) {
      where.add('complex_id = ?');
      args.add(complexId);
    }
    final rows = await db.query(
      'drivers',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'full_name ASC',
    );
    return rows.map((r) => Driver.fromMap(r)).toList();
  }

  Future<List<Driver>> getArchivedDrivers({String? complexId}) async {
    final db = await database;
    final rows = await db.query('drivers',
        where: complexId == null
            ? 'is_archived = 1'
            : 'is_archived = 1 AND complex_id = ?',
        whereArgs: complexId == null ? null : [complexId],
        orderBy: 'full_name ASC');
    return rows.map((r) => Driver.fromMap(r)).toList();
  }

  // ---------------- USERS ----------------

  Future<int> insertUser(UserAccount u) async {
    final db = await database;
    return db.insert('users', u.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateUser(UserAccount u) async {
    final db = await database;
    return db.update('users', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<UserAccount?> getUserByUsername(String username) async {
    final db = await database;
    final rows =
        await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return UserAccount.fromMap(rows.first);
  }

  Future<UserAccount?> getUserById(String id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return UserAccount.fromMap(rows.first);
  }

  Future<UserAccount?> getGodUser() async {
    final db = await database;
    final rows =
        await db.query('users', where: 'role = ?', whereArgs: ['god']);
    if (rows.isEmpty) return null;
    return UserAccount.fromMap(rows.first);
  }

  /// Solo los usuarios comunes (excluye al god) para la pantalla de
  /// administración de usuarios.
  Future<List<UserAccount>> getCommonUsers() async {
    final db = await database;
    final rows = await db.query('users',
        where: 'role = ?', whereArgs: ['common'], orderBy: 'username ASC');
    return rows.map((r) => UserAccount.fromMap(r)).toList();
  }

  // ---------------- MAINTENANCE RECORDS ----------------

  Future<int> insertMaintenanceRecord(MaintenanceRecord r) async {
    final db = await database;
    return db.insert('maintenance_records', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteMaintenanceRecord(String id) async {
    final db = await database;
    return db.delete('maintenance_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MaintenanceRecord>> getMaintenanceRecords(
      String vehicleId) async {
    final db = await database;
    final rows = await db.query('maintenance_records',
        where: 'vehicle_id = ?', whereArgs: [vehicleId], orderBy: 'date DESC');
    return rows.map((r) => MaintenanceRecord.fromMap(r)).toList();
  }

  // ---------------- VEHICLE OBSERVATION PHOTOS ----------------
  // Fotos sueltas adjuntas al campo "Observaciones" de un vehículo.

  Future<int> insertObservationPhoto(ObservationPhoto p) async {
    final db = await database;
    return db.insert('vehicle_observation_photos', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteObservationPhoto(String id) async {
    final db = await database;
    return db.delete('vehicle_observation_photos',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ObservationPhoto>> getObservationPhotos(
      String vehicleId) async {
    final db = await database;
    final rows = await db.query('vehicle_observation_photos',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'created_at DESC');
    return rows.map((r) => ObservationPhoto.fromMap(r)).toList();
  }

  // ---------------- MAINTENANCE RECORD PHOTOS ----------------
  // Fotos adjuntas a un registro puntual del historial (arreglo/avería).

  Future<int> insertRecordPhoto(RecordPhoto p) async {
    final db = await database;
    return db.insert('maintenance_record_photos', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteRecordPhoto(String id) async {
    final db = await database;
    return db.delete('maintenance_record_photos',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecordPhoto>> getRecordPhotos(String recordId) async {
    final db = await database;
    final rows = await db.query('maintenance_record_photos',
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'created_at DESC');
    return rows.map((r) => RecordPhoto.fromMap(r)).toList();
  }

  // ---------------- FUEL LOGS (combustible) ----------------

  Future<int> insertFuelLog(FuelLog f) async {
    final db = await database;
    return db.insert('fuel_logs', f.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteFuelLog(String id) async {
    final db = await database;
    return db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Cargas de un vehículo en un mes puntual ("2026-08"). Es la
  /// "planilla del mes en curso" que se resetea visualmente cada mes
  /// (siempre arranca vacía en un mes nuevo), pero el historial de
  /// meses anteriores queda guardado y se consulta igual, pasando el
  /// monthKey correspondiente.
  Future<List<FuelLog>> getFuelLogsForMonth(
      String vehicleId, String monthKey) async {
    final db = await database;
    final rows = await db.query(
      'fuel_logs',
      where: 'vehicle_id = ? AND month_key = ?',
      whereArgs: [vehicleId, monthKey],
      orderBy: 'date DESC',
    );
    return rows.map((r) => FuelLog.fromMap(r)).toList();
  }

  /// Todos los meses (distintos) para los que un vehículo tiene
  /// cargas registradas, más recientes primero. Sirve para armar el
  /// selector de mes en la pantalla de combustible.
  Future<List<String>> getFuelLogMonths(String vehicleId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT month_key FROM fuel_logs WHERE vehicle_id = ? '
      'ORDER BY month_key DESC',
      [vehicleId],
    );
    return rows.map((r) => r['month_key'] as String).toList();
  }

  // ---------------- VEHICLE TECH SHEETS (ficha técnica) ----------------
  // Tabla de renglones (FECHA, CHOFER, KILOMETRO, REPUESTOS, COMERCIO),
  // varios por vehículo.

  Future<int> insertTechSheetEntry(TechSheetEntry t) async {
    final db = await database;
    return db.insert('vehicle_tech_sheets', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteTechSheetEntry(String id) async {
    final db = await database;
    return db.delete('vehicle_tech_sheets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TechSheetEntry>> getTechSheetEntries(String vehicleId) async {
    final db = await database;
    final rows = await db.query('vehicle_tech_sheets',
        where: 'vehicle_id = ?', whereArgs: [vehicleId], orderBy: 'date DESC');
    return rows.map((r) => TechSheetEntry.fromMap(r)).toList();
  }

  // ---------------- AUDIT LOG (auditoría) ----------------

  Future<int> insertAuditLog(AuditLog log) async {
    final db = await database;
    return db.insert('audit_log', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Los últimos [limit] movimientos, más recientes primero. Pensado
  /// para la pantalla de auditoría del panel de administración.
  Future<List<AuditLog>> getAuditLogs({int limit = 200}) async {
    final db = await database;
    final rows = await db.query('audit_log',
        orderBy: 'timestamp DESC', limit: limit);
    return rows.map((r) => AuditLog.fromMap(r)).toList();
  }

  // ---------------- FEATURE FLAGS (pestañas visibles) ----------------
  // Qué secciones de la app puede ver un usuario común. El admin
  // (god) siempre ve todo, sin importar estos valores.

  // ---------------- TRÁMITES ----------------

  /// Trámites de los móviles de un complejo (el complejo se toma del
  /// móvil, así si el móvil se mueve de complejo el trámite lo sigue).
  Future<List<Tramite>> getTramitesForComplex(String complexId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.* FROM tramites t
      JOIN vehicles v ON v.id = t.vehicle_id
      WHERE v.complex_id = ?
      ORDER BY t.start_date DESC
    ''', [complexId]);
    return rows.map((r) => Tramite.fromMap(r)).toList();
  }

  Future<List<Tramite>> getAllTramites() async {
    final db = await database;
    final rows = await db.query('tramites', orderBy: 'start_date DESC');
    return rows.map((r) => Tramite.fromMap(r)).toList();
  }

  Future<void> upsertTramite(Tramite t) async {
    final db = await database;
    await db.insert('tramites', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTramite(String id) async {
    final db = await database;
    await db.delete('tramites', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- COMPLEX APPEARANCE ----------------

  Future<List<ComplexAppearance>> getComplexAppearances() async {
    final db = await database;
    final rows = await db.query('complex_appearance');
    return rows.map((r) => ComplexAppearance.fromMap(r)).toList();
  }

  Future<void> upsertComplexAppearance(ComplexAppearance a) async {
    final db = await database;
    await db.insert('complex_appearance', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FeatureFlag>> getFeatureFlags() async {
    final db = await database;
    final rows = await db.query('feature_flags');
    return rows.map((r) => FeatureFlag.fromMap(r)).toList();
  }

  Future<int> upsertFeatureFlag(FeatureFlag f) async {
    final db = await database;
    return db.insert('feature_flags', f.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- LEGAL ACCEPTANCES (aceptación de términos) ----------------

  Future<LegalAcceptance?> getLegalAcceptance(String username) async {
    final db = await database;
    final rows = await db.query('legal_acceptances',
        where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return LegalAcceptance.fromMap(rows.first);
  }

  Future<List<LegalAcceptance>> getAllLegalAcceptances() async {
    final db = await database;
    final rows = await db.query('legal_acceptances');
    return rows.map((r) => LegalAcceptance.fromMap(r)).toList();
  }

  Future<int> upsertLegalAcceptance(LegalAcceptance a) async {
    final db = await database;
    return db.insert('legal_acceptances', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
