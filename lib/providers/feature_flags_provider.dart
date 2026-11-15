import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/feature_flag.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// Qué "pestañas"/secciones puede ver un usuario común, según lo que
/// haya configurado el admin (god). Si una clave todavía no está
/// guardada en la base (por ejemplo, recién actualizada la app y
/// nunca se tocó ese interruptor), se trata como ACTIVADA por
/// defecto — así ninguna sección nueva aparece oculta por accidente.
///
/// El admin (god) nunca se ve afectado por estos flags: siempre ve
/// todo. El chequeo de "sos god, mostrá igual" se hace en cada
/// pantalla, no acá.
class FeatureFlagsProvider extends ChangeNotifier {
  final Map<String, bool> _enabled = {};
  bool isLoading = true;

  bool isEnabled(String key) => _enabled[key] ?? true;

  /// Clave interna (no aparece en la lista de pestañas) donde se guarda
  /// qué logo eligió el admin. Viaja por el mismo circuito que los
  /// demás interruptores, así que se sincroniza a todos los
  /// dispositivos sin tocar la base ni las reglas de Firestore.
  static const String kAltLogoKey = 'app_logo_alt';
  static const String kLogoOriginalAsset = 'assets/images/logo.png';
  static const String kLogoAltAsset = 'assets/images/logo_azul.png';

  /// false = logo original (alas y cadenas), true = logo azul
  /// (patrullero). Si el admin nunca eligió, se usa el original.
  bool get useAltLogo => _enabled[kAltLogoKey] ?? false;

  String get logoAsset => useAltLogo ? kLogoAltAsset : kLogoOriginalAsset;

  /// Solo debe llamarse desde el panel de administración (god).
  Future<void> setAltLogo(bool value) => setEnabled(kAltLogoKey, value);

  Future<void> load() async {
    final flags = await DatabaseHelper.instance.getFeatureFlags();
    _enabled
      ..clear()
      ..addEntries(flags.map((f) => MapEntry(f.key, f.enabled)));
    isLoading = false;
    notifyListeners();
  }

  /// Solo debe llamarse desde una pantalla de administración (god).
  Future<void> setEnabled(String key, bool value) async {
    _enabled[key] = value;
    notifyListeners();
    final flag = FeatureFlag(key: key, enabled: value);
    await DatabaseHelper.instance.upsertFeatureFlag(flag);
    unawaited(SyncService.instance.pushFeatureFlag(flag));
  }
}
