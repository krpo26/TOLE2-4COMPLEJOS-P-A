import 'package:workmanager/workmanager.dart';

import 'backup_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';

const String _kTaskName = 'fleet_app_background_upkeep';
const String _kUniqueTaskName = 'fleet_app_background_upkeep_periodic';

/// Punto de entrada que ejecuta Android en un proceso/isolate aparte
/// para correr la tarea en segundo plano, incluso con la app cerrada.
/// El `@pragma('vm:entry-point')` es obligatorio: sin esa anotación,
/// el compilador puede "podar" esta función por no verla usada desde
/// el código Dart normal, y la tarea en segundo plano fallaría en
/// silencio.
///
/// Esta función corre cada ~15 minutos (mínimo técnico que permite
/// Android para tareas periódicas), pero adentro cada acción se
/// autolimita a su propio intervalo real:
/// - El respaldo automático solo se ejecuta si pasaron 3 horas o más
///   desde el último (ver [BackupService.runAutoBackupIfDue]).
/// - La alerta sonora solo se repite según el intervalo que haya
///   configurado el administrador (ver
///   [NotificationService.checkAndNotifyAllIfDue]).
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationService.instance.init();
      await SyncService.instance.init();

      await BackupService.instance.runAutoBackupIfDue();

      await NotificationService.instance.checkForCurrentUser();
    } catch (_) {
      // Una falla acá (por ejemplo, sin conexión en ese momento) nunca
      // debe hacer que Android deje de reintentar en el próximo ciclo.
    }
    return Future.value(true);
  });
}

/// Registra la tarea periódica en segundo plano. Se llama una sola
/// vez al arrancar la app (ver main.dart) — `registerPeriodicTask` es
/// idempotente: si la tarea ya estaba registrada de una apertura
/// anterior, no la duplica.
///
/// LIMITACIÓN HONESTA: tanto Android como iOS restringen cuánto puede
/// correr una app en segundo plano para cuidar batería. Android suele
/// respetar bien este intervalo de 15 minutos; iOS con BGTaskScheduler
/// decide el momento exacto según uso de batería y patrones de uso
/// del celular, así que en iPhone el respaldo/alerta puede tardar más
/// en dispararse que en Android. En ambos casos, además, cada vez que
/// se abre la app manualmente también se revisan las alertas al
/// instante (eso no depende del sistema operativo).
class BackgroundService {
  BackgroundService._internal();
  static final BackgroundService instance = BackgroundService._internal();

  Future<void> initializeAndRegister() async {
    try {
      await Workmanager().initialize(
        backgroundTaskDispatcher,
        isInDebugMode: false,
      );
      await Workmanager().registerPeriodicTask(
        _kUniqueTaskName,
        _kTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    } catch (_) {
      // Si falla el registro (por ejemplo, en una plataforma no
      // soportada), la app sigue funcionando normal: solo se pierde
      // la automatización en segundo plano, no ninguna otra función.
    }
  }
}
