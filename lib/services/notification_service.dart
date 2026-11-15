import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/complex.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import '../providers/settings_provider.dart' show kColorOptions;
import 'auth_service.dart';
import 'database_helper.dart';
import 'notification_prefs_service.dart';

/// Encapsula las notificaciones push locales del sistema operativo
/// (Android/iOS) para alertas de service y vencimiento de carnet.
///
/// Estas notificaciones salen del sistema operativo (aparecen en la
/// barra de notificaciones del celular, con sonido) incluso con la
/// app cerrada, siempre que haya sido [BackgroundService] quien las
/// disparó desde la tarea programada (ver background_service.dart).
///
/// CADA CUÁNTO SUENA: el usuario administrador (god) regula el
/// intervalo mínimo entre una alerta sonora y la siguiente desde el
/// panel de administración ([getAlertIntervalMinutes] /
/// [setAlertIntervalMinutes]). Por defecto es cada 60 minutos. Esto
/// evita que, si hay varios vencimientos pendientes, el celular esté
/// sonando todo el tiempo — pero mientras haya algo vencido o por
/// vencer, la alerta se repite cada tanto hasta que se resuelva.
///
/// Para que el sonido personalizado funcione en Android hace falta
/// colocar el archivo de audio en
/// `android/app/src/main/res/raw/alert_sound.wav` (ver README /
/// guía de entrega). Si ese archivo no está, Android usa el sonido
/// de notificación por defecto del sistema — la notificación igual
/// sale, solo cambia el sonido.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  static const _kIntervalMinutesKey = 'alert_sound_interval_minutes';
  static const _kLastFiredAtKey = 'alert_sound_last_fired_at';
  static const int kDefaultIntervalMinutes = 60;

  /// Opciones que se ofrecen en el panel de administración.
  static const List<int> kIntervalOptionsMinutes = [
    15, 30, 60, 120, 180, 360, 720, 1440,
  ];

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ exige pedir el permiso de notificaciones en tiempo
    // de ejecución; en versiones anteriores este llamado no hace nada.
    await androidImpl?.requestNotificationsPermission();

    // Los canales viejos (uno fijo por complejo) se eliminan: ahora
    // se crean al usarlos según el aspecto y el sonido que haya
    // elegido el administrador (cambiar el sonido de un canal ya
    // creado no se puede en Android, por eso se usan canales nuevos).
    for (final c in kComplexes) {
      await androidImpl?.deleteNotificationChannel('fleet_alerts_${c.id}');
    }
  }

  /// Cada cuánto (en minutos) se REPITE la notificación mientras haya
  /// algo pendiente. (Cada cuánto suena el audio se configura aparte,
  /// en las preferencias de notificación.)
  Future<int> getAlertIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kIntervalMinutesKey) ?? kDefaultIntervalMinutes;
  }

  Future<void> setAlertIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kIntervalMinutesKey, minutes);
  }

  static const _kLastSoundKey = 'notif_last_sound_at';

  /// ¿Toca que suene la alerta auditiva? Respeta el "cada cuánto" que
  /// eligió el administrador. Si toca, anota la hora para que el resto
  /// de las notificaciones de la misma tanda salgan en silencio.
  Future<bool> _soundDue(NotificationPrefs p, {required bool force}) async {
    if (force) return true;
    if (p.soundIntervalMinutes <= 0) return false;
    final sp = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(sp.getString(_kLastSoundKey) ?? '');
    final due = last == null ||
        DateTime.now().difference(last).inMinutes >= p.soundIntervalMinutes;
    if (due) {
      await sp.setString(_kLastSoundKey, DateTime.now().toIso8601String());
    }
    return due;
  }

  /// Reproduce el audio propio cargado por el administrador.
  Future<void> _playCustomAudio(String path) async {
    final player = AudioPlayer();
    try {
      await player.play(DeviceFileSource(path));
      // Se espera a que termine (con tope) para que la tarea en
      // segundo plano no se corte antes de que suene.
      await player.onPlayerComplete.first.timeout(const Duration(seconds: 30));
    } catch (_) {
      // Si el audio no se puede reproducir, la notificación igual salió.
    } finally {
      await player.dispose();
    }
  }

  /// Muestra una notificación de un complejo puntual. Solo sale si
  /// hay un usuario con sesión iniciada Y habilitado en ese complejo
  /// (el admin ve los 4). El aspecto (color, logo, estilo, banner,
  /// pantalla bloqueada) y el sonido salen de lo que configuró el
  /// administrador en "Notificaciones".
  Future<void> _show(
    int id,
    String title,
    String body,
    String complexId, {
    bool forceSound = false,
  }) async {
    final user = await AuthService.instance.currentUser();
    if (user == null || !user.canAccess(complexId)) return;

    final c = complexById(complexId);
    final prefs = await NotificationPrefsService.instance.load();
    final customAudio = await NotificationPrefsService.instance.customAudio();
    final soundDue = await _soundDue(prefs, force: forceSound);
    // Con audio propio la notificación sale silenciosa y el sonido lo
    // reproduce la app; sin audio propio suena el de la app.
    final systemSound = soundDue && customAudio == null;

    // Color y logo del complejo (los que cargó el admin, si los hay).
    var color = c.color;
    Uint8List? logo;
    try {
      final list = await DatabaseHelper.instance.getComplexAppearances();
      for (final a in list) {
        if (a.complexId != c.id) continue;
        final idx = a.colorIndex;
        if (idx != null && idx < kColorOptions.length) {
          color = kColorOptions[idx].color;
        }
        final b64 = a.logoBase64;
        if (b64 != null && b64.isNotEmpty) logo = base64Decode(b64);
      }
    } catch (_) {}
    if (prefs.colorMode == 'fixed' &&
        prefs.fixedColorIndex < kColorOptions.length) {
      color = kColorOptions[prefs.fixedColorIndex].color;
    }

    final fullTitle = prefs.showComplexName ? '${c.shortName} · $title' : title;
    final channelId =
        'fleet_${c.id}_${systemSound ? 's' : 'q'}_${prefs.banner ? 'h' : 'd'}';
    final channelName =
        'Alertas ${c.shortName}${systemSound ? '' : ' (silenciosa)'}';
    final importance = prefs.banner ? Importance.high : Importance.defaultImportance;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Alertas de ${c.name}',
        importance: importance,
        playSound: systemSound,
        sound: systemSound
            ? const RawResourceAndroidNotificationSound('alert_sound')
            : null,
      ),
    );

    final visibility = prefs.lockVisibility == 'secret'
        ? NotificationVisibility.secret
        : prefs.lockVisibility == 'private'
            ? NotificationVisibility.private
            : NotificationVisibility.public;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Alertas de ${c.name}',
      importance: importance,
      priority: prefs.banner ? Priority.high : Priority.defaultPriority,
      playSound: systemSound,
      sound: systemSound
          ? const RawResourceAndroidNotificationSound('alert_sound')
          : null,
      groupKey: 'fleet_group_${c.id}',
      color: color,
      largeIcon: (prefs.useLogo && logo != null)
          ? ByteArrayAndroidBitmap(logo)
          : null,
      styleInformation: prefs.style == 'expanded'
          ? BigTextStyleInformation(body,
              contentTitle: fullTitle, summaryText: c.shortName)
          : null,
      visibility: visibility,
    );
    final iosDetails = DarwinNotificationDetails(
      sound: systemSound ? 'alert_sound.wav' : null,
      presentSound: systemSound,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, fullTitle, body, details);

    if (soundDue && customAudio != null) {
      await _playCustomAudio(customAudio.path);
    }
  }

  /// Notificación de prueba para que el administrador vea y escuche
  /// cómo queda (ignora el "cada cuánto").
  Future<void> showTest(String complexId) => _show(
        777001,
        'Prueba de notificación',
        'Así se ve y suena la alerta de este complejo. Ejemplo: la unidad '
            '12 (AB123CD) superó el kilometraje de service.',
        complexId,
        forceSound: true,
      );

  Future<void> notifyVehicleMaintenance(Vehicle v) async {
    if (v.maintenanceStatus == MaintenanceStatus.ok) return;
    final title = v.maintenanceStatus == MaintenanceStatus.overdue
        ? 'Service vencido'
        : 'Service próximo';
    final body = v.maintenanceStatus == MaintenanceStatus.overdue
        ? 'La unidad ${v.internalNumber} (${v.plate}) superó el kilometraje de service.'
        : 'La unidad ${v.internalNumber} (${v.plate}) está a ${v.kmRemaining} km del próximo service.';
    await _show(v.plate.hashCode, title, body, v.complexId);
  }

  Future<void> notifyDriverLicense(Driver d) async {
    if (d.licenseStatus == LicenseStatus.ok) return;
    final days = d.daysToLicenseExpiration;
    final title = d.licenseStatus == LicenseStatus.expired
        ? 'Carnet vencido'
        : 'Carnet por vencer';
    final body = d.licenseStatus == LicenseStatus.expired
        ? '${d.fullName} tiene el carnet de conducir vencido.'
        : '${d.fullName} tiene el carnet vence en $days días.';
    await _show(d.documentId.hashCode, title, body, d.complexId);
  }

  /// Alerta de que un vehículo llegó (o superó) el límite mensual de
  /// combustible que le fijó el admin. Se dispara una sola vez, justo
  /// en el momento en que se cruza el umbral (ver
  /// FuelProvider.addFuelLog), no en cada carga posterior.
  Future<void> notifyFuelLimitReached(Vehicle v, double totalLiters) async {
    await _show(
      'fuel_limit_${v.id}'.hashCode,
      'Límite de combustible alcanzado',
      'La unidad ${v.internalNumber} (${v.plate}) llegó a '
          '${totalLiters.toStringAsFixed(1)} litros cargados este mes.',
      v.complexId,
    );
  }

  /// Aviso previo al de "límite alcanzado": salta al 90% del límite
  /// mensual, para que haya margen de reacción antes de llegar al
  /// tope. Mismo canal con sonido + aparece en la barra de
  /// notificaciones, igual que todas las demás.
  Future<void> notifyFuelLimitApproaching(
      Vehicle v, double totalLiters, double limit) async {
    await _show(
      'fuel_limit_approaching_${v.id}'.hashCode,
      'Acercándose al límite de combustible',
      'La unidad ${v.internalNumber} (${v.plate}) ya cargó '
          '${totalLiters.toStringAsFixed(1)} de ${limit.toStringAsFixed(1)} '
          'litros permitidos este mes.',
      v.complexId,
    );
  }

  /// Recorre listas completas y dispara notificaciones para todos los
  /// casos en warning/overdue. Pensado para llamarse al abrir la app
  /// o desde una tarea programada en background.
  Future<void> checkAndNotifyAll(
      List<Vehicle> vehicles, List<Driver> drivers) async {
    for (final v in vehicles) {
      await notifyVehicleMaintenance(v);
    }
    for (final d in drivers) {
      await notifyDriverLicense(d);
    }
  }

  /// Igual que [checkAndNotifyAll], pero respeta el intervalo mínimo
  /// configurado por el administrador entre una alerta sonora y la
  /// siguiente. Se usa desde la tarea en segundo plano: esta se
  /// ejecuta cada 15 minutos (mínimo técnico de Android), pero el
  /// sonido de alerta en sí solo se repite según lo que haya elegido
  /// el admin en el panel (por defecto, cada 60 minutos).
  Future<void> checkAndNotifyAllIfDue(
      List<Vehicle> vehicles, List<Driver> drivers) async {
    // Sin sesión iniciada no se notifica nada.
    final user = await AuthService.instance.currentUser();
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes =
        prefs.getInt(_kIntervalMinutesKey) ?? kDefaultIntervalMinutes;

    // Cada complejo tiene su propio reloj de alertas: solo se
    // revisan los complejos a los que el usuario está habilitado.
    for (final c in kComplexes) {
      if (!user.canAccess(c.id)) continue;

      final key = '${_kLastFiredAtKey}_${c.id}';
      final lastFiredStr = prefs.getString(key);
      final lastFired =
          lastFiredStr != null ? DateTime.tryParse(lastFiredStr) : null;
      final due = lastFired == null ||
          DateTime.now().difference(lastFired).inMinutes >= intervalMinutes;
      if (!due) continue;

      await checkAndNotifyAll(
        vehicles.where((v) => v.complexId == c.id).toList(),
        drivers.where((d) => d.complexId == c.id).toList(),
      );
      await prefs.setString(key, DateTime.now().toIso8601String());
    }
  }

  /// Revisa todas las alertas pendientes (leyendo directo de la base
  /// local) y notifica solo las de los complejos habilitados para el
  /// usuario que tiene la sesión iniciada. Lo usan tanto la apertura
  /// de la app como la tarea en segundo plano.
  Future<void> checkForCurrentUser() async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles();
    final drivers = await db.getDrivers();
    await checkAndNotifyAllIfDue(vehicles, drivers);
  }
}
