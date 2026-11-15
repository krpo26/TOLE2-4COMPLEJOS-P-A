import 'package:screen_protector/screen_protector.dart';

/// Bloquea capturas de pantalla y grabación de pantalla mientras la
/// app está abierta, para todos los usuarios (no solo el god), como
/// refuerzo técnico del marco legal de confidencialidad que cada
/// usuario acepta en [LegalTermsScreen].
///
/// En Android esto activa la bandera FLAG_SECURE de la ventana: el
/// sistema operativo directamente impide la captura (el usuario ve un
/// aviso de "no se puede capturar la pantalla por política de la
/// app" o la imagen sale en negro, según el equipo). En iOS, además,
/// difumina el contenido en el selector de apps recientes para que no
/// quede visible en una captura automática del sistema.
///
/// Si por algún motivo la plataforma no soporta el bloqueo (por
/// ejemplo, en web o desktop) el error se ignora en silencio: la app
/// sigue funcionando normal, simplemente sin esta protección extra.
class ScreenshotProtectionService {
  static Future<void> enable() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {
      // Plataforma no soportada o permiso no disponible: se continúa
      // sin bloqueo de capturas, sin interrumpir el arranque de la app.
    }
    try {
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {
      // Idem para el difuminado en el selector de apps (iOS).
    }
  }

  /// Por si en el futuro se quiere permitir capturas en alguna
  /// pantalla puntual (por ejemplo, para que el god saque una captura
  /// de un reporte). No se usa todavía en ningún lado de la app.
  static Future<void> disable() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {}
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {}
  }
}
