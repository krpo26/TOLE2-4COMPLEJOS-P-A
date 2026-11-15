import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// ⚠️ ARCHIVO PLACEHOLDER — ver README, sección "Modo online / offline".
///
/// Estas claves NO son reales. Para activar la sincronización con la
/// nube hay que generarlas para tu propio proyecto Firebase con:
///
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// Ese comando SOBRESCRIBE este archivo con tus credenciales reales
/// (una vez que creaste un proyecto gratuito en https://console.firebase.google.com).
/// Hasta que hagas ese paso, `SyncService.init()` intentará conectarse,
/// fallará silenciosamente, y la app sigue funcionando 100% offline
/// con la base SQLite local — ninguna función se rompe por esto.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Esta app está pensada para Android/iOS, no para web.',
      );
    }
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    throw UnsupportedError(
      'DefaultFirebaseOptions no soporta esta plataforma.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_TU_API_KEY',
    appId: 'REEMPLAZAR_CON_TU_APP_ID_ANDROID',
    messagingSenderId: 'REEMPLAZAR_CON_TU_SENDER_ID',
    projectId: 'REEMPLAZAR_CON_TU_PROJECT_ID',
    storageBucket: 'REEMPLAZAR_CON_TU_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_TU_API_KEY',
    appId: 'REEMPLAZAR_CON_TU_APP_ID_IOS',
    messagingSenderId: 'REEMPLAZAR_CON_TU_SENDER_ID',
    projectId: 'REEMPLAZAR_CON_TU_PROJECT_ID',
    storageBucket: 'REEMPLAZAR_CON_TU_PROJECT_ID.appspot.com',
    iosBundleId: 'com.fleetapp.app',
  );
}
